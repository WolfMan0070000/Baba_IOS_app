import SwiftUI

/// Central design system for Baba App – colors, fonts, modifiers
/// Colors are extracted from the app icon (cyan-to-blue gradient).
public enum AppTheme {
    // MARK: Colors
    public static let accentTop     = Color(red: 54/255,  green: 209/255, blue: 1)
    public static let accentBottom  = Color(red: 0/255,   green: 123/255, blue: 1)
    /// Main accent (average of gradient)
    public static let primary       = Color(red: 0/255,   green: 165/255, blue: 1)
    public static let background    = Color(uiColor: .systemBackground)
    public static let cardBackground = Color(uiColor: UIColor.secondarySystemBackground.withAlphaComponent(0.6))

    // MARK: Gradient
    public static let accentGradient = LinearGradient(
        colors: [accentTop, accentBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Fonts (SF Rounded for friendly look)
    public enum Fonts {
        public static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        public static let title      = Font.system(size: 28, weight: .semibold, design: .rounded)
        public static let body       = Font.system(.body, design: .rounded)
    }

    // MARK: Corner Radius / Shadow
    public static let cardRadius: CGFloat = 18
}

// MARK: - View Modifiers
private struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1))
            )
    }
}

extension View {
    /// Applies a frosted-glass card style used throughout the app.
    public func glassCard() -> some View {
        modifier(GlassCard())
    }
}

extension Text {
    /// Stylised section header following the new theme.
    public func sectionHeader() -> some View {
        self
            .font(AppTheme.Fonts.title)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
} 