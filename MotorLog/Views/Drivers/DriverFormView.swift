//
//  DriverFormView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// Adds a new driver, or edits an existing one when `driver` is provided.
struct DriverFormView: View {
    let driver: Driver?
    /// Called with the saved driver (used by the driver picker to auto-select it).
    var onSaved: ((Driver) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var photo: PickedImage?
    @State private var firstName: String
    @State private var lastName: String
    @State private var type: DriverType
    @State private var phone: String
    @State private var licenseFront: PickedImage?
    @State private var licenseBack: PickedImage?
    @State private var licenseNumber: String
    @State private var licenseExpiry: Date?

    init(driver: Driver?, onSaved: ((Driver) -> Void)? = nil) {
        self.driver = driver
        self.onSaved = onSaved
        _photo = State(initialValue: driver?.photo.map { PickedImage(data: $0) })
        _firstName = State(initialValue: driver?.firstName ?? "")
        _lastName = State(initialValue: driver?.lastName ?? "")
        _type = State(initialValue: driver?.type ?? .family)
        _phone = State(initialValue: driver?.phone ?? "")
        _licenseFront = State(initialValue: driver?.licenseFront.map { PickedImage(data: $0) })
        _licenseBack = State(initialValue: driver?.licenseBack.map { PickedImage(data: $0) })
        _licenseNumber = State(initialValue: driver?.licenseNumber ?? "")
        _licenseExpiry = State(initialValue: driver?.licenseExpiry)
    }

    private var isEditing: Bool { driver != nil }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                profilePhoto
                personalSection
                licenseSection

                VStack(spacing: 10) {
                    Button(isEditing ? "Save changes" : "Save driver", action: save)
                        .buttonStyle(.primary)
                        .disabled(!isValid)
                    if !isValid {
                        Text("Enter at least a first name.")
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
        .navigationTitle(isEditing ? "Edit driver" : "New driver")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Sections

    private var profilePhoto: some View {
        VStack(spacing: 10) {
            SingleImageField(title: "Add profile photo", image: $photo, isCircle: true)
                .frame(width: 130, height: 130)
            Text(photo == nil ? "Add profile photo" : "Change profile photo")
                .font(.dm(18, .bold, relativeTo: .headline))
                .foregroundStyle(Color.brandGreen)
            Text("Optional")
                .font(.dm(14, relativeTo: .footnote))
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow("Personal details")
            HStack(spacing: 14) {
                StyledTextField(label: "First name", placeholder: "First name", text: $firstName)
                StyledTextField(label: "Last name", placeholder: "Last name", text: $lastName)
            }
            LabeledField(label: "Driver type") {
                Menu {
                    Picker("Driver type", selection: $type) {
                        ForEach(DriverType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                } label: {
                    HStack {
                        Text(type.title).foregroundStyle(Color.primaryText)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(.rect)
                }
                .accessibilityLabel("Driver type, \(type.title)")
            }
            StyledTextField(label: "Phone", placeholder: "Phone number", text: $phone, keyboard: .phonePad)
        }
    }

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionEyebrow("Driver's license")
            HStack(spacing: 14) {
                SingleImageField(title: "License front", image: $licenseFront)
                SingleImageField(title: "License back", image: $licenseBack)
            }
            .frame(height: 150)

            StyledTextField(
                label: "License number",
                placeholder: "Enter license number",
                text: $licenseNumber,
                capitalization: .characters
            )

            LabeledField(label: "Expiry date") {
                if let expiry = licenseExpiry {
                    HStack {
                        DatePicker(
                            "Expiry date",
                            selection: Binding(get: { expiry }, set: { licenseExpiry = $0 }),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        Spacer()
                        Button("Clear", systemImage: "xmark.circle.fill") { licenseExpiry = nil }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color.secondaryText)
                    }
                } else {
                    Button {
                        licenseExpiry = Calendar.current.date(byAdding: .year, value: 1, to: .now)
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
        }
    }

    // MARK: Saving

    private func save() {
        let target = driver ?? {
            let newDriver = Driver()
            modelContext.insert(newDriver)
            return newDriver
        }()

        target.firstName = firstName.trimmingCharacters(in: .whitespaces)
        target.lastName = lastName.trimmingCharacters(in: .whitespaces)
        target.type = type
        target.phone = phone.trimmingCharacters(in: .whitespaces)
        target.licenseNumber = licenseNumber.trimmingCharacters(in: .whitespaces)
        target.licenseExpiry = licenseExpiry
        target.photo = photo?.data
        target.licenseFront = licenseFront?.data
        target.licenseBack = licenseBack?.data

        onSaved?(target)
        dismiss()
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        DriverFormView(driver: nil)
    }
}
