//
//  MotorLogTests.swift
//  MotorLogTests
//

import Foundation
import SwiftData
import Testing
@testable import MotorLog

@MainActor
struct DataModelTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: Vehicle.self, VehiclePhoto.self, Driver.self, MaintenanceRecord.self, RecordPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    @Test func deletingVehicleCascadesToRecordsAndPhotos() throws {
        let vehicle = Vehicle(make: "BMW", model: "M3")
        context.insert(vehicle)
        let photo = VehiclePhoto(data: Data([1, 2, 3]), order: 0)
        context.insert(photo)
        photo.vehicle = vehicle
        let record = MaintenanceRecord(title: "Oil change")
        context.insert(record)
        record.vehicle = vehicle
        let receipt = RecordPhoto(data: Data([4]), name: "Receipt 1", order: 0)
        context.insert(receipt)
        receipt.record = record
        try context.save()

        context.delete(vehicle)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Vehicle>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<VehiclePhoto>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<MaintenanceRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RecordPhoto>()) == 0)
    }

    @Test func deletingDriverUnassignsVehicles() throws {
        let driver = Driver(firstName: "Alex", lastName: "Morgan")
        let vehicle = Vehicle(make: "Porsche", model: "911")
        context.insert(driver)
        context.insert(vehicle)
        vehicle.driver = driver
        try context.save()
        #expect(driver.vehicles.count == 1)

        context.delete(driver)
        try context.save()

        let vehicles = try context.fetch(FetchDescriptor<Vehicle>())
        #expect(vehicles.count == 1)
        #expect(vehicles.first?.driver == nil)
    }

    @Test func recordsSortByServiceDate() throws {
        let vehicle = Vehicle(make: "BMW", model: "M3")
        context.insert(vehicle)
        let base = Date(timeIntervalSince1970: 1_000_000)
        for (index, title) in ["First", "Second", "Third"].enumerated() {
            // Creation dates intentionally run opposite to service dates to prove sorting uses serviceDate.
            let record = MaintenanceRecord(title: title, createdAt: base.addingTimeInterval(Double(-index) * 60))
            record.serviceDate = base.addingTimeInterval(Double(index) * 86_400)
            context.insert(record)
            record.vehicle = vehicle
        }

        #expect(vehicle.records(newestFirst: true).map(\.title) == ["Third", "Second", "First"])
        #expect(vehicle.records(newestFirst: false).map(\.title) == ["First", "Second", "Third"])
    }

    @Test func recordsWithSameServiceDateFallBackToCreationDate() throws {
        let vehicle = Vehicle(make: "BMW", model: "M3")
        context.insert(vehicle)
        let base = Date(timeIntervalSince1970: 1_000_000)
        for (index, title) in ["First", "Second", "Third"].enumerated() {
            let record = MaintenanceRecord(title: title, createdAt: base.addingTimeInterval(Double(index) * 60))
            record.serviceDate = base
            context.insert(record)
            record.vehicle = vehicle
        }

        #expect(vehicle.records(newestFirst: true).map(\.title) == ["Third", "Second", "First"])
        #expect(vehicle.records(newestFirst: false).map(\.title) == ["First", "Second", "Third"])
    }

    @Test func nextServiceComesFromLatestRecord() throws {
        let vehicle = Vehicle(make: "BMW", model: "M3")
        vehicle.odometer = 24_680
        context.insert(vehicle)
        let now = Date(timeIntervalSince1970: 1_000_000)

        let older = MaintenanceRecord(title: "Old")
        older.serviceDate = now.addingTimeInterval(-86_400 * 100)
        older.nextServiceDate = now.addingTimeInterval(86_400 * 5)
        context.insert(older)
        older.vehicle = vehicle

        let latest = MaintenanceRecord(title: "Latest")
        latest.serviceDate = now.addingTimeInterval(-86_400)
        latest.nextServiceOdometer = 26_000
        context.insert(latest)
        latest.vehicle = vehicle

        #expect(vehicle.nextServiceStatus(now: now).kind == .distanceRemaining(1_320))
    }

    @Test(arguments: [RecordType.maintenance, RecordType.repair])
    func nextServiceIgnoresNonServiceRecords(type: RecordType) throws {
        let vehicle = Vehicle(make: "Nissan", model: "FB 15")
        vehicle.odometer = 114_800
        context.insert(vehicle)
        let now = Date(timeIntervalSince1970: 1_000_000)

        let service = MaintenanceRecord(title: "Full service", type: .service)
        service.serviceDate = now.addingTimeInterval(-86_400 * 30)
        service.nextServiceOdometer = 119_800
        context.insert(service)
        service.vehicle = vehicle

        // A newer maintenance/repair record without next-service values must not hide the service's values.
        let other = MaintenanceRecord(title: "Replace tyre", type: type)
        other.serviceDate = now
        context.insert(other)
        other.vehicle = vehicle

        #expect(vehicle.latestServiceRecord?.title == "Full service")
        #expect(vehicle.nextServiceStatus(now: now).kind == .distanceRemaining(5_000))
    }

    @Test func nextServiceNotScheduledWithOnlyRepairs() throws {
        let vehicle = Vehicle(make: "Nissan", model: "FB 15")
        context.insert(vehicle)
        let repair = MaintenanceRecord(title: "Replace tyre", type: .repair)
        repair.nextServiceOdometer = 120_000
        context.insert(repair)
        repair.vehicle = vehicle

        #expect(vehicle.nextServiceStatus().kind == .notScheduled)
    }
}

