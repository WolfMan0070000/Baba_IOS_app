//
//  AuthFormComponents.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI

// MARK: - Reusable Form Components
extension LoginView {

    // MARK: - AuthTextField
    struct AuthTextField: View {
        let title: String
        let placeholder: String
        let systemImage: String
        let textContentType: UITextContentType?
        let keyboardType: UIKeyboardType?
        let isSecure: Bool
        @Binding var text: String
        @Binding var isFocused: Bool
        let onFocus: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: AuthDesign.formLabelFontSize, weight: .semibold, design: .default))
                    .foregroundColor(.primary)

                HStack {
                    Image(systemName: systemImage)
                        .foregroundColor(isFocused ? AuthDesign.primaryColor : .secondary)
                        .frame(width: AuthDesign.smallIconSize)

                    if isSecure {
                        SecureField(placeholder, text: $text)
                            .font(.system(size: AuthDesign.formFieldFontSize, design: .default))
                            .textContentType(textContentType)
                    } else {
                        TextField(placeholder, text: $text)
                            .font(.system(size: AuthDesign.formFieldFontSize, design: .default))
                            .textContentType(textContentType)
                            .keyboardType(keyboardType ?? .default)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, AuthDesign.formFieldHorizontalPadding)
                .padding(.vertical, AuthDesign.formFieldVerticalPadding)
                .background(formFieldBackground)
                .onTapGesture {
                    withAnimation(AuthAnimation.interactionAnimation()) {
                        onFocus()
                    }
                }
                .accessibilityLabel("\(title) field")
            }
        }

        private var formFieldBackground: some View {
            RoundedRectangle(cornerRadius: AuthDesign.formCornerRadius, style: .continuous)
                .fill(AuthDesign.secondaryColor)
                .overlay(
                    RoundedRectangle(cornerRadius: AuthDesign.formCornerRadius, style: .continuous)
                        .strokeBorder(
                            isFocused ? AuthDesign.primaryColor.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isFocused ? AuthDesign.primaryColor.opacity(0.1) : Color.clear,
                    radius: AuthDesign.secondaryShadowRadius,
                    x: 0,
                    y: 4
                )
        }
    }

    // MARK: - AuthButton
    struct AuthButton: View {
        let title: String
        let isLoading: Bool
        let isDisabled: Bool
        let action: () -> Void
        var style: ButtonStyle = .primary

        enum ButtonStyle {
            case primary, secondary, destructive

            var backgroundColor: Color {
                switch self {
                case .primary: return AuthDesign.primaryColor
                case .secondary: return AuthDesign.secondaryColor
                case .destructive: return AuthDesign.errorColor.opacity(0.1)
                }
            }

            var foregroundColor: Color {
                switch self {
                case .primary: return .white
                case .secondary: return AuthDesign.primaryColor
                case .destructive: return AuthDesign.errorColor
                }
            }

            var shadowColor: Color {
                switch self {
                case .primary: return AuthDesign.primaryColor.opacity(0.3)
                case .secondary: return Color.black.opacity(0.04)
                case .destructive: return Color.clear
                }
            }

            var borderColor: Color {
                switch self {
                case .primary: return Color.clear
                case .secondary: return AuthDesign.primaryColor.opacity(0.3)
                case .destructive: return AuthDesign.errorColor.opacity(0.2)
                }
            }

            var borderWidth: CGFloat {
                switch self {
                case .primary: return 0
                case .secondary, .destructive: return 1
                }
            }
        }

        var body: some View {
            Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuthDesign.cornerRadius, style: .continuous)
                        .fill(style.backgroundColor)
                        .frame(height: AuthDesign.primaryButtonHeight)
                        .shadow(color: style.shadowColor, radius: AuthDesign.primaryShadowRadius, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: AuthDesign.cornerRadius, style: .continuous)
                                .strokeBorder(style.borderColor, lineWidth: style.borderWidth)
                        )

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                            .scaleEffect(1.2)
                    } else {
                        Text(title)
                            .font(.system(size: AuthDesign.buttonFontSize, weight: .semibold, design: .default))
                            .foregroundColor(style.foregroundColor)
                    }
                }
            }
            .disabled(isDisabled)
            .opacity(isDisabled ? AuthDesign.disabledOpacity : 1.0)
            .accessibilityLabel(isLoading ? "Loading..." : "\(title) button")
        }
    }

    // MARK: - AuthErrorMessage
    struct AuthErrorMessage: View {
        let message: String?

        var body: some View {
            if let message = message {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AuthDesign.errorColor)
                        .font(.system(size: 16))

                    Text(message)
                        .font(.system(size: AuthDesign.errorFontSize, design: .default))
                        .foregroundColor(AuthDesign.errorColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.horizontal, AuthDesign.formFieldHorizontalPadding)
                .padding(.vertical, 12)
                .background(errorBackground)
                .transition(.opacity.combined(with: .scale))
            }
        }

        private var errorBackground: some View {
            RoundedRectangle(cornerRadius: AuthDesign.formCornerRadius, style: .continuous)
                .fill(AuthDesign.errorColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AuthDesign.formCornerRadius, style: .continuous)
                        .strokeBorder(AuthDesign.errorColor.opacity(0.2), lineWidth: 1)
                )
        }
    }

    // MARK: - AuthCard
    struct AuthCard<Content: View>: View {
        let content: Content

        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        var body: some View {
            content
                .padding(.horizontal, AuthDesign.cardHorizontalPadding)
                .padding(.vertical, AuthDesign.cardVerticalPadding)
                .background(cardBackground)
        }

        private var cardBackground: some View {
            RoundedRectangle(cornerRadius: AuthDesign.cornerRadius, style: .continuous)
                .fill(AuthDesign.secondaryColor)
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
        }
    }

    // MARK: - AuthLogo
    struct AuthLogo: View {
        @Binding var scale: CGFloat
        let delay: Double

        var body: some View {
            ZStack {
                // Outer glow
                Circle()
                    .fill(AuthDesign.primaryColor.opacity(AuthDesign.glowOpacity))
                    .frame(width: AuthDesign.logoGlowSize, height: AuthDesign.logoGlowSize)
                    .blur(radius: 20)
                    .scaleEffect(scale)

                // Main logo background
                Circle()
                    .fill(AuthDesign.tertiaryColor)
                    .frame(width: AuthDesign.logoSize, height: AuthDesign.logoSize)
                    .shadow(color: Color.black.opacity(0.1), radius: AuthDesign.logoShadowRadius, x: 0, y: 5)

                // Logo icon
                Image(systemName: "app.badge.fill")
                    .font(.system(size: AuthDesign.iconSize, weight: .medium))
                    .foregroundColor(AuthDesign.primaryColor)
            }
            .scaleEffect(scale)
            .onAppear {
                withAnimation(AuthAnimation.logoScaleAnimation(delay: delay)) {
                    scale = 1.0
                }
            }
        }
    }
}
