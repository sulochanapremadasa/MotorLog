//
//  SettingsView.swift
//  MotorLog
//

import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @AppStorage(StorageKeys.appearance) private var appearance = AppearanceMode.system
    @AppStorage(StorageKeys.dataResetID) private var dataResetID = 0

    @State private var confirmsErase = false
    @State private var eraseError: String?
    @State private var showsPaywall = false
    @State private var showsManageSubscriptions = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // In-content header so the screen starts right below the status bar.
                Text("Settings")
                    .font(.dm(34, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Color.primaryText)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow("iMotorLog Pro")
                    proCard
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow("Appearance")
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Theme", systemImage: "circle.lefthalf.filled")
                            .font(.dm(17, .semibold, relativeTo: .headline))
                            .foregroundStyle(Color.primaryText)
                        Picker("Theme", selection: $appearance) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .card(padding: 18)
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow("Data")
                    VStack(alignment: .leading, spacing: 14) {
                        Text("All vehicles, drivers, records, and photos are stored only on this device.")
                            .font(.dm(15, relativeTo: .subheadline))
                            .foregroundStyle(Color.secondaryText)
                        Button {
                            confirmsErase = true
                        } label: {
                            Label("Erase all data", systemImage: "trash")
                        }
                        .buttonStyle(.destructiveSoft)
                    }
                    .card(padding: 18)
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionEyebrow("About")
                    HStack(spacing: 16) {
                        IconTile(systemName: "car.side", size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iMotorLog")
                                .font(.dm(18, .bold, relativeTo: .headline))
                                .foregroundStyle(Color.primaryText)
                            Text("Version \(appVersion)")
                                .font(.dm(15, relativeTo: .subheadline))
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                    }
                    .card(padding: 18)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.vertical, 8)
        }
        .screenBackground()
        // Title is kept for the back-button menu on pushed screens; the bar itself is hidden here.
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsPaywall, onDismiss: {
            // Make sure the Pro card reflects a purchase made in the paywall.
            Task { await store.refreshEntitlements() }
        }) {
            PaywallView()
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        .alert("Restore Purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .confirmationDialog("Erase all data?", isPresented: $confirmsErase, titleVisibility: .visible) {
            Button("Erase All Data", role: .destructive, action: eraseAllData)
        } message: {
            Text("Every vehicle, driver, maintenance record, and photo will be permanently deleted. This can't be undone.")
        }
        .alert("Couldn't erase data", isPresented: Binding(get: { eraseError != nil }, set: { if !$0 { eraseError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(eraseError ?? "")
        }
    }

    /// Current plan with the matching action: Upgrade on the free plan, Manage / Restore on Pro.
    private var proCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                IconTile(systemName: "crown.fill", size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isPro ? "iMotorLog Pro" : "Free plan")
                        .font(.dm(18, .bold, relativeTo: .headline))
                        .foregroundStyle(Color.primaryText)
                    Text(proSubtitle)
                        .font(.dm(15, relativeTo: .subheadline))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)

            if store.isPro {
                // Lifetime is a non-renewing purchase, so there is no subscription to manage.
                if store.activePlan?.isAutoRenewable == true {
                    Button {
                        showsManageSubscriptions = true
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                    .buttonStyle(.outline)
                }
                Button {
                    Task { await restorePurchases() }
                } label: {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.outline)
                .disabled(isRestoring)
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    Label("Upgrade to Pro", systemImage: "sparkles")
                }
                .buttonStyle(.primary)
            }
        }
        .card(padding: 18)
    }

    private var proSubtitle: String {
        if let plan = store.activePlanTitle {
            return "\(plan) plan · unlimited vehicles and service records."
        }
        return "Up to \(FreeTierLimits.maxVehicles) vehicles and \(FreeTierLimits.maxRecordsPerVehicle) service records per vehicle."
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            restoreMessage = try await store.restorePurchases()
                ? "iMotorLog Pro is active on this device."
                : "No iMotorLog Pro purchase was found for this Apple Account."
        } catch {
            restoreMessage = error.localizedDescription
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "\(version)"
    }

    private func eraseAllData() {
        // Batch deletes (`delete(model:)`) run in the store and can't apply the
        // cascade/nullify relationship rules, so they fail with constraint errors.
        // Deleting fetched objects lets SwiftData handle the relationships.
        // Reset the other tabs first so no pushed screen re-renders a deleted model.
        dataResetID += 1
        do {
            try deleteAll(Vehicle.self)          // cascades to photos, records and receipts
            try deleteAll(Driver.self)           // nullifies on vehicles
            // Remove anything left without a parent.
            try deleteAll(MaintenanceRecord.self)
            try deleteAll(RecordPhoto.self)
            try deleteAll(VehiclePhoto.self)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            eraseError = error.localizedDescription
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        for object in try modelContext.fetch(FetchDescriptor<T>()) {
            modelContext.delete(object)
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        SettingsView()
    }
}
