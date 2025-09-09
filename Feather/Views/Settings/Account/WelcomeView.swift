//
//  WelcomeView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//  Last Updated: 15.09.2025 - Apple-style redesign
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showLoginView = false

    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0.0
    @State private var buttonOffset: CGFloat = 50
    @State private var buttonOpacity: Double = 0.0

    var body: some View {
        NavigationView {
            ZStack {
                // Apple-style background (matching LoginView)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemGroupedBackground).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Subtle pattern overlay
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        // Create subtle circular patterns
                        for i in 0..<4 {
                            let centerX = width * 0.3 + (width * 0.2 * CGFloat(i))
                            let centerY = height * 0.4 + (height * 0.15 * CGFloat(i))
                            let radius = min(width, height) * 0.12

                            path.addArc(
                                center: CGPoint(x: centerX, y: centerY),
                                radius: radius,
                                startAngle: .zero,
                                endAngle: .degrees(360),
                                clockwise: false
                            )
                        }
                    }
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.02),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: min(geometry.size.width, geometry.size.height) * 0.12
                        )
                    )
                }

                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 80)

                        // Logo section with Apple-style animation
                        VStack(spacing: 32) {
                            ZStack {
                                // Outer glow
                                Circle()
                                    .fill(Color.blue.opacity(0.08))
                                    .frame(width: 140, height: 140)
                                    .blur(radius: 25)
                                    .scaleEffect(logoScale)

                                // Main logo background
                                Circle()
                                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)

                                // App logo
                                Image(systemName: "app.badge.fill")
                                    .font(.system(size: 50, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .scaleEffect(logoScale)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                                    logoScale = 1.0
                                }
                            }

                            // Welcome text with animation
                            VStack(spacing: 16) {
                                Text("Welcome to Feather")
                                    .font(.system(size: 34, weight: .bold, design: .default))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)

                                Text("Sign in to access your certificates and sync your apps across devices.")
                                    .font(.system(size: 17, weight: .regular, design: .default))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                                textOpacity = 1.0
                                textOffset = 0
                            }
                        }

                        Spacer(minLength: 60)

                        // Action buttons with Apple-style design
                        VStack(spacing: 16) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showLoginView = true
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.blue)
                                        .frame(height: 56)
                                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)

                                    Text("Sign In")
                                        .font(.system(size: 17, weight: .semibold, design: .default))
                                        .foregroundColor(.white)
                                }
                            }
                            .accessibilityLabel("Sign In button")
                            .accessibilityHint("Double tap to sign in to your account")

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    UserDefaults.standard.set(true, forKey: "Feather.hasSeenWelcome")
                                }
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                                        .frame(height: 56)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                                    Text("Skip for Now")
                                        .font(.system(size: 17, weight: .medium, design: .default))
                                        .foregroundColor(.blue)
                                }
                            }
                            .accessibilityLabel("Skip sign in button")
                            .accessibilityHint("Double tap to skip sign in and continue as guest")
                        }
                        .padding(.horizontal, 24)
                        .opacity(buttonOpacity)
                        .offset(y: buttonOffset)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                                buttonOpacity = 1.0
                                buttonOffset = 0
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showLoginView) {
            LoginView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showLoginView = false
                    UserDefaults.standard.set(true, forKey: "Feather.hasSeenWelcome")
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
