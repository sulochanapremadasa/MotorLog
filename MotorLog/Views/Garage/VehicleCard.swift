//
//  VehicleCard.swift
//  MotorLog
//

import SwiftUI

/// Vehicle summary card shown in the garage list.
struct VehicleCard: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(spacing: 0) {
            StoredImage(
                hasData: !vehicle.photos.isEmpty,
                cacheKey: coverPhoto?.id.uuidString ?? "none",
                maxPixel: 1200
            ) { [coverPhoto] in
                coverPhoto?.data
            }
            .frame(height: 190)
            .frame(maxWidth: .infinity)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    if !vehicle.trimAndYear.isEmpty {
                        Text(vehicle.trimAndYear)
                            .font(.dm(15, relativeTo: .subheadline))
                            .foregroundStyle(Color.secondaryText)
                    }
                    Text(vehicle.displayName)
                        .font(.dm(24, .bold, relativeTo: .title))
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(2)
                    Text(detailLine)
                        .font(.dm(16, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            Divider().overlay(Color.cardBorder)

            HStack(spacing: 12) {
                Image(systemName: "wrench.adjustable")
                    .foregroundStyle(Color.brandGreen)
                    .accessibilityHidden(true)
                Text("Next service")
                    .font(.dm(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Text(nextServiceText)
                    .font(.dm(15, .bold, relativeTo: .subheadline))
                    .foregroundStyle(isMileageOverdue ? Color.destructive : Color.brandGreen)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.appBackground.opacity(0.6))
        }
        .background(Color.cardBackground)
        .clipShape(.rect(cornerRadius: Theme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        }
        .contentShape(.rect(cornerRadius: Theme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows service history")
    }

    /// The first photo; its data is only read by `StoredImage` when the thumbnail isn't cached.
    private var coverPhoto: VehiclePhoto? {
        vehicle.photos.min { $0.order < $1.order }
    }

    /// The card only shows mileage: the due odometer from the latest service record, e.g. "119,800 km".
    private var nextServiceText: String {
        vehicle.nextServiceOdometer.map(vehicle.formattedDistance) ?? "Not scheduled"
    }

    private var isMileageOverdue: Bool {
        guard let due = vehicle.nextServiceOdometer else { return false }
        return vehicle.odometer > due
    }

    /// "7XLM219 • 24,680 mi"
    private var detailLine: String {
        [vehicle.plateNumber, vehicle.formattedDistance(vehicle.odometer)]
            .filter { !$0.isEmpty }
            .joined(separator: "  •  ")
    }
}
