//
//  ProPlan.swift
//  MotorLog
//

import Foundation

/// Pro plans sold through StoreKit. Raw values are the product IDs in `Products.storekit`.
enum ProPlan: String, CaseIterable, Identifiable {
    case monthly = "com.sulo.MotorLog.monthly"
    case annual = "com.sulo.MotorLog.annual"
    case lifetime = "com.sulo.MotorLog.lifetime"

    var id: String { rawValue }
    var productID: String { rawValue }

    /// Fallback title used until the App Store product has loaded.
    var title: String {
        switch self {
        case .monthly: "Monthly"
        case .annual: "Annual"
        case .lifetime: "Lifetime"
        }
    }

    /// Lifetime is a non-renewing subscription. StoreKit never expires it, so it acts as a permanent unlock
    /// and has nothing to manage in the App Store subscriptions sheet.
    var isAutoRenewable: Bool { self != .lifetime }

    /// Order the plans appear on the paywall.
    static let paywallOrder: [ProPlan] = [.annual, .monthly, .lifetime]

    /// Highest rank wins when more than one entitlement is active at the same time.
    var rank: Int {
        switch self {
        case .monthly: 0
        case .annual: 1
        case .lifetime: 2
        }
    }
}

/// Caps that apply while the person is on the free plan. Pro removes all of them.
enum FreeTierLimits {
    static let maxVehicles = 3
    static let maxRecordsPerVehicle = 20

    static func canAddVehicle(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < maxVehicles
    }

    /// Records are capped per vehicle, not across the whole garage.
    static func canAddRecord(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < maxRecordsPerVehicle
    }
}

/// Which free-plan cap was hit. Drives the "Upgrade to Pro" alert.
enum FreeTierLimit: Identifiable {
    case vehicles, records

    var id: Self { self }

    var title: String {
        switch self {
        case .vehicles: "Vehicle limit reached"
        case .records: "Record limit reached"
        }
    }

    var message: String {
        switch self {
        case .vehicles:
            "The free plan includes up to \(FreeTierLimits.maxVehicles) vehicles. Upgrade to iMotorLog Pro to add as many as you like."
        case .records:
            "The free plan keeps up to \(FreeTierLimits.maxRecordsPerVehicle) service records per vehicle. Upgrade to iMotorLog Pro for unlimited history."
        }
    }
}

/// Links shown under the paywall's purchase button.
/// `termsOfUse` is Apple's standard EULA; replace `privacyPolicy` with your own policy URL before release.
enum LegalLinks {
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    static let privacyPolicy = URL(string: "https://aplivox.com/privacy/imotorlog")
}
