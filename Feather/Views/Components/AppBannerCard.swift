//
//  AppBannerCard.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI
import Feather

struct AppBannerCard: View {
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
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibility(label: Text("\(app.displayName) app icon"))
                    } else if state.error != nil {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 58, height: 58)
                            .overlay(Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 58, height: 58)
                            .overlay(ProgressView())
                    }
                }
                
                // App Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(app.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let developer = app.developer, !developer.isEmpty {
                        Text(developer)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Rating
                    if let rating = app.rating, rating > 0 {
                        HStack(spacing: 4) {
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                        .font(.system(size: 10))
                                        .foregroundColor(index < Int(rating.rounded()) ? .orange : .gray.opacity(0.3))
                                }
                            }
                            Text("\(rating, specifier: "%.1f")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Short description
                    if let shortDesc = app.displayShortDescription {
                        Text(shortDesc)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // GET / state button
                statefulGetButton
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
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
            Button(action: downloadAction(for: download)) {
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

    private func downloadAction(for download: Download) -> () -> Void {
        return {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            if download.isCompleted {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToLibraryTab"), object: nil)
            } else if download.state == .downloading || download.task?.state == .running {
                DownloadManager.shared.pauseDownload(download)
            } else {
                DownloadManager.shared.resumeDownload(download)
            }
        }
    }
}