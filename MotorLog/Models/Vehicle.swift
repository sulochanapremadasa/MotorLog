//
//  Vehicle.swift
//  MotorLog
//

import Foundation
import SwiftData

@Model
final class Vehicle {
    static let maxPhotos = 3

    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var make: String = ""
    var model: String = ""
    var year: Int?
    var trim: String = ""
    var plateNumber: String = ""
    var odometer: Double = 0
    var vin: String = ""
    var fuelTypeRaw: String = FuelType.petrol.rawValue
    /// Empty for vehicles saved before units were selectable; those fall back to the device region.
    var distanceUnitRaw: String = ""
    var nickname: String = ""
    var color: String = ""

    @Relationship(deleteRule: .cascade, inverse: \VehiclePhoto.vehicle)
    var photos: [VehiclePhoto] = []

    var driver: Driver?

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceRecord.vehicle)
    var records: [MaintenanceRecord] = []

    init(make: String = "", model: String = "", createdAt: Date = .now) {
        self.make = make
        self.model = model
        self.createdAt = createdAt
    }

    var fuelType: FuelType {
        get { FuelType(rawValue: fuelTypeRaw) ?? .petrol }
        set { fuelTypeRaw = newValue.rawValue }
    }

    /// Unit used for this vehicle's mileage and all of its records' odometer readings.
    var distanceUnit: DistanceUnit {
        get { DistanceUnit(rawValue: distanceUnitRaw) ?? .current }
        set { distanceUnitRaw = newValue.rawValue }
    }

    func formattedDistance(_ value: Double) -> String {
        Formatters.distance(value, unit: distanceUnit)
    }

    /// "BMW M3", or the nickname when make/model are empty.
    var displayName: String {
        let name = [make, model].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? (nickname.isEmpty ? "Untitled vehicle" : nickname) : name
    }

    /// "Competition · 2022"
    var trimAndYear: String {
        [trim, year.map(String.init) ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var sortedPhotos: [VehiclePhoto] {
        photos.sorted { $0.order < $1.order }
    }

    var coverPhotoData: Data? {
        sortedPhotos.first?.data
    }

    /// Most recent record of type `.service` by service date (ties broken by creation date).
    /// Maintenance and repair records don't affect the next service.
    var latestServiceRecord: MaintenanceRecord? {
        records
            .filter { $0.type == .service }
            .max { lhs, rhs in
                if lhs.serviceDate == rhs.serviceDate { return lhs.createdAt < rhs.createdAt }
                return lhs.serviceDate < rhs.serviceDate
            }
    }

    /// Next-service mileage saved on the latest service record.
    var nextServiceOdometer: Double? {
        latestServiceRecord?.nextServiceOdometer
    }

    func nextServiceStatus(now: Date = .now) -> NextServiceStatus {
        let record = latestServiceRecord
        return NextServiceStatus(
            dueDate: record?.nextServiceDate,
            dueOdometer: record?.nextServiceOdometer,
            currentOdometer: odometer,
            unit: distanceUnit,
            now: now
        )
    }

    /// Records sorted by service date. Records with the same service date fall back to creation date.
    func records(newestFirst: Bool) -> [MaintenanceRecord] {
        records.sorted { lhs, rhs in
            if lhs.serviceDate != rhs.serviceDate {
                return newestFirst ? lhs.serviceDate > rhs.serviceDate : lhs.serviceDate < rhs.serviceDate
            }
            return newestFirst ? lhs.createdAt > rhs.createdAt : lhs.createdAt < rhs.createdAt
        }
    }
}

@Model
final class VehiclePhoto {
    var id: UUID = UUID()
    var order: Int = 0
    @Attribute(.externalStorage) var data: Data?
    var vehicle: Vehicle?

    init(data: Data, order: Int) {
        self.data = data
        self.order = order
    }
}
