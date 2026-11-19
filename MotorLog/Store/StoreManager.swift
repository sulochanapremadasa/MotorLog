//
//  StoreManager.swift
//  MotorLog
//

import Foundation
import Observation
import StoreKit
import SwiftUI

/// Loads the Pro products, tracks the active entitlement, and answers free-plan limit checks.
/// One instance lives for the whole app and is shared through the SwiftUI environment.
@Observable
@MainActor
final class StoreManager {
    /// Products in paywall order. Empty until `loadProducts()` succeeds.
    private(set) var products: [Product] = []
    /// The plan the person is currently entitled to, or `nil` on the free plan.
    private(set) var activePlan: ProPlan?
    private(set) var isLoadingProducts = false
    private(set) var productsError: String?
    /// Product IDs whose introductory offer this customer can still redeem.
    private(set) var introOfferEligibleProductIDs: Set<String> = []

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    /// Incremented on every refresh so an older, slower refresh can't overwrite a newer result.
    @ObservationIgnored private var refreshGeneration = 0
    /// Verified purchases from this session that `currentEntitlements` may not include yet.
    /// Each one is dropped as soon as StoreKit reports the product as an entitlement.
    @ObservationIgnored private var recentPurchases: [StoreKit.Transaction] = []

    var isPro: Bool { activePlan != nil }

    /// Localized name of the active plan, e.g. "Annual".
    var activePlanTitle: String? {
        guard let activePlan else { return nil }
        return product(for: activePlan)?.displayName ?? activePlan.title
    }

    init() {
        // Listen for renewals, refunds, Ask to Buy approvals, and purchases made on other devices.
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
        Task { await refreshEntitlements() }
    }

    // MARK: - Products

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        productsError = nil
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: ProPlan.allCases.map(\.productID))
            products = ProPlan.paywallOrder.compactMap { plan in
                loaded.first { $0.id == plan.productID }
            }

            var eligible: Set<String> = []
            for product in products {
                if let subscription = product.subscription,
                   subscription.introductoryOffer != nil,
                   await subscription.isEligibleForIntroOffer {
                    eligible.insert(product.id)
                }
            }
            introOfferEligibleProductIDs = eligible

            if products.isEmpty {
                productsError = "Plans aren't available right now. Please try again later."
            }
        } catch {
            productsError = error.localizedDescription
        }
    }

    func product(for plan: ProPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    /// The introductory offer for a product, only when this customer is still eligible for it.
    func introductoryOffer(for product: Product) -> Product.SubscriptionOffer? {
        guard introOfferEligibleProductIDs.contains(product.id) else { return nil }
        return product.subscription?.introductoryOffer
    }

    // MARK: - Entitlements

    /// Recomputes `activePlan` from StoreKit's current entitlements.
    func refreshEntitlements() async {
        // Refreshes overlap (launch, returning to the foreground after the payment sheet, purchase,
        // Transaction.updates). Only the most recently started one may publish its result, otherwise
        // a snapshot taken before the purchase committed could reset the plan to free.
        refreshGeneration += 1
        let generation = refreshGeneration

        var entitled: [StoreKit.Transaction] = []
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                entitled.append(transaction)
            }
        }
        guard generation == refreshGeneration else { return }

        // Once StoreKit reports a product itself, the locally remembered purchase is no longer needed.
        let entitledIDs = Set(entitled.map(\.productID))
        recentPurchases.removeAll { entitledIDs.contains($0.productID) }

        activePlan = bestPlan(in: entitled + recentPurchases)
    }

    /// Highest-ranked Pro plan among transactions that are neither revoked nor expired.
    private func bestPlan(in transactions: [StoreKit.Transaction]) -> ProPlan? {
        var best: ProPlan?
        for transaction in transactions {
            guard let plan = ProPlan(rawValue: transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration <= .now { continue }
            if let current = best, current.rank >= plan.rank { continue }
            best = plan
        }
        return best
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate != nil {
            recentPurchases.removeAll { $0.productID == transaction.productID }
        }
        await transaction.finish()
        await refreshEntitlements()
    }

    // MARK: - Purchasing

    enum PurchaseOutcome {
        case purchased
        /// Waiting on Ask to Buy or Strong Customer Authentication. `StoreKit.Transaction.updates` delivers the result later.
        case pending
        case cancelled
    }

    func purchase(_ product: Product, using purchaseAction: PurchaseAction) async throws -> PurchaseOutcome {
        let result = try await purchaseAction(product)
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Remember the purchase so it counts even while `currentEntitlements` still lags behind it.
                recentPurchases.append(transaction)
                await transaction.finish()
                await refreshEntitlements()
                return .purchased
            case .unverified(_, let error):
                throw error
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Asks the App Store to resync transactions. Returns `true` when a Pro entitlement is active afterwards.
    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    // MARK: - Free-plan limits

    func canAddVehicle(currentCount: Int) -> Bool {
        FreeTierLimits.canAddVehicle(currentCount: currentCount, isPro: isPro)
    }

    func canAddRecord(to vehicle: Vehicle) -> Bool {
        FreeTierLimits.canAddRecord(currentCount: vehicle.records.count, isPro: isPro)
    }
}

// MARK: - Display helpers

extension Product.SubscriptionPeriod {
    /// "1 month", "7 days", "1 year".
    var displayText: String {
        let unitName: String
        switch unit {
        case .day: unitName = value == 1 ? "day" : "days"
        case .week: unitName = value == 1 ? "week" : "weeks"
        case .month: unitName = value == 1 ? "month" : "months"
        case .year: unitName = value == 1 ? "year" : "years"
        @unknown default: unitName = value == 1 ? "period" : "periods"
        }
        return "\(value) \(unitName)"
    }

    /// Suffix shown after a price: "/month", "/year", "/3 months".
    var priceSuffix: String {
        if value == 1 {
            switch unit {
            case .day: return "/day"
            case .week: return "/week"
            case .month: return "/month"
            case .year: return "/year"
            @unknown default: return ""
            }
        }
        return "/\(displayText)"
    }
}

extension Product.SubscriptionOffer {
    /// Short badge text, e.g. "1 MONTH FREE" or "$0.99 FOR 3 MONTHS".
    var badgeText: String {
        if paymentMode == .freeTrial {
            return "\(period.displayText) free".uppercased()
        }
        let length = periodCount > 1 ? "\(periodCount) × \(period.displayText)" : period.displayText
        return "\(displayPrice) for \(length)".uppercased()
    }
}
