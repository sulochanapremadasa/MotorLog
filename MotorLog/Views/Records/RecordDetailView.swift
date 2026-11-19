//
//  RecordDetailView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// Full details of a single maintenance record.
struct RecordDetailView: View {
    let record: MaintenanceRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showsEdit = false
    @State private var confirmsDeletion = false
    @State private var viewedPhoto: RecordPhoto?

    /// Odometer values use the unit chosen for the vehicle.
    private var unit: DistanceUnit { record.vehicle?.distanceUnit ?? .current }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                infoGrid
                if let nextService = nextServiceText {
                    nextServiceCard(nextService)
                }
                if !record.notes.isEmpty {
                    notesCard
                }
                attachmentsCard

                Button("Edit record") { showsEdit = true }
                    .buttonStyle(.outline)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationTitle("Maintenance record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Edit Record", systemImage: "pencil") { showsEdit = true }
                    Button("Delete Record", systemImage: "trash", role: .destructive) { confirmsDeletion = true }
                }
            }
        }
        .navigationDestination(isPresented: $showsEdit) {
            if let vehicle = record.vehicle {
                RecordFormView(vehicle: vehicle, record: record)
            }
        }
        .confirmationDialog("Delete record?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Delete Record", role: .destructive) {
                dismiss()
                modelContext.delete(record)
            }
        } message: {
            Text("This record and its attachments will be permanently deleted.")
        }
        .fullScreenCover(item: $viewedPhoto) { photo in
            if let data = photo.data {
                ImageViewer(data: data)
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 14) {
            IconTile(systemName: record.type.symbolName, size: 92)
            Text(record.type.title)
                .font(.dm(14, .bold, relativeTo: .caption))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.brandGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.brandGreenSoft, in: .capsule)
            Text(record.title)
                .font(.dm(32, .bold, relativeTo: .largeTitle))
                .foregroundStyle(Color.primaryText)
                .multilineTextAlignment(.center)
            if let vehicle = record.vehicle {
                Text([vehicle.displayName, vehicle.plateNumber].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.dm(17, relativeTo: .body))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var infoGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                InfoTile(systemName: "calendar", label: "Service date", value: Formatters.mediumDate(record.serviceDate))
                Divider().overlay(Color.cardBorder)
                InfoTile(systemName: "gauge.with.dots.needle.33percent", label: "Odometer", value: Formatters.distance(record.odometer, unit: unit))
            }
            .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Color.cardBorder)
            HStack(spacing: 0) {
                InfoTile(systemName: "list.bullet.rectangle.portrait", label: "Total cost", value: Formatters.currency(record.cost))
                Divider().overlay(Color.cardBorder)
                InfoTile(
                    systemName: "mappin.and.ellipse",
                    label: "Service provider",
                    value: record.shopName.isEmpty ? "—" : record.shopName
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Color.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Color.cardBorder, lineWidth: 1)
        }
    }

    private var nextServiceText: String? {
        guard record.type == .service else { return nil }
        var parts: [String] = []
        if let date = record.nextServiceDate {
            parts.append(Formatters.mediumDate(date))
        }
        if let odometer = record.nextServiceOdometer {
            parts.append("at \(Formatters.distance(odometer, unit: unit))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " or ")
    }

    private func nextServiceCard(_ text: String) -> some View {
        InfoTile(systemName: "calendar.badge.clock", label: "Next service due", value: text)
            .background(Color.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Color.cardBorder, lineWidth: 1)
            }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionEyebrow("Service notes")
            Text(record.notes)
                .font(.dm(17, relativeTo: .body))
                .foregroundStyle(Color.primaryText)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .card(padding: 18)
    }

    private var attachmentsCard: some View {
        let photos = record.sortedPhotos

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                SectionTitle(eyebrow: "Attachments", title: "Receipts & documents")
                Spacer()
                Text(photos.count == 1 ? "1 file" : "\(photos.count) files")
                    .font(.dm(14, relativeTo: .footnote))
                    .foregroundStyle(Color.secondaryText)
            }

            if photos.isEmpty {
                Divider().overlay(Color.cardBorder)
                Text("No attachments")
                    .font(.dm(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.secondaryText)
            }

            ForEach(photos) { photo in
                Divider().overlay(Color.cardBorder)
                Button {
                    viewedPhoto = photo
                } label: {
                    HStack(spacing: 16) {
                        StoredImage(data: photo.data, cacheKey: photo.id.uuidString, maxPixel: 240)
                            .frame(width: 64, height: 64)
                            .clipShape(.rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(photo.name.isEmpty ? "Photo" : photo.name)
                                .font(.dm(17, .semibold, relativeTo: .headline))
                                .foregroundStyle(Color.primaryText)
                            Text("JPG · \(Formatters.byteCount(photo.byteCount))")
                                .font(.dm(14, relativeTo: .footnote))
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the photo")
            }
        }
        .padding(4)
        .card(padding: 18)
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \MaintenanceRecord.createdAt, order: .reverse) var records: [MaintenanceRecord]
    NavigationStack {
        if let record = records.first {
            RecordDetailView(record: record)
        }
    }
}
