//
//  LoginView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//  Last Updated: 15.09.2025 - Apple-style redesign
//

import SwiftUI
import NimbleViews

struct LoginView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var apiBaseURL: String = UserDefaults.standard.string(forKey: "Feather.apiBaseURL") ?? "http://localhost:4000"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var showServerSettings: Bool = false
    @State private var emailFocused: Bool = false
    @State private var passwordFocused: Bool = false
    @State private var keyboardHeight: CGFloat = 0

    // Animation states
    @State private var logoScale: CGFloat = 1.0
    @State private var formOffset: CGFloat = 50
    @State private var formOpacity: Double = 0.0

    var body: some View {
        NavigationView {
            ZStack {
                // Apple-style background
                appleStyleBackground

                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: 60)

                        // Logo and title section
                        logoSection

                        // Login form
                        if authManager.isAuthenticated {
                            accountInfoView
            } else {
                            loginFormView
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
                }
                .ignoresSafeArea(.keyboard)
            }
            .navigationBarHidden(true)
            .onAppear {
                setupInitialAnimation()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardFrame.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        }
    }

    private func onLogin() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                AuthManager.shared.setApiBaseURL(apiBaseURL)
                try await AuthManager.shared.login(email: email, password: password)
                // Certificate fetch is already handled in AuthManager.login()
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    // MARK: - Apple-style Background
    private var appleStyleBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemBackground).opacity(0.8)
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
                    for i in 0..<5 {
                        let centerX = width * 0.2 + (width * 0.15 * CGFloat(i))
                        let centerY = height * 0.3 + (height * 0.1 * CGFloat(i))
                        let radius = min(width, height) * 0.15

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
                            Color.blue.opacity(0.03),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: min(geometry.size.width, geometry.size.height) * 0.15
                    )
                )
            }
        }
    }

    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 24) {
            // App logo with Apple-style animation
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                    .scaleEffect(logoScale)

                // Main logo background
                Circle()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)

                // Logo icon
                Image(systemName: "app.badge.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.blue)
                    .symbolEffect(.bounce, value: authManager.isAuthenticated)
            }
            .scaleEffect(logoScale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    logoScale = 1.0
                }
            }

            // Title and subtitle
            VStack(spacing: 8) {
                Text("Welcome to Feather")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(authManager.isAuthenticated ? "You're signed in" : "Sign in to continue")
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(formOpacity)
        .offset(y: formOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                formOpacity = 1.0
                formOffset = 0
            }
        }
    }

    // MARK: - Login Form View
    private var loginFormView: some View {
        VStack(spacing: 20) {
            // Email field with Apple-style design
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundColor(.primary)

                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(emailFocused ? .blue : .secondary)
                        .frame(width: 20)

                    TextField("Enter your email", text: $email)
                        .font(.system(size: 17, design: .default))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Email address field")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    emailFocused ? Color.blue.opacity(0.3) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: emailFocused ? Color.blue.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        emailFocused = true
                        passwordFocused = false
                    }
                }
            }

            // Password field with Apple-style design
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundColor(.primary)

                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(passwordFocused ? .blue : .secondary)
                        .frame(width: 20)

                    SecureField("Enter your password", text: $password)
                        .font(.system(size: 17, design: .default))
                        .textContentType(.password)
                        .accessibilityLabel("Password field")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    passwordFocused ? Color.blue.opacity(0.3) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: passwordFocused ? Color.blue.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        passwordFocused = true
                        emailFocused = false
                    }
                }
            }

            // Error message with Apple-style design
            if showError, let errorMessage = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16))

                    Text(errorMessage)
                        .font(.system(size: 15, design: .default))
                        .foregroundColor(.red)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale))
            }

            // Server settings toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showServerSettings.toggle()
                }
            }) {
                HStack {
                    Text("Server Settings")
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: showServerSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.vertical, 8)
            }

            // Server settings section
            if showServerSettings {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Base URL")
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(.primary)

                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        TextField("https://api.example.com", text: $apiBaseURL)
                            .font(.system(size: 17, design: .default))
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Sign In button with Apple-style design
            Button(action: onLogin) {
                ZStack {
                    // Button background
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.blue)
                        .frame(height: 56)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Button content
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }
                }
            }
            .accessibilityLabel(isLoading ? "Signing in..." : "Sign In button")
            .accessibilityHint("Double tap to sign in to your account")
            .disabled(isLoading || email.isEmpty || password.isEmpty)
            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            .padding(.top, 8)
        }
        .opacity(formOpacity)
        .offset(y: formOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                formOpacity = 1.0
                formOffset = 0
            }
        }
    }

    // MARK: - Account Info View (when logged in)
    private var accountInfoView: some View {
        VStack(spacing: 24) {
            // Account info card
            VStack(spacing: 16) {
                // User avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }

                // Account details
                VStack(spacing: 8) {
                    Text(authManager.currentUserEmail ?? "Unknown")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.primary)

                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)

                        Text("Signed In")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.green)
                    }
                }

                // Server info
                VStack(spacing: 4) {
                    Text("Connected to")
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.secondary)

                    Text(authManager.apiBaseURL.absoluteString)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
            )

            // Sign out button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    authManager.logout()
                }
            }) {
                HStack {
                    Text("Sign Out")
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(.red)

                    Spacer()

                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .opacity(formOpacity)
        .offset(y: formOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                formOpacity = 1.0
                formOffset = 0
            }
        }
    }

    // MARK: - Helper Methods
    private func setupInitialAnimation() {
        logoScale = 0.8
        formOffset = 50
        formOpacity = 0.0

        // Trigger animations
        withAnimation(.easeOut(duration: 0.8)) {
            logoScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            formOpacity = 1.0
            formOffset = 0
        }
    }
}