struct NextServiceStatusTests {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func notScheduledWithoutValues() {
        let status = NextServiceStatus(dueDate: nil, dueOdometer: nil, currentOdometer: 0, now: now, calendar: calendar)
        #expect(status.kind == .notScheduled)
        #expect(status.text == "Not scheduled")
        #expect(!status.isScheduled)
    }

    @Test(arguments: [(12, "Due in 12 days"), (1, "Due tomorrow"), (0, "Due today")])
    func dueDateInFuture(days: Int, expected: String) throws {
        let due = try #require(calendar.date(byAdding: .day, value: days, to: now))
        let status = NextServiceStatus(dueDate: due, dueOdometer: nil, currentOdometer: 0, now: now, calendar: calendar)
        #expect(status.text == expected)
        #expect(!status.isOverdue)
    }

    @Test func overdueDate() throws {
        let due = try #require(calendar.date(byAdding: .day, value: -3, to: now))
        let status = NextServiceStatus(dueDate: due, dueOdometer: nil, currentOdometer: 0, now: now, calendar: calendar)
        #expect(status.kind == .overdueByDays(3))
        #expect(status.isOverdue)
    }

    @Test func dateTakesPrecedenceOverOdometer() throws {
        let due = try #require(calendar.date(byAdding: .day, value: 4, to: now))
        let status = NextServiceStatus(dueDate: due, dueOdometer: 30_000, currentOdometer: 10_000, now: now, calendar: calendar)
        #expect(status.kind == .dueInDays(4))
    }

    @Test func odometerRemainingAndOverdue() {
        let remaining = NextServiceStatus(dueDate: nil, dueOdometer: 26_000, currentOdometer: 24_680, now: now, calendar: calendar)
        #expect(remaining.kind == .distanceRemaining(1_320))

        let overdue = NextServiceStatus(dueDate: nil, dueOdometer: 26_000, currentOdometer: 26_500, now: now, calendar: calendar)
        #expect(overdue.kind == .overdueByDistance(500))
        #expect(overdue.isOverdue)
    }
}

struct DisplayTests {
    @Test func vehicleDisplayNames() {
        let vehicle = Vehicle(make: "Porsche", model: "911")
        vehicle.trim = "Carrera S"
        vehicle.year = 2020
        #expect(vehicle.displayName == "Porsche 911")
        #expect(vehicle.trimAndYear == "Carrera S · 2020")

        let nicknamed = Vehicle()
        nicknamed.nickname = "Weekend car"
        #expect(nicknamed.displayName == "Weekend car")
    }

