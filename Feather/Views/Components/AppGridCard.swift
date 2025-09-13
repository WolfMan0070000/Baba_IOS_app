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
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    init(app: IOSAppDTO, onTap: @escaping () -> Void, onGetTap: (() -> Void)? = nil) {
        self.app = app
        self.onTap = onTap
        self.onGetTap = onGetTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
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
                        .frame(width: 72, height: 72)
                        .opacity(0.8)
                    
                    // Main icon background
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.9))
                        .frame(width: 72, height: 72)
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
                                        .frame(width: 68, height: 68)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .accessibility(label: Text("\(app.displayName) app icon"))
                                } else if state.error != nil {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.red.opacity(0.1))
                                        .frame(width: 68, height: 68)
                                        .overlay(
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.red)
                                        )
                                        .accessibility(label: Text("Failed to load \(app.displayName) app icon"))
                                } else {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.gray.opacity(0.12))
                                        .frame(width: 68, height: 68)
                                        .overlay(ProgressView())
                                        .accessibility(label: Text("Loading \(app.displayName) app icon"))
                                }
                            }
                        )
                }
                
                // Title and developer
                VStack(spacing: 3) {
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
                
                statefulGetButton
            }
            .padding(.vertical, 6)
            .frame(height: 160) // Fixed height for consistent grid layout across pages
            // Removed previous gray background for a cleaner floating look
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
                        VStack(spacing: 2) {
                            ProgressView(value: Double(download.progress))
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .frame(width: 18, height: 18)
                            Text("\(Int(download.progress * 100))%")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 10)
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
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
    
    private func labelCapsule(text: String, systemName: String, fg: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(fg)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(fg)
        }
        .padding(.horizontal, 10)
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