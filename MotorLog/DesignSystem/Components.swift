//
//  Components.swift
//  MotorLog
//

import SwiftUI

// MARK: - Cards

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.cardBackground, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            }
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// Standard screen background used across the app.
    func screenBackground() -> some View {
        background { Color.appBackground.ignoresSafeArea() }
    }

    // MARK: Backward-compatible wrappers (deployment target iOS 18)

    /// Enables `swipeActions` on rows outside a `List` on iOS 27+.
    /// Earlier versions fall back to the row's context menu.
    @ViewBuilder
    func swipeActionsContainerIfAvailable() -> some View {
        if #available(iOS 27.0, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }

    /// Applies a navigation subtitle on iOS 26+; earlier versions show the title only.
    @ViewBuilder
    func navigationSubtitleIfAvailable(_ subtitle: String) -> some View {
        if #available(iOS 26.0, *) {
            navigationSubtitle(subtitle)
        } else {
            self
        }
    }

    /// Presents a confirmation dialog while `item` is non-nil, clearing it on dismissal.
    /// Same behavior as the iOS 27 `confirmationDialog(_:item:)`, built on the iOS 15 `presenting:` API.
    func confirmationDialog<Item, A: View, M: View>(
        _ title: String,
        presenting item: Binding<Item?>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: @escaping (Item) -> A,
        @ViewBuilder message: @escaping (Item) -> M
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            titleVisibility: titleVisibility,
            presenting: item.wrappedValue,
            actions: actions,
            message: message
        )
    }

    /// Message-less variant of `confirmationDialog(_:presenting:titleVisibility:actions:message:)`.
    func confirmationDialog<Item, A: View>(
        _ title: String,
        presenting item: Binding<Item?>,
        titleVisibility: Visibility = .automatic,
        @ViewBuilder actions: @escaping (Item) -> A
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ),
            titleVisibility: titleVisibility,
            presenting: item.wrappedValue,
            actions: actions
        )
    }
}

// MARK: - Text

/// Small, tracked, uppercase label (e.g. "YOUR VEHICLES").
struct SectionEyebrow: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.dm(13, .semibold, relativeTo: .caption))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Color.secondaryText)
    }
}

/// Eyebrow plus a large section title (e.g. "TIMELINE / Maintenance records").
struct SectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionEyebrow(eyebrow)
            Text(title)
                .font(.dm(24, .bold, relativeTo: .title2))
                .foregroundStyle(Color.primaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dm(18, .bold, relativeTo: .headline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.brandGreen.opacity(isEnabled ? 1 : 0.4), in: .rect(cornerRadius: 18))
            .shadow(color: .brandGreen.opacity(isEnabled ? 0.25 : 0), radius: 12, y: 6)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dm(18, .semibold, relativeTo: .headline))
            .foregroundStyle(Color.brandGreen)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.cardBackground, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Color.cardBorder, lineWidth: 1.5)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct DestructiveSoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dm(18, .semibold, relativeTo: .headline))
            .foregroundStyle(Color.destructive)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.destructiveSoft, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Color.destructive.opacity(0.2), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == OutlineButtonStyle {
    static var outline: OutlineButtonStyle { OutlineButtonStyle() }
}

extension ButtonStyle where Self == DestructiveSoftButtonStyle {
    static var destructiveSoft: DestructiveSoftButtonStyle { DestructiveSoftButtonStyle() }
}

/// Round green "+" button used in section headers.
struct CircleAddButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.brandGreen, in: .circle)
                .shadow(color: .brandGreen.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Form fields

/// A label above a rounded white field container.
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.dm(15, .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.secondaryText)
            content
                .font(.dm(17, relativeTo: .body))
                .foregroundStyle(Color.primaryText)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Color.cardBackground, in: .rect(cornerRadius: Theme.fieldCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.fieldCornerRadius)
                        .strokeBorder(Color.cardBorder, lineWidth: 1)
                }
        }
    }
}

/// Text field styled with a grey placeholder.
struct StyledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .words
    var suffix: String?

    var body: some View {
        LabeledField(label: label) {
            HStack {
                TextField(label, text: $text, prompt: Text(placeholder).foregroundStyle(Color.placeholderText))
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                if let suffix {
                    Text(suffix).foregroundStyle(Color.secondaryText)
                }
            }
        }
    }
}

// MARK: - Upload tiles

/// Dashed tile with a camera icon, used to add images.
struct DashedUploadTile: View {
    let title: String
    var subtitle: String?
    var isCircle = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "camera")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.brandGreen)
            if !isCircle {
                Text(title)
                    .font(.dm(16, .bold, relativeTo: .subheadline))
                    .foregroundStyle(isCircle ? Color.brandGreen : Color.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(.dm(13, relativeTo: .caption))
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isCircle {
                Circle().fill(Color.brandGreenSoft.opacity(0.6))
            } else {
                RoundedRectangle(cornerRadius: 16).fill(Color.cardBackground.opacity(0.5))
            }
        }
        .overlay {
            if isCircle {
                Circle().strokeBorder(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// Dashed "Add a new driver" style row button.
struct DashedActionRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandGreen)
                    .frame(width: 44, height: 44)
                    .background(Color.brandGreenSoft, in: .circle)
                Text(title)
                    .font(.dm(18, .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.brandGreen)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Color.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icons & tiles

/// Rounded square tile holding an SF Symbol.
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 56
    var tint: Color = .brandGreen
    var background: Color = .brandGreenSoft

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background, in: .rect(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

/// Icon, small caps label and value — used in the record detail grid.
struct InfoTile: View {
    let systemName: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundStyle(Color.brandGreen)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.dm(11, .medium, relativeTo: .caption))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondaryText)
                Text(value)
                    .font(.dm(16, .bold, relativeTo: .body))
                    .foregroundStyle(Color.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Circular avatar for a driver, falling back to initials.
struct AvatarView: View {
    let data: Data?
    let cacheKey: String
    let initials: String
    var size: CGFloat = 56

    var body: some View {
        Group {
            if data != nil {
                StoredImage(data: data, cacheKey: cacheKey, maxPixel: size * 3)
            } else {
                Text(initials)
                    .font(.dm(size * 0.36, .bold))
                    .foregroundStyle(Color.brandGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.brandGreenSoft)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    let systemName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            IconTile(systemName: systemName, size: 64)
            Text(title)
                .font(.dm(20, .bold, relativeTo: .title3))
                .foregroundStyle(Color.primaryText)
            Text(message)
                .font(.dm(15, relativeTo: .subheadline))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .card()
    }
}
