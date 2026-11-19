//
//  MotorLogApp.swift
//  MotorLog
//
//  Created by Sulochana Premadasa on 2026-11-09.
//

import SwiftData
import SwiftUI

@main
struct MotorLogApp: App {
    @State private var store = StoreManager()
    
    @Environment(\.scenePhase) private var modelScenePhase

    init() {
        Theme.configureNavigationBarFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .onChange(of: modelScenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        // Refresh entitlements immediately when returning to the foreground
                        Task {
                            await store.refreshEntitlements()
                        }
                    }
                }
        }
        .modelContainer(for: [
            Vehicle.self,
            VehiclePhoto.self,
            Driver.self,
            MaintenanceRecord.self,
            RecordPhoto.self
        ])
    }
}
