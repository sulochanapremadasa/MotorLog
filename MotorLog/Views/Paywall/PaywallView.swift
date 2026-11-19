//
//  PaywallView.swift
//  MotorLog
//

import StoreKit
import SwiftUI

/// Branded upgrade screen: hero, free-vs-Pro comparison, selectable plan cards, purchase and restore.
/// Presented as a sheet from Settings and from the free-plan limit alerts.
struct PaywallView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var statusMessage: StatusMessage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                closeButton
                hero
                comparisonCard

                if store.isPro {
                    proActiveCard
                } else {
                    plansSection
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .presentationDragIndicator(.visible)
        .task {
            if store.products.isEmpty {
                await store.loadProducts()
            }
            if selectedProductID == nil {
                selectedProductID = store.product(for: .annual)?.id ?? store.products.first?.id
            }
        }
        .alert(statusMessage?.title ?? "", isPresented: isShowingStatus, presenting: statusMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message.body)
        }
    }

    // MARK: - Header

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground, in: .circle)
                    .overlay { Circle().strokeBorder(Color.cardBorder, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.top, 12)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.brandGreenSoft)
                    .frame(width: 96, height: 96)
                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.brandGreen)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                SectionEyebrow("iMotorLog Pro")
                Text("Unlimited garage.\nUnlimited history.")
                    .font(.dm(32, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Track every vehicle you own and keep its full service record, with everything stored privately on your device.")
                    .font(.dm(17, relativeTo: .body))
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Comparison

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            comparisonHeader
            Divider().overlay(Color.cardBorder)
            comparisonRow(
                title: "Vehicles",
                free: "Up to \(FreeTierLimits.maxVehicles)",
                pro: "Unlimited"
            )
            Divider().overlay(Color.cardBorder).padding(.leading, 16)
            comparisonRow(
                title: "Service records",
                free: "\(FreeTierLimits.maxRecordsPerVehicle) per vehicle",
                pro: "Unlimited"
            )
            Divider().overlay(Color.cardBorder).padding(.leading, 16)
            comparisonRow(
                title: "On-device privacy",
                free: "Included",
                pro: "Included"
            )
        }
        .card(padding: 0)
    }

    /// Width of the Free and Pro value columns.
    private let comparisonColumnWidth: CGFloat = 84

    private var comparisonHeader: some View {
        HStack {
            Spacer()
            Text("Free")
                .frame(width: comparisonColumnWidth)
            Text("Pro")
                .foregroundStyle(Color.brandGreen)
                .frame(width: comparisonColumnWidth)
        }
        .font(.dm(13, .semibold, relativeTo: .caption))
        .tracking(1.2)
        .textCase(.uppercase)
        .foregroundStyle(Color.secondaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func comparisonRow(title: String, free: String, pro: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.dm(16, .semibold, relativeTo: .body))
                .foregroundStyle(Color.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            Text(free)
                .font(.dm(14, relativeTo: .subheadline))
                .foregroundStyle(Color.secondaryText)
                .frame(width: comparisonColumnWidth)
            Text(pro)
                .font(.dm(14, .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.brandGreen)
                .frame(width: comparisonColumnWidth)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Free: \(free). Pro: \(pro).")
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionEyebrow("Choose a plan")

            if store.isLoadingProducts && store.products.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(minHeight: 160)
            } else if let error = store.productsError, store.products.isEmpty {
                VStack(spacing: 14) {
                    Text(error)
                        .font(.dm(15, relativeTo: .subheadline))
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await store.loadProducts() }
                    }
                    .buttonStyle(.outline)
                }
                .frame(maxWidth: .infinity)
                .card(padding: 18)
            } else {
                VStack(spacing: 12) {
                    ForEach(store.products, id: \.id) { product in
                        PlanCard(
                            product: product,
                            introOffer: store.introductoryOffer(for: product),
                            badge: badge(for: product),
                            isSelected: product.id == selectedProductID
                        ) {
                            selectedProductID = product.id
                        }
                    }
                }
            }
        }

        if let product = selectedProduct {
            VStack(spacing: 14) {
                Button {
                    Task { await buy(product) }
                } label: {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(continueTitle(for: product))
                    }
                }
                .buttonStyle(.primary)
                .disabled(isPurchasing || isRestoring)

                Text(disclosure(for: product))
                    .font(.dm(13, relativeTo: .caption))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        footer
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                }
            }
            .font(.dm(16, .semibold, relativeTo: .callout))
            .foregroundStyle(Color.brandGreen)
            .disabled(isPurchasing || isRestoring)

            HStack(spacing: 6) {
                if let terms = LegalLinks.termsOfUse {
                    Link("Terms of Use", destination: terms)
                }
                Text("·").accessibilityHidden(true)
                if let privacy = LegalLinks.privacyPolicy {
                    Link("Privacy Policy", destination: privacy)
                }
            }
            .font(.dm(13, relativeTo: .caption))
            .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var proActiveCard: some View {
        VStack(spacing: 14) {
            IconTile(systemName: "checkmark.seal.fill", size: 64)
            Text("You're on iMotorLog Pro")
                .font(.dm(20, .bold, relativeTo: .title3))
                .foregroundStyle(Color.primaryText)
            if let plan = store.activePlanTitle {
                Text("\(plan) plan · unlimited vehicles and records.")
                    .font(.dm(15, relativeTo: .subheadline))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .card(padding: 20)
    }

    // MARK: - Copy

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedProductID }
    }

    private func badge(for product: Product) -> String? {
        if let offer = store.introductoryOffer(for: product) {
            return offer.badgeText
        }
        if product.id == ProPlan.annual.productID, store.products.count > 1 {
            return "BEST VALUE"
        }
        return nil
    }

    private func continueTitle(for product: Product) -> String {
        if let offer = store.introductoryOffer(for: product), offer.paymentMode == .freeTrial {
            return "Start \(offer.period.displayText) free"
        }
        return "Continue"
    }

    private func disclosure(for product: Product) -> String {
        guard let subscription = product.subscription else {
            return "One-time payment of \(product.displayPrice). Not a subscription."
        }
        let recurring = "\(product.displayPrice)\(subscription.subscriptionPeriod.priceSuffix)"
        if let offer = store.introductoryOffer(for: product), offer.paymentMode == .freeTrial {
            return "Free for \(offer.period.displayText), then \(recurring). Renews automatically until cancelled."
        }
        return "\(recurring), billed automatically until cancelled. Cancel anytime in Settings."
    }

    // MARK: - Actions

    private func buy(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(product, using: purchase) {
            case .purchased:
                dismiss()
            case .pending:
                statusMessage = StatusMessage(
                    title: "Purchase pending",
                    body: "Your purchase is waiting for approval. Pro unlocks automatically once it completes."
                )
            case .cancelled:
                break
            }
        } catch {
            statusMessage = StatusMessage(title: "Purchase failed", body: error.localizedDescription)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            if try await store.restorePurchases() {
                statusMessage = StatusMessage(title: "Purchases restored", body: "iMotorLog Pro is active on this device.")
            } else {
                statusMessage = StatusMessage(
                    title: "Nothing to restore",
                    body: "No iMotorLog Pro purchase was found for this Apple Account."
                )
            }
        } catch {
            statusMessage = StatusMessage(title: "Couldn't restore", body: error.localizedDescription)
        }
    }

    private var isShowingStatus: Binding<Bool> {
        Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )
    }

    private struct StatusMessage {
        let title: String
        let body: String
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let product: Product
    let introOffer: Product.SubscriptionOffer?
    let badge: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 14) {
                radio

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.dm(17, .bold, relativeTo: .headline))
                            .foregroundStyle(Color.primaryText)
                        if let badge {
                            Text(badge)
                                .font(.dm(10, .bold, relativeTo: .caption2))
                                .tracking(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.brandGreen, in: .capsule)
                        }
                    }
                    if !product.description.isEmpty {
                        Text(product.description)
                            .font(.dm(13, relativeTo: .caption))
                            .foregroundStyle(Color.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.dm(18, .bold, relativeTo: .headline))
                        .foregroundStyle(Color.primaryText)
                    Text(periodText)
                        .font(.dm(12, relativeTo: .caption2))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.brandGreenSoft.opacity(0.7) : Color.cardBackground,
                in: .rect(cornerRadius: Theme.cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(isSelected ? Color.brandGreen : Color.cardBorder, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var radio: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.brandGreen : Color.cardBorder, lineWidth: 2)
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityHidden(true)
    }

    private var periodText: String {
        if let subscription = product.subscription {
            return "per \(subscription.subscriptionPeriod.displayText.dropFirst(2))"
        }
        return "one-time"
    }

    private var accessibilityText: String {
        var parts = [product.displayName, "\(product.displayPrice) \(periodText)"]
        if let badge { parts.append(badge.capitalized) }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    PaywallView()
        .environment(StoreManager())
}
