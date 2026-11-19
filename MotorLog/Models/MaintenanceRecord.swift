//
//  MaintenanceRecord.swift
//  MotorLog
//

import Foundation
import SwiftData

@Model
final class MaintenanceRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var typeRaw: String = RecordType.service.rawValue
    var title: String = ""
    var serviceDate: Date = Date.now
    var odometer: Double = 0
    var cost: Decimal = 0
    var shopName: String = ""
    var notes: String = ""
    var nextServiceDate: Date?
    var nextServiceOdometer: Double?

    @Relationship(deleteRule: .cascade, inverse: \RecordPhoto.record)
    var photos: [RecordPhoto] = []

    var vehicle: Vehicle?

    init(title: String = "", type: RecordType = .service, createdAt: Date = .now) {
        self.title = title
        self.typeRaw = type.rawValue
        self.createdAt = createdAt
    }

    var type: RecordType {
        get { RecordType(rawValue: typeRaw) ?? .service }
        set { typeRaw = newValue.rawValue }
    }

    var sortedPhotos: [RecordPhoto] {
        photos.sorted { $0.order < $1.order }
    }
}

@Model
final class RecordPhoto {
    var id: UUID = UUID()
    var order: Int = 0
    var name: String = ""
    var byteCount: Int = 0
    @Attribute(.externalStorage) var data: Data?
    var record: MaintenanceRecord?

    init(data: Data, name: String, order: Int) {
        self.data = data
        self.name = name
        self.order = order
        self.byteCount = data.count
    }
}
