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
    @ObservedObject private var downloadManager = DownloadManager.shared
    
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
                
                // GET / state button
                statefulGetButton
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var currentDownload: Download? {
        downloadManager.downloads.first { download in
            download.fileName.contains(app.bundleIdentifier) || download.id.contains(app.bundleIdentifier)
        }
    }
    
    @ViewBuilder
    private var statefulGetButton: some View {
        let download = currentDownload
        if let download = download {
            if download.isCompleted {
                labelCapsule(text: String(localized: "Done"), systemName: "checkmark.circle.fill", fg: .green)
            } else if let task = download.task {
                switch task.state {
                case .running:
                    HStack(spacing: 6) {
                        ProgressView(value: Double(download.progress))
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .frame(width: 16, height: 16)
                        Text("\(Int(download.progress * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                case .suspended:
                    labelCapsule(text: String(localized: "Paused"), systemName: "pause.circle.fill", fg: .orange)
                case .canceling:
                    labelCapsule(text: String(localized: "Cancelling"), systemName: "xmark.circle.fill", fg: .red)
                case .completed:
                    labelCapsule(text: String(localized: "Done"), systemName: "checkmark.circle.fill", fg: .green)
                @unknown default:
                    labelCapsule(text: String(localized: "Queued"), systemName: "clock.fill", fg: .blue)
                }
            } else {
                labelCapsule(text: String(localized: "Queued"), systemName: "clock.fill", fg: .blue)
            }
        } else {
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
    }
    
    private func labelCapsule(text: String, systemName: String, fg: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(fg)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(fg)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(fg.opacity(0.12))
        .clipShape(Capsule())
    }
}