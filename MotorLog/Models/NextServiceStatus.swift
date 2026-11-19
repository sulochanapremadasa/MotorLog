//
//  NextServiceStatus.swift
//  MotorLog
//

import Foundation

/// Describes when a vehicle's next service is due, based on the latest record.
/// A due date takes precedence over a due odometer reading.
struct NextServiceStatus: Equatable {
    enum Kind: Equatable {
        case notScheduled
        case dueToday
        case dueInDays(Int)
        case overdueByDays(Int)
        case distanceRemaining(Double)
        case overdueByDistance(Double)
    }

    let kind: Kind
    let unit: DistanceUnit

    init(
        dueDate: Date?,
        dueOdometer: Double?,
        currentOdometer: Double,
        unit: DistanceUnit = .current,
        now: Date,
        calendar: Calendar = .current
    ) {
        self.unit = unit
        if let dueDate {
            let start = calendar.startOfDay(for: now)
            let end = calendar.startOfDay(for: dueDate)
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            if days == 0 {
                kind = .dueToday
            } else if days > 0 {
                kind = .dueInDays(days)
            } else {
                kind = .overdueByDays(-days)
            }
        } else if let dueOdometer {
            let remaining = dueOdometer - currentOdometer
            kind = remaining >= 0 ? .distanceRemaining(remaining) : .overdueByDistance(-remaining)
        } else {
            kind = .notScheduled
        }
    }

    var text: String {
        switch kind {
        case .notScheduled: "Not scheduled"
        case .dueToday: "Due today"
        case .dueInDays(let days): days == 1 ? "Due tomorrow" : "Due in \(days) days"
        case .overdueByDays(let days): days == 1 ? "Overdue by 1 day" : "Overdue by \(days) days"
        case .distanceRemaining(let distance): Formatters.distance(distance, unit: unit)
        case .overdueByDistance(let distance): "Overdue by \(Formatters.distance(distance, unit: unit))"
        }
    }

    var isOverdue: Bool {
        switch kind {
        case .overdueByDays, .overdueByDistance: true
        default: false
        }
    }

    var isScheduled: Bool { kind != .notScheduled }
}
