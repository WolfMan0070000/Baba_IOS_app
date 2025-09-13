//
//  AppGridCard.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI
import Feather

struct AppGridCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    let onGetTap: (() -> Void)?
    
    init(app: IOSAppDTO, onTap: @escaping () -> Void, onGetTap: (() -> Void)? = nil) {
        self.app = app
        self.onTap = onTap
        self.onGetTap = onGetTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                // Icon container with layered background and subtle shadow
                ZStack {
                    // Soft background halo
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.06),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 12)
                        .frame(width: 76, height: 76)
                        .opacity(0.8)
                    
                    // Main icon background
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.9))
                        .frame(width: 76, height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.45),
                                            Color.white.opacity(0.15)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.6
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                        .overlay(
                            // App Icon
                            LazyImage(url: URL(string: app.iconUrl)) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .accessibility(label: Text("\(app.displayName) app icon"))
                                } else if state.error != nil {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                        )
                                        .accessibility(label: Text("Failed to load \(app.displayName) app icon"))
                                } else {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.gray.opacity(0.12))
                                        .frame(width: 72, height: 72)
                                        .overlay(ProgressView())
                                        .accessibility(label: Text("Loading \(app.displayName) app icon"))
                                }
                            }
                        )
                }
                
                // Title and developer
                VStack(spacing: 4) {
                    Text(app.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(width: 96)
                    
                    if let developer = app.developer, !developer.isEmpty {
                        Text(developer)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(width: 96)
                    }
                }
                
                // GET button
                Button(action: { onGetTap?() }) {
                    Text("GET")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
            // Removed previous gray background for a cleaner floating look
        }
        .buttonStyle(PlainButtonStyle())
    }
}