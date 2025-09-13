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
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var emailFocused: Bool
    @FocusState private var passwordFocused: Bool

    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var formOffset: CGFloat = 50
    @State private var formOpacity: Double = 0.0

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
                        Spacer(minLength: 60)

                        // Logo and title section
                        logoSection

                        // Login form
                        if authManager.isAuthenticated {
                            accountInfoView
                        } else {
                            loginFormView
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 20 : 40)
                }
                .ignoresSafeArea(.keyboard)
            }
            .navigationBarHidden(true)
            .onAppear(perform: setupInitialAnimation)
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

    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 20) {
            // Simple logo representation
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 80, height: 80)
                
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

            // Title and subtitle
            VStack(spacing: 8) {
                Text("Welcome to Feather")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text(authManager.isAuthenticated ? "You're signed in" : "Sign in to continue")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(formOpacity)
        .offset(y: formOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                formOpacity = 1.0
                formOffset = 0
            }
        }
    }

    // MARK: - Login Form View
    private var loginFormView: some View {
        VStack(spacing: 20) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Enter your email", text: $email)
                        .font(.system(size: 16))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($emailFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    SecureField("Enter your password", text: $password)
                        .font(.system(size: 16))
                        .textContentType(.password)
                        .focused($passwordFocused)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }

            // Error message
            if showError, let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
            }

            // Server settings toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showServerSettings.toggle()
                }
            }) {
                HStack {
                    Text("Server Settings")
                        .font(.system(size: 16, weight: .medium))
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        TextField("https://api.example.com", text: $apiBaseURL)
                            .font(.system(size: 16))
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Sign in button
            Button(action: onLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 20, height: 20)
                    }
                    
                    Text("Sign In")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isLoading || email.isEmpty || password.isEmpty ? Color.gray : Color.blue)
                )
                .foregroundColor(.white)
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)
        }
        .opacity(formOpacity)
        .offset(y: formOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                formOpacity = 1.0
                formOffset = 0
            }
        }
    }

    // MARK: - Account Info View (when logged in)
    private var accountInfoView: some View {
        VStack(spacing: 24) {
            // User info card
            VStack(spacing: 20) {
                // User avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }

                // Account details
                VStack(spacing: 8) {
                    Text(authManager.currentUserEmail ?? "Unknown")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)

                        Text("Signed In")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                    }
                }

                // Server info
                VStack(spacing: 4) {
                    Text("Connected to")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)

                    Text(authManager.apiBaseURL.absoluteString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemBackground))
            )

            // Sign out button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    authManager.logout()
                }
            }) {
                Text("Sign Out")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red)
                    )
                    .foregroundColor(.white)
            }
        }
        .opacity(formOpacity)
        .offset(y: formOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
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
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            logoScale = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            formOpacity = 1.0
            formOffset = 0
        }
    }
}