//
//  DriversView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// Drivers tab: everyone who drives the person's vehicles.
struct DriversView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Driver.firstName), SortDescriptor(\Driver.lastName)])
    private var drivers: [Driver]

    @State private var showsNewDriver = false
    @State private var driverPendingDeletion: Driver?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                banner

                SectionTitle(eyebrow: "All drivers", title: "Your drivers")

                if drivers.isEmpty {
                    EmptyStateCard(
                        systemName: "person.2",
                        title: "No drivers yet",
                        message: "Add the people who drive your vehicles."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(drivers) { driver in
                            if driver.id != drivers.first?.id {
                                Divider().overlay(Color.cardBorder)
                            }
                            NavigationLink(value: driver) {
                                DriverRow(driver: driver)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete Driver", systemImage: "trash", role: .destructive) {
                                    driverPendingDeletion = driver
                                }
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    driverPendingDeletion = driver
                                }
                            }
                        }
                    }
                    .background(Color.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
                    .clipShape(.rect(cornerRadius: Theme.cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Color.cardBorder, lineWidth: 1)
                    }
                }

                DashedActionRow(title: "Add a new driver") {
                    showsNewDriver = true
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 8)
        }
        .swipeActionsContainerIfAvailable()
        .screenBackground()
        .navigationTitle("Drivers")
        .navigationSubtitleIfAvailable(drivers.count == 1 ? "1 person" : "\(drivers.count) people")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add driver", systemImage: "plus") {
                    showsNewDriver = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
            }
        }
        .navigationDestination(for: Driver.self) { driver in
            DriverFormView(driver: driver)
        }
        .navigationDestination(isPresented: $showsNewDriver) {
            DriverFormView(driver: nil)
        }
        .confirmationDialog("Delete driver?", presenting: $driverPendingDeletion, titleVisibility: .visible) { driver in
            Button("Delete \(driver.fullName)", role: .destructive) {
                modelContext.delete(driver)
            }
        } message: { driver in
            Text(driver.vehicles.isEmpty
                 ? "This driver will be permanently deleted."
                 : "This driver will be removed from their assigned vehicles and permanently deleted.")
        }
    }

    private var banner: some View {
        HStack(alignment: .top, spacing: 18) {
            IconTile(systemName: "person.2", size: 64, background: .cardBackground)
            VStack(alignment: .leading, spacing: 6) {
                Text("Keep everyone organized")
                    .font(.dm(19, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.primaryText)
                Text("Assign drivers to vehicles and keep license details close at hand.")
                    .font(.dm(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandGreenSoft.opacity(0.8), in: .rect(cornerRadius: Theme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius).strokeBorder(Color.brandGreen.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Avatar, name and "2 vehicles · License exp. …" summary.
struct DriverRow: View {
    let driver: Driver

    var body: some View {
        HStack(spacing: 18) {
            AvatarView(
                data: driver.photo,
                cacheKey: "driver-\(driver.id)-\(driver.photo?.count ?? 0)",
                initials: driver.initials,
                size: 64
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.fullName)
                    .font(.dm(19, .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.primaryText)
                Text(driver.summary)
                    .font(.dm(14, relativeTo: .footnote))
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primaryText)
                .accessibilityHidden(true)
        }
        .padding(18)
        .background(Color.cardBackground)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        DriversView()
    }
}
