//
//  Enums.swift
//  MotorLog
//

import Foundation

/// Fuel / powertrain type of a vehicle.
enum FuelType: String, Codable, CaseIterable, Identifiable {
    case petrol, diesel, hybrid, electric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .petrol: "Petrol"
        case .diesel: "Diesel"
        case .hybrid: "Hybrid"
        case .electric: "Electric"
        }
    }
}

/// Relationship of a driver to the vehicle owner.
enum DriverType: String, Codable, CaseIterable, Identifiable {
    case owner, family, employee, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner: "Owner"
        case .family: "Family"
        case .employee: "Employee"
        case .other: "Other"
        }
    }
}

/// Kind of work captured in a maintenance record.
enum RecordType: String, Codable, CaseIterable, Identifiable {
    case maintenance, service, repair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maintenance: "Maintenance"
        case .service: "Service"
        case .repair: "Repair"
        }
    }

    var symbolName: String {
        switch self {
        case .maintenance: "wrench.adjustable"
        case .service: "wrench.and.screwdriver"
        case .repair: "hammer"
        }
    }
}

/// Unit for odometer readings. Each vehicle stores its own; new vehicles default to the device region.
enum DistanceUnit: String, Codable, CaseIterable, Identifiable {
    case kilometers, miles

    var id: String { rawValue }

    static var current: DistanceUnit {
        Locale.current.measurementSystem == .metric ? .kilometers : .miles
    }

    var symbol: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        }
    }
}

enum Formatters {
    /// Currency code from the device region, falling back to USD.
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static func currency(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode))
    }

    /// Formats an odometer value with the given unit, e.g. "24,680 mi".
    static func distance(_ value: Double, unit: DistanceUnit = .current) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit.symbol)"
    }

    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day(.twoDigits).year())
    }

    static func mediumDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func byteCount(_ count: Int) -> String {
        Int64(count).formatted(.byteCount(style: .file))
    }
}
