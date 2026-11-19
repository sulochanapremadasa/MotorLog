//
//  ServiceHistoryView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// A vehicle's maintenance timeline, sorted by service date.
struct ServiceHistoryView: View {
    let vehicle: Vehicle

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var newestFirst = true
    @State private var showsAddRecord = false
    @State private var showsEditVehicle = false
    @State private var confirmsVehicleDeletion = false
    @State private var recordPendingDeletion: MaintenanceRecord?
    @State private var limitReached: FreeTierLimit?

    var body: some View {
        let records = vehicle.records(newestFirst: newestFirst)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VehicleHero(vehicle: vehicle)
                NextServiceTile(status: vehicle.nextServiceStatus())

                HStack(alignment: .bottom) {
                    SectionTitle(eyebrow: "Timeline", title: "Maintenance records")
                    Spacer()
                    sortToggle
                }
                .padding(.top, 8)

                if records.isEmpty {
                    EmptyStateCard(
                        systemName: "wrench.and.screwdriver",
                        title: "No records yet",
                        message: "Tap + to log the first maintenance, service, or repair for this vehicle."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                TimelineRow(record: record, isLast: record.id == records.last?.id)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete Record", systemImage: "trash", role: .destructive) {
                                    recordPendingDeletion = record
                                }
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    recordPendingDeletion = record
                                }
                            }
                        }
                    }
                }

                Button {
                    confirmsVehicleDeletion = true
                } label: {
                    Label("Delete vehicle", systemImage: "trash")
                }
                .buttonStyle(.destructiveSoft)
                .padding(.top, 12)
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 12)
        }
        .swipeActionsContainerIfAvailable()
        .screenBackground()
        .proUpgradePrompt(for: $limitReached)
        .navigationTitle("Service history")
        .navigationSubtitleIfAvailable(vehicle.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Edit Vehicle", systemImage: "pencil") { showsEditVehicle = true }
                    Button("Delete Vehicle", systemImage: "trash", role: .destructive) {
                        confirmsVehicleDeletion = true
                    }
                }
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add record", systemImage: "plus") {
                    if store.canAddRecord(to: vehicle) {
                        showsAddRecord = true
                    } else {
                        limitReached = .records
                    }
                }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
            }
        }
        .navigationDestination(for: MaintenanceRecord.self) { record in
            RecordDetailView(record: record)
        }
        .navigationDestination(isPresented: $showsAddRecord) {
            RecordFormView(vehicle: vehicle, record: nil)
        }
        .navigationDestination(isPresented: $showsEditVehicle) {
            VehicleFormView(vehicle: vehicle)
        }
        .confirmationDialog("Delete vehicle?", isPresented: $confirmsVehicleDeletion, titleVisibility: .visible) {
            Button("Delete \(vehicle.displayName)", role: .destructive) {
                dismiss()
                modelContext.delete(vehicle)
            }
        } message: {
            Text("This vehicle and all of its maintenance records will be permanently deleted.")
        }
        .confirmationDialog("Delete record?", presenting: $recordPendingDeletion, titleVisibility: .visible) { record in
            Button("Delete \(record.title)", role: .destructive) {
                modelContext.delete(record)
            }
        }
    }

    private var sortToggle: some View {
        Button {
            withAnimation(.snappy) { newestFirst.toggle() }
        } label: {
            Label(newestFirst ? "Newest" : "Oldest", systemImage: "line.3.horizontal.decrease")
                .font(.dm(16, .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.cardBackground, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort order, \(newestFirst ? "newest first" : "oldest first")")
        .accessibilityHint("Toggles the sort order")
    }
}

/// Large photo header with the vehicle name over a gradient. Pages through all photos.
struct VehicleHero: View {
    let vehicle: Vehicle

    var body: some View {
        let photos = vehicle.sortedPhotos

        ZStack(alignment: .bottomLeading) {
            if photos.count > 1 {
                TabView {
                    ForEach(photos) { photo in
                        StoredImage(data: photo.data, cacheKey: photo.id.uuidString, maxPixel: 1400)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            } else {
                StoredImage(data: photos.first?.data, cacheKey: photos.first?.id.uuidString ?? "none", maxPixel: 1400)
            }

            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                if !vehicle.trimAndYear.isEmpty {
                    Text(vehicle.trimAndYear)
                        .font(.dm(15, .medium, relativeTo: .subheadline))
                        .tracking(1.2)
                        .textCase(.uppercase)
                }
                Text(vehicle.displayName)
                    .font(.dm(30, .bold, relativeTo: .largeTitle))
                    .lineLimit(2)
                Text([vehicle.formattedDistance(vehicle.odometer), vehicle.plateNumber].filter { !$0.isEmpty }.joined(separator: "  •  "))
                    .font(.dm(17, .semibold, relativeTo: .body))
            }
            .foregroundStyle(.white)
            .padding(24)
            .padding(.bottom, photos.count > 1 ? 14 : 0)
            .allowsHitTesting(false)
        }
        .frame(height: 290)
        .clipShape(.rect(cornerRadius: 28))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vehicle.displayName), \(vehicle.trimAndYear), \(vehicle.formattedDistance(vehicle.odometer))")
    }
}

/// Card showing when the next service is due.
struct NextServiceTile: View {
    let status: NextServiceStatus

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 26))
                .foregroundStyle(status.isOverdue ? Color.destructive : Color.accentOrange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Next service")
                    .font(.dm(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.primaryText)
                Text(status.text)
                    .font(.dm(15, relativeTo: .subheadline))
                    .foregroundStyle(status.isOverdue ? Color.destructive : Color.secondaryText)
            }
            Spacer()
        }
        .card(padding: 20)
        .accessibilityElement(children: .combine)
    }
}

/// A record in the timeline: dot + date header, then a summary card.
struct TimelineRow: View {
    let record: MaintenanceRecord
    let isLast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 14, height: 14)
                    .padding(4)
                    .background(Color.brandGreenSoft, in: .circle)
                Text(Formatters.longDate(record.serviceDate))
                    .font(.dm(14, .semibold, relativeTo: .footnote))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondaryText)
            }

            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(width: 2)
                    .padding(.leading, 10)
                    .opacity(isLast ? 0 : 1)
                    .accessibilityHidden(true)

                HStack(spacing: 14) {
                    IconTile(systemName: record.type.symbolName, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.title)
                            .font(.dm(19, .semibold, relativeTo: .headline))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(2)
                        if !record.shopName.isEmpty {
                            Text(record.shopName)
                                .font(.dm(15, relativeTo: .subheadline))
                                .foregroundStyle(Color.secondaryText)
                        }
                        Text("\(Formatters.distance(record.odometer, unit: record.vehicle?.distanceUnit ?? .current))  ·  \(Formatters.currency(record.cost))")
                            .font(.dm(15, relativeTo: .subheadline))
                            .foregroundStyle(Color.primaryText.opacity(0.8))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                }
                .card(padding: 16)
                .padding(.leading, 14)
                .padding(.bottom, 20)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.type.title), \(record.title), \(Formatters.longDate(record.serviceDate)), \(Formatters.currency(record.cost))")
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Vehicle.createdAt, order: .reverse) var vehicles: [Vehicle]
    NavigationStack {
        if let vehicle = vehicles.first {
            ServiceHistoryView(vehicle: vehicle)
        }
    }
}
