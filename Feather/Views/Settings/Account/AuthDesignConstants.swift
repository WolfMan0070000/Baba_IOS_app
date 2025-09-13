//
//  AuthDesignConstants.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI

// MARK: - Design Constants for Authentication Views
struct AuthDesign {
    // MARK: - Layout
    static let horizontalPadding: CGFloat = 24
    static let verticalSpacing: CGFloat = 20
    static let formVerticalSpacing: CGFloat = 20
    static let logoVerticalSpacing: CGFloat = 24
    static let contentVerticalSpacing: CGFloat = 40

    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 16
    static let formCornerRadius: CGFloat = 12

    // MARK: - Logo/Icon Sizes
    static let logoSize: CGFloat = 100
    static let logoGlowSize: CGFloat = 120
    static let iconSize: CGFloat = 40
    static let smallIconSize: CGFloat = 20

    // MARK: - Button Heights
    static let primaryButtonHeight: CGFloat = 56
    static let secondaryButtonHeight: CGFloat = 56

    // MARK: - Font Sizes
    static let titleFontSize: CGFloat = 32
    static let subtitleFontSize: CGFloat = 17
    static let formLabelFontSize: CGFloat = 15
    static let formFieldFontSize: CGFloat = 17
    static let buttonFontSize: CGFloat = 17
    static let errorFontSize: CGFloat = 15
    static let captionFontSize: CGFloat = 13

    // MARK: - Animations
    static let logoAnimationDuration: Double = 0.8
    static let formAnimationDuration: Double = 0.6
    static let buttonAnimationDuration: Double = 0.3
    static let logoAnimationDelay: Double = 0.2
    static let formAnimationDelay: Double = 0.4
    static let buttonAnimationDelay: Double = 0.6

    // MARK: - Shadows
    static let primaryShadowRadius: CGFloat = 8
    static let secondaryShadowRadius: CGFloat = 6
    static let logoShadowRadius: CGFloat = 10

    // MARK: - Opacity Values
    static let disabledOpacity: CGFloat = 0.6
    static let secondaryOpacity: CGFloat = 0.1
    static let glowOpacity: CGFloat = 0.1
    static let patternOpacity: CGFloat = 0.03

    // MARK: - Colors
    static let primaryColor = Color.blue
    static let secondaryColor = Color(UIColor.secondarySystemGroupedBackground)
    static let tertiaryColor = Color(UIColor.tertiarySystemGroupedBackground)
    static let errorColor = Color.red

    // MARK: - Gradients
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(UIColor.systemBackground),
            secondaryColor.opacity(0.8)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Spacing Constants
    static let formFieldVerticalPadding: CGFloat = 14
    static let formFieldHorizontalPadding: CGFloat = 16
    static let cardVerticalPadding: CGFloat = 24
    static let cardHorizontalPadding: CGFloat = 24
}

// MARK: - Animation Constants
struct AuthAnimation {
    static func logoScaleAnimation(delay: Double = 0) -> Animation {
        .easeOut(duration: AuthDesign.logoAnimationDuration).delay(delay)
    }

    static func formFadeAnimation(delay: Double = 0) -> Animation {
        .easeOut(duration: AuthDesign.formAnimationDuration).delay(delay)
    }

    static func buttonFadeAnimation(delay: Double = 0) -> Animation {
        .easeOut(duration: AuthDesign.buttonAnimationDuration).delay(delay)
    }

    static func interactionAnimation() -> Animation {
        .easeInOut(duration: 0.2)
    }
}
