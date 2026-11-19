//
//  DriverPickerView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// Lets the person choose the driver assigned to a vehicle, or add a new one.
struct DriverPickerView: View {
    @Binding var selection: Driver?

    @Query(sort: [SortDescriptor(\Driver.firstName), SortDescriptor(\Driver.lastName)])
    private var drivers: [Driver]

    @State private var showsNewDriver = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(eyebrow: "All drivers", title: "Choose a driver")

                VStack(spacing: 0) {
                    row(title: "No driver", subtitle: "Leave this vehicle unassigned", driver: nil)
                    ForEach(drivers) { driver in
                        Divider().overlay(Color.cardBorder)
                        row(title: driver.fullName, subtitle: driver.summary, driver: driver)
                    }
                }
                .background(Color.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Color.cardBorder, lineWidth: 1)
                }

                DashedActionRow(title: "Add a new driver") {
                    showsNewDriver = true
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 16)
        }
        .screenBackground()
        .navigationTitle("Drivers")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showsNewDriver) {
            // A newly created driver is selected automatically.
            DriverFormView(driver: nil) { newDriver in
                selection = newDriver
            }
        }
    }

    private func row(title: String, subtitle: String, driver: Driver?) -> some View {
        let isSelected = selection?.id == driver?.id

        return Button {
            selection = driver
        } label: {
            HStack(spacing: 16) {
                if let driver {
                    AvatarView(
                        data: driver.photo,
                        cacheKey: "driver-\(driver.id)-\(driver.photo?.count ?? 0)",
                        initials: driver.initials
                    )
                } else {
                    IconTile(systemName: "person.slash", size: 56)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.dm(18, .semibold, relativeTo: .headline))
                        .foregroundStyle(Color.primaryText)
                    Text(subtitle)
                        .font(.dm(14, relativeTo: .footnote))
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.brandGreen)
                }
            }
            .padding(18)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview(traits: .sampleData) {
    @Previewable @State var driver: Driver?
    NavigationStack {
        DriverPickerView(selection: $driver)
    }
}
