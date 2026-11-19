//
//  RecordFormView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// Adds a maintenance record to a vehicle, or edits an existing record.
struct RecordFormView: View {
    static let maxPhotos = 10

    let vehicle: Vehicle
    let record: MaintenanceRecord?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var type: RecordType
    @State private var title: String
    @State private var serviceDate: Date
    @State private var odometer: String
    @State private var cost: String
    @State private var shopName: String
    @State private var notes: String
    @State private var nextServiceDate: Date?
    @State private var nextServiceOdometer: String
    @State private var photos: [PickedImage]

    init(vehicle: Vehicle, record: MaintenanceRecord?) {
        self.vehicle = vehicle
        self.record = record
        _type = State(initialValue: record?.type ?? .service)
        _title = State(initialValue: record?.title ?? "")
        _serviceDate = State(initialValue: record?.serviceDate ?? .now)
        // Default a new record's odometer to the vehicle's current mileage.
        _odometer = State(initialValue: (record?.odometer ?? vehicle.odometer).formatted(.number.grouping(.never)))
        _cost = State(initialValue: record.map { $0.cost.formatted(.number.grouping(.never)) } ?? "")
        _shopName = State(initialValue: record?.shopName ?? "")
        _notes = State(initialValue: record?.notes ?? "")
        _nextServiceDate = State(initialValue: record?.nextServiceDate)
        _nextServiceOdometer = State(initialValue: record?.nextServiceOdometer.map { $0.formatted(.number.grouping(.never)) } ?? "")
        _photos = State(initialValue: record?.sortedPhotos.compactMap { photo in
            photo.data.map { PickedImage(id: photo.id, data: $0, name: photo.name) }
        } ?? [])
    }

    private var isEditing: Bool { record != nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                typeSection
                detailsSection
                // Only service records drive the vehicle's next service.
                if type == .service {
                    nextServiceSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                attachmentsSection

                VStack(spacing: 10) {
                    Button(isEditing ? "Save changes" : "Add record", action: save)
                        .buttonStyle(.primary)
                        .disabled(!isValid)
                    if !isValid {
                        Text("Enter a title for this record.")
                            .font(.dm(14, relativeTo: .footnote))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle(isEditing ? "Edit record" : "New record")
        .navigationSubtitleIfAvailable(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Type")
            HStack(spacing: 12) {
                ForEach(RecordType.allCases) { option in
                    let isSelected = option == type
                    Button {
                        withAnimation(.snappy) { type = option }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: option.symbolName)
                                .font(.system(size: 22))
                            Text(option.title)
                                .font(.dm(14, .semibold, relativeTo: .footnote))
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.brandGreen)
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(isSelected ? Color.brandGreen : Color.cardBackground, in: .rect(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isSelected ? Color.clear : Color.cardBorder, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow("Record details")
            StyledTextField(label: "Title", placeholder: "e.g. Oil & filter change", text: $title, capitalization: .sentences)
            LabeledField(label: "Service date") {
                DatePicker("Service date", selection: $serviceDate, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 14) {
                StyledTextField(
                    label: "Odometer",
                    placeholder: "24,680",
                    text: $odometer,
                    keyboard: .decimalPad,
                    suffix: vehicle.distanceUnit.symbol
                )
                StyledTextField(
                    label: "Total cost",
                    placeholder: "0.00",
                    text: $cost,
                    keyboard: .decimalPad,
                    suffix: Formatters.currencyCode
                )
            }
            StyledTextField(label: "Service provider", placeholder: "e.g. City Tire & Auto", text: $shopName)
            LabeledField(label: "Notes") {
                TextField(
                    "Notes",
                    text: $notes,
                    prompt: Text("What was done?").foregroundStyle(Color.placeholderText),
                    axis: .vertical
                )
                .lineLimit(4...10)
                .padding(.vertical, 16)
            }
        }
    }

    private var nextServiceSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow("Next service (optional)")
            LabeledField(label: "Due date") {
                if let date = nextServiceDate {
                    HStack {
                        DatePicker(
                            "Next service date",
                            selection: Binding(get: { date }, set: { nextServiceDate = $0 }),
                            in: serviceDate...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        Spacer()
                        Button("Clear", systemImage: "xmark.circle.fill") { nextServiceDate = nil }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color.secondaryText)
                    }
                } else {
                    Button {
                        nextServiceDate = Calendar.current.date(byAdding: .month, value: 6, to: serviceDate)
                    } label: {
                        HStack {
                            Text("Select a date").foregroundStyle(Color.placeholderText)
                            Spacer()
                            Image(systemName: "calendar").foregroundStyle(Color.primaryText)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            StyledTextField(
                label: "Due at mileage",
                placeholder: "e.g. 30,000",
                text: $nextServiceOdometer,
                keyboard: .decimalPad,
                suffix: vehicle.distanceUnit.symbol
            )
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionEyebrow("Receipts & documents")
                Spacer()
                Text("\(photos.count)/\(Self.maxPhotos)")
                    .font(.dm(14, relativeTo: .footnote))
                    .foregroundStyle(Color.secondaryText)
            }
            MultiImageField(images: $photos, maxCount: Self.maxPhotos, tileTitle: "Add receipt", tileSize: 120)
        }
    }

    // MARK: Saving

    private func save() {
        let target = record ?? {
            let newRecord = MaintenanceRecord()
            modelContext.insert(newRecord)
            newRecord.vehicle = vehicle
            return newRecord
        }()

        let odometerValue = (try? Double(odometer, format: .number)) ?? 0
        target.type = type
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.serviceDate = serviceDate
        target.odometer = odometerValue
        target.cost = (try? Decimal(cost, format: .number)) ?? 0
        target.shopName = shopName.trimmingCharacters(in: .whitespaces)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        // Next-service values only apply to service records; clear them for other types.
        if type == .service {
            target.nextServiceDate = nextServiceDate
            target.nextServiceOdometer = nextServiceOdometer.isEmpty ? nil : try? Double(nextServiceOdometer, format: .number)
        } else {
            target.nextServiceDate = nil
            target.nextServiceOdometer = nil
        }

        // Keep the vehicle's mileage current when a newer reading is logged.
        if odometerValue > vehicle.odometer {
            vehicle.odometer = odometerValue
        }

        syncPhotos(of: target)
        dismiss()
    }

    /// Removes deleted photos, adds new ones, and updates the order of the rest.
    private func syncPhotos(of target: MaintenanceRecord) {
        let keptIDs = Set(photos.map(\.id))
        for photo in target.photos where !keptIDs.contains(photo.id) {
            modelContext.delete(photo)
        }
        let existing = Dictionary(uniqueKeysWithValues: target.photos.map { ($0.id, $0) })
        for (index, picked) in photos.enumerated() {
            if let photo = existing[picked.id] {
                photo.order = index
            } else {
                let name = "Receipt \(index + 1)"
                let photo = RecordPhoto(data: picked.data, name: name, order: index)
                photo.id = picked.id
                modelContext.insert(photo)
                photo.record = target
            }
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var vehicles: [Vehicle]
    NavigationStack {
        if let vehicle = vehicles.first {
            RecordFormView(vehicle: vehicle, record: nil)
        }
    }
}
