//
//  LoginView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NimbleViews

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var apiBaseURL: String = UserDefaults.standard.string(forKey: "Feather.apiBaseURL") ?? "http://localhost:4000"
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Account") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }

            Section("Server") {
                TextField("API Base URL", text: $apiBaseURL)
                    .autocapitalization(.none)
                    .textContentType(.URL)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button(action: onLogin) {
                    if isLoading { ProgressView() } else { Text("Login") }
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty)
                Button(role: .destructive) {
                    AuthManager.shared.logout()
                } label: { Text("Logout") }
                .disabled(!AuthManager.shared.isAuthenticated)
            }
        }
        .navigationTitle("Account Login")
    }

    private func onLogin() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                AuthManager.shared.setApiBaseURL(apiBaseURL)
                try await AuthManager.shared.login(email: email, password: password)
                // After successful login, fetch and install certificate pair
                do { try await AuthManager.shared.fetchCertificateAndInstall() } catch { /* ignore if not assigned */ }
                await MainActor.run { isLoading = false }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


