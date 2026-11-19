//
//  VehicleFormView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// Adds a new vehicle, or edits an existing one when `vehicle` is provided.
struct VehicleFormView: View {
    let vehicle: Vehicle?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [PickedImage]
    @State private var make: String
    @State private var model: String
    @State private var year: String
    @State private var trim: String
    @State private var plate: String
    @State private var mileage: String
    @State private var distanceUnit: DistanceUnit
    @State private var vin: String
    @State private var fuelType: FuelType
    @State private var nickname: String
    @State private var color: String
    @State private var driver: Driver?

    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        // Existing photos keep their model IDs so edits can be diffed on save.
        _photos = State(initialValue: vehicle?.sortedPhotos.compactMap { photo in
            photo.data.map { PickedImage(id: photo.id, data: $0) }
        } ?? [])
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _year = State(initialValue: vehicle?.year.map(String.init) ?? "")
        _trim = State(initialValue: vehicle?.trim ?? "")
        _plate = State(initialValue: vehicle?.plateNumber ?? "")
        _mileage = State(initialValue: vehicle.map { $0.odometer.formatted(.number.grouping(.never)) } ?? "")
        _distanceUnit = State(initialValue: vehicle?.distanceUnit ?? .current)
        _vin = State(initialValue: vehicle?.vin ?? "")
        _fuelType = State(initialValue: vehicle?.fuelType ?? .petrol)
        _nickname = State(initialValue: vehicle?.nickname ?? "")
        _color = State(initialValue: vehicle?.color ?? "")
        _driver = State(initialValue: vehicle?.driver)
    }

    private var isEditing: Bool { vehicle != nil }

    private var isValid: Bool {
        !photos.isEmpty
            && !make.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                photosSection
                detailsSection
                moreDetailsSection
                driverSection

                VStack(spacing: 10) {
                    Button(isEditing ? "Save changes" : "Add vehicle", action: save)
                        .buttonStyle(.primary)
                        .disabled(!isValid)
                    if !isValid {
                        Text("Add at least one photo, a make, and a model.")
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
        .navigationTitle(isEditing ? "Edit vehicle" : "Add vehicle")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionEyebrow("Vehicle photos")
                Spacer()
                Text("\(photos.count)/\(Vehicle.maxPhotos)")
                    .font(.dm(14, relativeTo: .footnote))
                    .foregroundStyle(Color.secondaryText)
            }
            MultiImageField(images: $photos, maxCount: Vehicle.maxPhotos)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow("Vehicle details")
            HStack(spacing: 14) {
                StyledTextField(label: "Make", placeholder: "e.g. BMW", text: $make)
                StyledTextField(label: "Model", placeholder: "e.g. M3", text: $model)
            }
            HStack(spacing: 14) {
                StyledTextField(label: "Year", placeholder: "2025", text: $year, keyboard: .numberPad)
                StyledTextField(label: "Trim", placeholder: "Competition", text: $trim)
            }
            StyledTextField(label: "License plate", placeholder: "ABC 1234", text: $plate, capitalization: .characters)
            LabeledField(label: "Current mileage") {
                HStack(spacing: 12) {
                    TextField(
                        "Current mileage",
                        text: $mileage,
                        prompt: Text("24,680").foregroundStyle(Color.placeholderText)
                    )
                    .keyboardType(.decimalPad)
                    // Unit for this vehicle; all of its odometer fields use it.
                    Picker("Distance unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
        }
    }

    private var moreDetailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow("More details")
            StyledTextField(label: "VIN / Chassis number", placeholder: "17-character VIN", text: $vin, capitalization: .characters)
            LabeledField(label: "Fuel type") {
                Picker("Fuel type", selection: $fuelType) {
                    ForEach(FuelType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: 14) {
                StyledTextField(label: "Nickname", placeholder: "Weekend car", text: $nickname, capitalization: .sentences)
                StyledTextField(label: "Color", placeholder: "Alpine White", text: $color)
            }
        }
    }

    private var driverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Assigned driver")
            NavigationLink {
                DriverPickerView(selection: $driver)
            } label: {
                HStack(spacing: 16) {
                    if let driver {
                        AvatarView(
                            data: driver.photo,
                            cacheKey: "driver-\(driver.id)-\(driver.photo?.count ?? 0)",
                            initials: driver.initials
                        )
                    } else {
                        IconTile(systemName: "person.crop.circle.badge.plus", size: 56)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Driver")
                            .font(.dm(14, relativeTo: .footnote))
                            .foregroundStyle(Color.secondaryText)
                        Text(driver?.fullName ?? "Select a driver")
                            .font(.dm(18, .bold, relativeTo: .headline))
                            .foregroundStyle(Color.primaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                }
                .card(padding: 18)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Assigned driver, \(driver?.fullName ?? "none")")
        }
    }

    // MARK: Saving

    private func save() {
        let target = vehicle ?? {
            let newVehicle = Vehicle()
            modelContext.insert(newVehicle)
            return newVehicle
        }()

        target.make = make.trimmingCharacters(in: .whitespaces)
        target.model = model.trimmingCharacters(in: .whitespaces)
        target.year = Int(year.trimmingCharacters(in: .whitespaces))
        target.trim = trim.trimmingCharacters(in: .whitespaces)
        target.plateNumber = plate.trimmingCharacters(in: .whitespaces)
        target.odometer = (try? Double(mileage, format: .number)) ?? 0
        target.vin = vin.trimmingCharacters(in: .whitespaces)
        target.fuelType = fuelType
        target.distanceUnit = distanceUnit
        target.nickname = nickname.trimmingCharacters(in: .whitespaces)
        target.color = color.trimmingCharacters(in: .whitespaces)
        target.driver = driver

        syncPhotos(of: target)
        dismiss()
    }

    /// Removes deleted photos, adds new ones, and updates the order of the rest.
    private func syncPhotos(of target: Vehicle) {
        let keptIDs = Set(photos.map(\.id))
        for photo in target.photos where !keptIDs.contains(photo.id) {
            modelContext.delete(photo)
        }
        let existing = Dictionary(uniqueKeysWithValues: target.photos.map { ($0.id, $0) })
        for (index, picked) in photos.enumerated() {
            if let photo = existing[picked.id] {
                photo.order = index
            } else {
                let photo = VehiclePhoto(data: picked.data, order: index)
                photo.id = picked.id
                modelContext.insert(photo)
                photo.vehicle = target
            }
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        VehicleFormView(vehicle: nil)
    }
}
