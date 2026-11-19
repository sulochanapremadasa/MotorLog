//
//  OnboardingView.swift
//  MotorLog
//

import SwiftUI

/// Three swipeable intro pages, shown once on first launch.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "car.side",
            title: "Your garage, organized",
            message: "Keep every vehicle in one place, complete with photos, plates, and mileage."
        ),
        OnboardingPage(
            symbol: "wrench.and.screwdriver",
            title: "Every service, logged",
            message: "Record maintenance, services, and repairs with costs, notes, and receipts, and see what's due next."
        ),
        OnboardingPage(
            symbol: "person.2",
            title: "Drivers at a glance",
            message: "Assign drivers to vehicles and keep their license details close at hand."
        )
    ]

    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLastPage {
                    Button("Skip", action: onFinish)
                        .font(.dm(17, .semibold, relativeTo: .body))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, Theme.horizontalPadding)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.brandGreen : Color.cardBorder)
                        .frame(width: index == page ? 28 : 8, height: 8)
                }
            }
            .animation(.snappy, value: page)
            .accessibilityElement()
            .accessibilityLabel("Page \(page + 1) of \(pages.count)")
            .padding(.bottom, 28)

            Button(isLastPage ? "Get Started" : "Next") {
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 24)
        }
        .screenBackground()
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brandGreenSoft)
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: 150, height: 150)
                    .shadow(color: .brandGreen.opacity(0.15), radius: 20, y: 10)
                Image(systemName: page.symbol)
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Color.brandGreen)
            }
            .accessibilityHidden(true)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.dm(32, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(Color.primaryText)
                Text(page.message)
                    .font(.dm(17, relativeTo: .body))
                    .foregroundStyle(Color.secondaryText)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String
}

#Preview {
    OnboardingView {}
}
