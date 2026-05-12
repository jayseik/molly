import SwiftUI

/// Centralized visual tokens — adjust palette here rather than scattering literals across views.
enum MollyTheme {

    enum ColorToken {
        case background
        case card
        case border
        case accent

        func resolve(for scheme: ColorScheme) -> SwiftUI.Color {
            switch self {
            case .background:
                scheme == .dark ? SwiftUI.Color(white: 0.07) : SwiftUI.Color(white: 0.97)
            case .card:
                scheme == .dark ? SwiftUI.Color(white: 0.11) : SwiftUI.Color(white: 1.0)
            case .border:
                scheme == .dark ? SwiftUI.Color.white.opacity(0.08) : SwiftUI.Color.black.opacity(0.06)
            case .accent:
                // Deep teal-ish accent (muted for light/dark)
                scheme == .dark
                    ? SwiftUI.Color(red: 0.32, green: 0.66, blue: 0.60)
                    : SwiftUI.Color(red: 0.12, green: 0.45, blue: 0.44)
            }
        }
    }
}

struct MollyCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MollyTheme.ColorToken.card.resolve(for: scheme)))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MollyTheme.ColorToken.border.resolve(for: scheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.35 : 0.06), radius: 12, y: 6)
    }
}

extension View {
    func mollyCard() -> some View { modifier(MollyCardModifier()) }
}
