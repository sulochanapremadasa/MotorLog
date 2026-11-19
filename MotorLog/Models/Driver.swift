//
//  Driver.swift
//  MotorLog
//

import Foundation
import SwiftData

@Model
final class Driver {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var firstName: String = ""
    var lastName: String = ""
    var typeRaw: String = DriverType.family.rawValue
    var phone: String = ""
    var licenseNumber: String = ""
    var licenseExpiry: Date?

    @Attribute(.externalStorage) var photo: Data?
    @Attribute(.externalStorage) var licenseFront: Data?
    @Attribute(.externalStorage) var licenseBack: Data?

    /// Deleting a driver only unassigns them from their vehicles.
    @Relationship(deleteRule: .nullify, inverse: \Vehicle.driver)
    var vehicles: [Vehicle] = []

    init(firstName: String = "", lastName: String = "", createdAt: Date = .now) {
        self.firstName = firstName
        self.lastName = lastName
        self.createdAt = createdAt
    }

    var type: DriverType {
        get { DriverType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var fullName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Unnamed driver" : name
    }

    var initials: String {
        let letters = [firstName.first, lastName.first].compactMap { $0 }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// "2 vehicles · License exp. Sep 18, 2028"
    var summary: String {
        var parts = [vehicles.count == 1 ? "1 vehicle" : "\(vehicles.count) vehicles"]
        if let licenseExpiry {
            parts.append("License exp. \(Formatters.mediumDate(licenseExpiry))")
        }
        return parts.joined(separator: " · ")
    }
}
