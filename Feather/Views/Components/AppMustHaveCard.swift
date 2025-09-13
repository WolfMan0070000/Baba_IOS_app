//
//  AppMustHaveCard.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI
import Feather

struct AppMustHaveCard: View {
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
            HStack(spacing: 12) {
                // App Icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibility(label: Text("\(app.displayName) app icon"))
                    } else if state.error != nil {
                        // Error state
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                            )
                            .accessibility(label: Text("Failed to load \(app.displayName) app icon"))
                    } else {
                        // Loading state
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .overlay(
                                ProgressView()
                            )
                            .accessibility(label: Text("Loading \(app.displayName) app icon"))
                    }
                }
                
                // App Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let developer = app.developer, !developer.isEmpty {
                        Text(developer)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    // Short description
                    if let shortDesc = app.displayShortDescription {
                        Text(shortDesc)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Rating
                    if let rating = app.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(index < Int(rating.rounded()) ? .orange : .gray.opacity(0.3))
                            }
                            Text("\(rating, specifier: "%.1f")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // GET button
                Button(action: { onGetTap?() }) {
                    Text("GET")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}