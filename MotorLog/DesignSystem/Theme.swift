//
//  Theme.swift
//  MotorLog
//

import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    static let brandGreen = Color(light: 0x356B4F, dark: 0x6DB38C)
    static let brandGreenSoft = Color(light: 0xE6EFE9, dark: 0x22332A)
    static let appBackground = Color(light: 0xF5F7F5, dark: 0x0F1311)
    static let cardBackground = Color(light: 0xFFFFFF, dark: 0x1A201D)
    static let cardBorder = Color(light: 0xE4E9E6, dark: 0x2A322E)
    static let primaryText = Color(light: 0x17201B, dark: 0xF1F4F2)
    static let secondaryText = Color(light: 0x6E7C74, dark: 0x9AA8A0)
    static let placeholderText = Color(light: 0xA3ADA7, dark: 0x6A7670)
    static let destructive = Color(light: 0xB24A3B, dark: 0xE07A6A)
    static let destructiveSoft = Color(light: 0xFDF3F0, dark: 0x2E1D1A)
    static let accentOrange = Color(light: 0xE08A4B, dark: 0xF0A46C)

    /// Creates a color that adapts to light and dark appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Fonts

/// Bundled DM Sans weights (registered through `UIAppFonts` in Info.plist).
enum DMSans: String {
    case regular = "DMSans-Regular"
    case medium = "DMSans-Medium"
    case semibold = "DMSans-SemiBold"
    case bold = "DMSans-Bold"
}

extension Font {
    /// DM Sans at the given size, scaling with Dynamic Type relative to `style`.
    static func dm(_ size: CGFloat, _ weight: DMSans = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

enum Theme {
    static let cornerRadius: CGFloat = 20
    static let fieldCornerRadius: CGFloat = 14
    static let horizontalPadding: CGFloat = 20

    /// Applies DM Sans to UIKit-backed navigation bar titles.
    static func configureNavigationBarFonts() {
        let appearance = UINavigationBar.appearance()
        if let large = UIFont(name: DMSans.bold.rawValue, size: 34) {
            appearance.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
        if let inline = UIFont(name: DMSans.bold.rawValue, size: 18) {
            appearance.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline)]
        }
    }
}

/// User-selectable appearance, stored in `@AppStorage`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum StorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appearance = "appearance"
    /// Bumped by "Erase all data" to rebuild the tab navigation stacks.
    static let dataResetID = "dataResetID"
}
