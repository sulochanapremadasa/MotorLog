//
//  ImageSourcePicker.swift
//  MotorLog
//

import PhotosUI
import SwiftUI
import UIKit

/// Wraps `UIImagePickerController` for camera capture (SwiftUI has no native camera picker).
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Presents a "Take Photo / Choose from Library" dialog and returns processed JPEG data.
struct ImageSourcePickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    var maxSelection: Int
    let onPicked: ([Data]) -> Void

    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var libraryItems: [PhotosPickerItem] = []

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Add photo", isPresented: $isPresented, titleVisibility: .visible) {
                if isCameraAvailable {
                    Button("Take Photo") { showsCamera = true }
                }
                Button("Choose from Library") { showsLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(
                isPresented: $showsLibrary,
                selection: $libraryItems,
                maxSelectionCount: max(maxSelection, 1),
                selectionBehavior: .ordered,
                matching: .images
            )
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { image in
                    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                    Task {
                        if let processed = await ImageProcessing.prepareForStorage(data) {
                            onPicked([processed])
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: libraryItems) { _, items in
                guard !items.isEmpty else { return }
                libraryItems = []
                Task {
                    var results: [Data] = []
                    for item in items {
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              let processed = await ImageProcessing.prepareForStorage(data) else { continue }
                        results.append(processed)
                    }
                    if !results.isEmpty {
                        onPicked(results)
                    }
                }
            }
    }
}

extension View {
    /// Lets the person take or choose up to `maxSelection` photos.
    func imageSourcePicker(isPresented: Binding<Bool>, maxSelection: Int = 1, onPicked: @escaping ([Data]) -> Void) -> some View {
        modifier(ImageSourcePickerModifier(isPresented: isPresented, maxSelection: maxSelection, onPicked: onPicked))
    }
}

/// Single image slot: shows the image if set, otherwise a dashed upload tile.
struct SingleImageField: View {
    let title: String
    var subtitle: String? = "Tap to upload"
    @Binding var image: PickedImage?
    var isCircle = false

    @State private var showsPicker = false

    var body: some View {
        Button {
            showsPicker = true
        } label: {
            if let image {
                StoredImage(data: image.data, cacheKey: image.id.uuidString, maxPixel: 600)
                    .clipShape(isCircle ? AnyShape(.circle) : AnyShape(.rect(cornerRadius: 16)))
                    .overlay(alignment: .topTrailing) {
                        if !isCircle { removeButton }
                    }
            } else {
                DashedUploadTile(title: title, subtitle: subtitle, isCircle: isCircle)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(image == nil ? title : "\(title), photo added")
        .accessibilityHint("Choose or take a photo")
        .contextMenu {
            if image != nil {
                Button("Remove Photo", systemImage: "trash", role: .destructive) { image = nil }
            }
        }
        .imageSourcePicker(isPresented: $showsPicker) { results in
            if let first = results.first {
                image = PickedImage(data: first)
            }
        }
    }

    private var removeButton: some View {
        Button {
            image = nil
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.55), in: .circle)
        }
        .buttonStyle(.plain)
        .padding(8)
        .accessibilityLabel("Remove \(title)")
    }
}

/// Horizontal strip of up to `maxCount` images plus an upload tile.
struct MultiImageField: View {
    @Binding var images: [PickedImage]
    let maxCount: Int
    var tileTitle = "Add photo"
    var tileSize: CGFloat = 150

    @State private var showsPicker = false

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(images) { image in
                    StoredImage(data: image.data, cacheKey: image.id.uuidString, maxPixel: tileSize * 3)
                        .frame(width: tileSize, height: tileSize * 0.9)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                images.removeAll { $0.id == image.id }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(.black.opacity(0.55), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                            .accessibilityLabel("Remove photo")
                        }
                }
                if images.count < maxCount {
                    Button {
                        showsPicker = true
                    } label: {
                        DashedUploadTile(title: tileTitle, subtitle: "Up to \(maxCount)")
                            .frame(width: tileSize, height: tileSize * 0.9)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .imageSourcePicker(isPresented: $showsPicker, maxSelection: maxCount - images.count) { results in
            let room = maxCount - images.count
            images.append(contentsOf: results.prefix(room).map { PickedImage(data: $0) })
        }
    }
}

/// Full-screen, zoomable photo viewer.
struct ImageViewer: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = max(1, $0.magnification) }
                            .onEnded { _ in withAnimation(.spring) { scale = 1 } }
                    )
                    .accessibilityLabel("Photo")
            } else {
                ProgressView().tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: .circle)
            }
            .padding()
            .accessibilityLabel("Close")
        }
        .task {
            image = await ImageProcessing.thumbnail(data, maxPixel: 3000)
        }
    }
}
