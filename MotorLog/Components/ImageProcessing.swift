//
//  ImageProcessing.swift
//  MotorLog
//

import ImageIO
import SwiftUI
import UIKit

/// An image picked in a form but not saved yet.
struct PickedImage: Identifiable, Equatable {
    var id = UUID()
    var data: Data
    var name: String = ""
}

enum ImageProcessing {
    /// Downscales and JPEG-compresses an image before it's stored, off the main actor.
    @concurrent
    nonisolated static func prepareForStorage(_ data: Data, maxDimension: CGFloat = 2048) async -> Data? {
        guard let image = downsample(data, maxPixel: maxDimension) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.8)
    }

    /// Decodes a display-sized thumbnail off the main actor.
    @concurrent
    nonisolated static func thumbnail(_ data: Data, maxPixel: CGFloat) async -> UIImage? {
        downsample(data, maxPixel: maxPixel).map { UIImage(cgImage: $0) }
    }

    nonisolated private static func downsample(_ data: Data, maxPixel: CGFloat) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

/// In-memory cache of decoded thumbnails, keyed by a caller-provided identifier.
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 150
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

/// Displays image data, decoding it asynchronously so scrolling stays smooth.
struct StoredImage: View {
    /// Whether there is image data to load; decides between the photo and the placeholder.
    let hasData: Bool
    /// Stable identifier for the image content (used for caching and reloading).
    let cacheKey: String
    var maxPixel: CGFloat = 1200
    /// Reads the image data only on a cache miss. External-storage blobs are read from disk,
    /// so touching them on every body evaluation makes scrolling stutter.
    private let loadData: () -> Data?

    @State private var image: UIImage?

    private var fullKey: String { Self.key(cacheKey, maxPixel) }

    init(data: Data?, cacheKey: String, maxPixel: CGFloat = 1200) {
        self.init(hasData: data != nil, cacheKey: cacheKey, maxPixel: maxPixel) { data }
    }

    init(hasData: Bool, cacheKey: String, maxPixel: CGFloat = 1200, loadData: @escaping () -> Data?) {
        self.hasData = hasData
        self.cacheKey = cacheKey
        self.maxPixel = maxPixel
        self.loadData = loadData
        // Seed from the cache so rows re-created by lazy stacks show their image immediately,
        // instead of flashing the placeholder and fading in again while scrolling.
        _image = State(initialValue: hasData ? ThumbnailCache.shared.image(for: Self.key(cacheKey, maxPixel)) : nil)
    }

    private static func key(_ cacheKey: String, _ maxPixel: CGFloat) -> String {
        "\(cacheKey)-\(Int(maxPixel))"
    }

    var body: some View {
        Color.brandGreenSoft
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                        // Scoped to this view so the fade never animates the enclosing scroll view's layout.
                        .animation(.easeOut(duration: 0.2), value: image)
                } else if !hasData {
                    Image(systemName: "car.side")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.brandGreen.opacity(0.5))
                }
            }
            .clipped()
            .task(id: fullKey) {
                await load()
            }
    }

    private func load() async {
        guard hasData else {
            image = nil
            return
        }
        if let cached = ThumbnailCache.shared.image(for: fullKey) {
            if image !== cached { image = cached }
            return
        }
        guard let data = loadData() else {
            image = nil
            return
        }
        let decoded = await ImageProcessing.thumbnail(data, maxPixel: maxPixel)
        guard !Task.isCancelled, let decoded else { return }
        ThumbnailCache.shared.insert(decoded, for: fullKey)
        image = decoded
    }
}
