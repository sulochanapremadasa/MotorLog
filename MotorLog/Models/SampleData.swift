//
//  SampleData.swift
//  MotorLog
//

import Foundation
import SwiftData
import SwiftUI

/// In-memory sample data used by SwiftUI previews.
struct SampleData: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        let container = try ModelContainer(
            for: Vehicle.self, Driver.self, MaintenanceRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        populate(container.mainContext)
        return container
    }

    func body(content: Content, context: ModelContainer) -> some View {
        PreviewStoreHost {
            content.modelContainer(context)
        }
    }

    static func populate(_ context: ModelContext) {
        let alex = Driver(firstName: "Alex", lastName: "Morgan")
        alex.type = .owner
        alex.phone = "+1 555 0100"
        alex.licenseNumber = "D1234567"
        alex.licenseExpiry = Calendar.current.date(byAdding: .year, value: 3, to: .now)
        let jamie = Driver(firstName: "Jamie", lastName: "Chen")
        jamie.licenseExpiry = Calendar.current.date(byAdding: .month, value: 8, to: .now)
        context.insert(alex)
        context.insert(jamie)

        let bmw = Vehicle(make: "BMW", model: "M3", createdAt: .now.addingTimeInterval(-86_400 * 30))
        bmw.year = 2022
        bmw.trim = "Competition"
        bmw.plateNumber = "7XLM219"
        bmw.odometer = 24_680
        bmw.driver = alex
        context.insert(bmw)

        let porsche = Vehicle(make: "Porsche", model: "911")
        porsche.year = 2020
        porsche.trim = "Carrera S"
        porsche.plateNumber = "8RDK410"
        porsche.odometer = 31_240
        porsche.driver = alex
        context.insert(porsche)

        let oil = MaintenanceRecord(title: "Oil & filter change", type: .service, createdAt: .now.addingTimeInterval(-86_400 * 2))
        oil.serviceDate = .now.addingTimeInterval(-86_400 * 2)
        oil.odometer = 24_680
        oil.cost = 189
        oil.shopName = "Bavarian Motor Works"
        oil.notes = "Replaced engine oil with 0W-30 synthetic and installed OEM oil filter. Multi-point inspection completed with no issues found."
        oil.nextServiceOdometer = 26_000
        context.insert(oil)
        oil.vehicle = bmw

        let annual = MaintenanceRecord(title: "Annual service", type: .service, createdAt: .now.addingTimeInterval(-86_400 * 10))
        annual.serviceDate = .now.addingTimeInterval(-86_400 * 10)
        annual.odometer = 31_240
        annual.cost = 645
        annual.shopName = "Porsche Service Center"
        annual.nextServiceDate = .now.addingTimeInterval(86_400 * 12)
        context.insert(annual)
        annual.vehicle = porsche

        let tires = MaintenanceRecord(title: "Rear tire replacement", type: .repair, createdAt: .now.addingTimeInterval(-86_400 * 200))
        tires.serviceDate = .now.addingTimeInterval(-86_400 * 200)
        tires.odometer = 26_430
        tires.cost = 880
        tires.shopName = "City Tire & Auto"
        context.insert(tires)
        tires.vehicle = porsche
    }
}

/// Hosts a `StoreManager` for previews, mirroring what `MotorLogApp` injects at launch.
private struct PreviewStoreHost<Content: View>: View {
    @State private var store = StoreManager()
    @ViewBuilder var content: Content

    var body: some View {
        content.environment(store)
    }
}

extension PreviewTrait where T == Preview.ViewTraits {
    static var sampleData: Self { .modifier(SampleData()) }
}
