//
//  LoginView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
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

    var body: some View {
        Form {
            if authManager.isAuthenticated {
                // User is logged in - show account info and logout option
                Section("Account") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authManager.currentUserEmail ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Signed In")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Server") {
                    HStack {
                        Text("API Base URL")
                        Spacer()
                        Text(authManager.apiBaseURL.absoluteString)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Text("Sign Out")
                    }
                }
            } else {
                // User is not logged in - show login form
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
                        if isLoading { ProgressView() } else { Text("Sign In") }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                }
            }
        }
        .navigationTitle("Account")
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
                }
            }
        }
    }
}


