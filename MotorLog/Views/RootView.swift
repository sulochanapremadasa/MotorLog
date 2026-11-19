//
//  RootView.swift
//  MotorLog
//

import SwiftUI

/// Tab-based root: Garage, Drivers, Settings. Presents onboarding on first launch.
struct RootView: View {
    @AppStorage(StorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(StorageKeys.appearance) private var appearance = AppearanceMode.system
    /// Changing this discards pushed screens that may hold models deleted by "Erase all data".
    @AppStorage(StorageKeys.dataResetID) private var dataResetID = 0

    var body: some View {
        TabView {
            Tab("Garage", systemImage: "car") {
                NavigationStack {
                    GarageView()
                }
                .id(dataResetID)
            }
            Tab("Drivers", systemImage: "person.2") {
                NavigationStack {
                    DriversView()
                }
                .id(dataResetID)
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(.brandGreen)
        .font(.dm(17))
        .preferredColorScheme(appearance.colorScheme)
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}

#Preview(traits: .sampleData) {
    RootView()
}
