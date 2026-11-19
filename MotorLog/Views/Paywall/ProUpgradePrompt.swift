//
//  ProUpgradePrompt.swift
//  MotorLog
//

import SwiftUI

/// Shows the "limit reached" alert for the bound `FreeTierLimit`, with an Upgrade button that opens the paywall.
private struct ProUpgradePromptModifier: ViewModifier {
    @Binding var limit: FreeTierLimit?
    @State private var showsPaywall = false

    func body(content: Content) -> some View {
        content
            .alert(limit?.title ?? "", isPresented: isPresented, presenting: limit) { _ in
                Button("Upgrade to Pro") { showsPaywall = true }
                Button("Not now", role: .cancel) {}
            } message: { limit in
                Text(limit.message)
            }
            .sheet(isPresented: $showsPaywall) {
                PaywallView()
            }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { limit != nil },
            set: { if !$0 { limit = nil } }
        )
    }
}

extension View {
    /// Presents an upgrade alert whenever `limit` becomes non-nil. Clears it on dismissal.
    func proUpgradePrompt(for limit: Binding<FreeTierLimit?>) -> some View {
        modifier(ProUpgradePromptModifier(limit: limit))
    }
}
