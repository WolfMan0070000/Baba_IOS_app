//
//  CategoryAppsView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI


struct CategoryAppsView: View {
    let category: AppCategory
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedApp: IOSAppDTO?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    ForEach(apps, id: \.id) { app in
                        CategoryAppCard(app: app) {
                            selectedApp = app
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedApp) { app in
            AppDetailView(app: app)
        }
    }
}

private struct CategoryAppCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // App Icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                }
                
                // App Info
                VStack(spacing: 4) {
                    Text(app.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Rating if available
                    if let rating = app.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CategoryAppsView(
        category: AppCategory(id: 1, nameEn: "Games", nameFa: "بازی‌ها", icon: "gamecontroller"),
        apps: [
            IOSAppDTO(
                id: 1,
                bundleIdentifier: "com.example.game",
                name: "Sample Game",
                nameFa: "بازی نمونه",
                version: "1.0.0",
                description: "A sample game for testing",
                descriptionFa: "بازی نمونه برای تست",
                shortDescriptionFa: "بازی نمونه",
                shortDescriptionEn: "Sample Game",
                iconUrl: "https://example.com/icon.png",
                ipaUrl: "https://example.com/game.ipa",
                screenshots: nil,
                bannerUrl: nil,
                developer: "Game Studio",
                hint: nil,
                fileSize: "50.2 MB",
                isPopular: true,
                isProChoice: false,
                isFeatured: false,
                isAi: false,
                whatsNew: nil,
                whatsNewFa: nil,
                whatsNewEn: nil,
                averageRating: 4.5,
                ratingCount: 200,
                categoryId: 1,
                category: AppCategory(id: 1, nameEn: "Games", nameFa: "بازی‌ها", icon: "gamecontroller"),
                createdAt: nil,
                updatedAt: nil,
                reviews: nil
            )
        ]
    ) { app in
        print("App tapped: \(app.displayName)")
    }
}