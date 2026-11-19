//
//  GarageView.swift
//  MotorLog
//

import SwiftData
import SwiftUI

/// First screen: every vehicle the person owns, one below the other.
struct GarageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var showsAddVehicle = false
    @State private var editingVehicle: Vehicle?
    @State private var vehiclePendingDeletion: Vehicle?
    @State private var limitReached: FreeTierLimit?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // In-content header so the screen starts right below the status bar.
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Garage")
                        .font(.dm(34, .bold, relativeTo: .largeTitle))
                        .foregroundStyle(Color.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    Text(vehicles.count == 1 ? "1 vehicle" : "\(vehicles.count) vehicles")
                        .font(.dm(17, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.secondaryText)
                }
                

                HStack(alignment: .center) {
                    SectionTitle(eyebrow: "Your vehicles", title: "Ready for the road")
                    Spacer()
                    CircleAddButton(accessibilityLabel: "Add vehicle") {
                        if store.canAddVehicle(currentCount: vehicles.count) {
                            showsAddVehicle = true
                        } else {
                            limitReached = .vehicles
                        }
                    }
                }

                if vehicles.isEmpty {
                    EmptyStateCard(
                        systemName: "car.side",
                        title: "No vehicles yet",
                        message: "Add your first vehicle to start tracking its maintenance, service, and repairs."
                    )
                }

                ForEach(vehicles) { vehicle in
                    NavigationLink(value: vehicle) {
                        VehicleCard(vehicle: vehicle)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit Vehicle", systemImage: "pencil") { editingVehicle = vehicle }
                        Button("Delete Vehicle", systemImage: "trash", role: .destructive) {
                            vehiclePendingDeletion = vehicle
                        }
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            vehiclePendingDeletion = vehicle
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 24)
        }
        .swipeActionsContainerIfAvailable()
        .screenBackground()
        .proUpgradePrompt(for: $limitReached)
        // Title is kept for the back-button menu on pushed screens; the bar itself is hidden here.
        .navigationTitle("My Garage")
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Vehicle.self) { vehicle in
            ServiceHistoryView(vehicle: vehicle)
        }
        .navigationDestination(isPresented: $showsAddVehicle) {
            VehicleFormView(vehicle: nil)
        }
        .navigationDestination(item: $editingVehicle) { vehicle in
            VehicleFormView(vehicle: vehicle)
        }
        .confirmationDialog("Delete vehicle?", presenting: $vehiclePendingDeletion, titleVisibility: .visible) { vehicle in
            Button("Delete \(vehicle.displayName)", role: .destructive) {
                modelContext.delete(vehicle)
            }
        } message: { _ in
            Text("This vehicle and all of its maintenance records will be permanently deleted.")
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        GarageView()
    }
}
