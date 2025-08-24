//
//  WelcomeView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showLoginView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // App Logo/Icon
                Image(systemName: "bird.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.primary)
                
                // Welcome Text
                VStack(spacing: 16) {
                    Text(.localized("Welcome to Baba Apps"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(.localized("Sign in to access your certificates and sync your apps across devices."))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        showLoginView = true
                    }) {
                        Text(.localized("Sign In"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // Skip login - set a flag to not show welcome again
                        UserDefaults.standard.set(true, forKey: "Feather.hasSeenWelcome")
                    }) {
                        Text(.localized("Skip for Now"))
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showLoginView) {
            NavigationView {
                LoginView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(.localized("Cancel")) {
                                showLoginView = false
                            }
                        }
                    }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                showLoginView = false
                UserDefaults.standard.set(true, forKey: "Feather.hasSeenWelcome")
            }
        }
    }
}

#Preview {
    WelcomeView()
}