    @Test func vehicleUsesItsOwnDistanceUnit() {
        let vehicle = Vehicle(make: "BMW", model: "M3")
        vehicle.distanceUnit = .miles
        #expect(vehicle.formattedDistance(1_320).hasSuffix(" mi"))
        vehicle.distanceUnit = .kilometers
        #expect(vehicle.formattedDistance(1_320).hasSuffix(" km"))

        // Vehicles saved before the unit option existed fall back to the device region.
        let legacy = Vehicle()
        legacy.distanceUnitRaw = ""
        #expect(legacy.distanceUnit == DistanceUnit.current)
    }

    @Test func driverNameAndInitials() {
        let driver = Driver(firstName: "Jamie", lastName: "Chen")
        #expect(driver.fullName == "Jamie Chen")
        #expect(driver.initials == "JC")
        #expect(driver.summary == "0 vehicles")
    }
}

@MainActor
struct FreeTierLimitTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        container = try ModelContainer(
            for: Vehicle.self, VehiclePhoto.self, Driver.self, MaintenanceRecord.self, RecordPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    @Test func freePlanAllowsUpToThreeVehicles() {
        #expect(FreeTierLimits.maxVehicles == 3)
        #expect(FreeTierLimits.canAddVehicle(currentCount: 0, isPro: false))
        #expect(FreeTierLimits.canAddVehicle(currentCount: 2, isPro: false))
        #expect(!FreeTierLimits.canAddVehicle(currentCount: 3, isPro: false))
        #expect(!FreeTierLimits.canAddVehicle(currentCount: 10, isPro: false))
    }

    @Test func proRemovesVehicleCap() {
        #expect(FreeTierLimits.canAddVehicle(currentCount: 3, isPro: true))
        #expect(FreeTierLimits.canAddVehicle(currentCount: 50, isPro: true))
    }

    @Test func recordCapIsPerVehicle() throws {
        let full = Vehicle(make: "BMW", model: "M3")
        let empty = Vehicle(make: "Porsche", model: "911")
        context.insert(full)
        context.insert(empty)
        for index in 0..<FreeTierLimits.maxRecordsPerVehicle {
            let record = MaintenanceRecord(title: "Record \(index)")
            context.insert(record)
            record.vehicle = full
        }
        try context.save()

        #expect(full.records.count == 20)
        #expect(!FreeTierLimits.canAddRecord(currentCount: full.records.count, isPro: false))
        // A second vehicle has its own allowance even when another one is full.
        #expect(FreeTierLimits.canAddRecord(currentCount: empty.records.count, isPro: false))
    }

    @Test func proRemovesRecordCap() throws {
        let vehicle = Vehicle(make: "Nissan", model: "FB 15")
        context.insert(vehicle)
        for index in 0..<(FreeTierLimits.maxRecordsPerVehicle + 5) {
            let record = MaintenanceRecord(title: "Record \(index)")
            context.insert(record)
            record.vehicle = vehicle
        }
        try context.save()

        #expect(!FreeTierLimits.canAddRecord(currentCount: vehicle.records.count, isPro: false))
        #expect(FreeTierLimits.canAddRecord(currentCount: vehicle.records.count, isPro: true))
    }

    @Test func planIdentifiersMatchStoreKitConfiguration() {
        #expect(ProPlan.monthly.productID == "com.sulo.MotorLog.monthly")
        #expect(ProPlan.annual.productID == "com.sulo.MotorLog.annual")
        #expect(ProPlan.lifetime.productID == "com.sulo.MotorLog.lifetime")
        #expect(!ProPlan.lifetime.isAutoRenewable)
        #expect(ProPlan.lifetime.rank > ProPlan.annual.rank && ProPlan.annual.rank > ProPlan.monthly.rank)
    }
}
