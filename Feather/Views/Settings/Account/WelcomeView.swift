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
                // Simplified background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemBackground).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 80)

                        // Logo section with simplified animation
                        VStack(spacing: 24) {
                            // Simple logo representation
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "bird.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(logoScale)
                            .onAppear {
                                withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                                    logoScale = 1.0
                                }
                            }

                            // Welcome text with animation
                            VStack(spacing: 16) {
                                Text("Welcome to Feather")
                                    .font(.system(size: 32, weight: .bold, design: .default))
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
                            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                                textOpacity = 1.0
                                textOffset = 0
                            }
                        }

                        Spacer(minLength: 60)

                        // Action buttons with simplified design
                        VStack(spacing: 20) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showLoginView = true
                                }
                            }) {
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.blue)
                                    )
                                    .foregroundColor(.white)
                            }
                            .accessibilityLabel("Sign In button")
                            .accessibilityHint("Double tap to sign in to your account")

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    UserDefaults.standard.set(true, forKey: "Feather.hasSeenWelcome")
                                }
                            }) {
                                Text("Skip for Now")
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(UIColor.secondarySystemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.blue)
                            }
                            .accessibilityLabel("Skip sign in button")
                            .accessibilityHint("Double tap to skip sign in and continue as guest")
                        }
                        .padding(.horizontal, 24)
                        .opacity(buttonOpacity)
                        .offset(y: buttonOffset)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                                buttonOpacity = 1.0
                                buttonOffset = 0
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
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