//
//  AppHeroCard.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//  Last Updated: 15.09.2025 - Apple-style redesign
//

import SwiftUI
import NimbleViews
import NukeUI
import Feather

struct AppHeroCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    let onGetTap: (() -> Void)?
    
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var isHovered = false
    @State private var iconLoaded = false
    
    init(app: IOSAppDTO, onTap: @escaping () -> Void, onGetTap: (() -> Void)? = nil) {
        self.app = app
        self.onTap = onTap
        self.onGetTap = onGetTap
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Hero banner with app icon
                heroBannerSection
                
                // App information section
                appInfoSection
            }
            .background(modernCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.displayName) app")
        .accessibilityHint("Tap to view app details")
    }
    
    private var heroBannerSection: some View {
        ZStack {
            // Sophisticated background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.15),
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140) // Reduced from 200 to make hero banner more compact
            
            // Decorative elements
            GeometryReader { geometry in
                // Floating circles
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: CGFloat.random(in: 20...60))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .animation(
                            Animation.easeInOut(duration: Double.random(in: 3...6))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.5),
                            value: isHovered
                        )
                }
            }
            
            // Main app icon
            modernAppIcon
                .frame(width: 120, height: 120) // Reduced from 120x120 to make icon more compact
        }
        .frame(height: 140) // Reduced from 200 to make hero banner more compact
    }
    
    private var modernAppIcon: some View {
        ZStack {
            // Sophisticated background with multiple layers
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 20)
                .frame(width: 100, height: 100) // Reduced from 120x120 to make icon more compact
            
            // Main icon container
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                .frame(width: 100, height: 100) // Reduced from 120x120 to make icon more compact
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            LazyImage(url: URL(string: app.iconUrl)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 95, height: 95) // Reduced from 108x108 to match smaller container
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .accessibility(label: Text("\(app.displayName) app icon"))
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                iconLoaded = true
                            }
                        }
                } else if state.error != nil {
                    // Error state with modern styling
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 72, height: 72) // Reduced from 108x108 to match smaller container
                        .overlay(
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.red.opacity(0.7))
                        )
                        .shadow(color: Color.red.opacity(0.2), radius: 8, x: 0, y: 4)
                        .accessibility(label: Text("Failed to load \(app.displayName) app icon"))
                } else {
                    // Loading state with shimmer effect
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 72, height: 72) // Reduced from 108x108 to match smaller container
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.secondary)
                        )
                        .shadow(color: Color.gray.opacity(0.15), radius: 6, x: 0, y: 3)
                        .accessibility(label: Text("Loading \(app.displayName) app icon"))
                }
            }
        }
    }
    
    private var appInfoSection: some View {
        VStack(spacing: 16) { // Reduced from 20 to make card more compact
            // App name and developer
            VStack(spacing: 8) { // Reduced from 12 to make card more compact
                Text(app.displayName)
                    .font(.system(size: 22, weight: .bold, design: .default)) // Reduced from 28 to make title more compact
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                
                if let developer = app.developer, !developer.isEmpty {
                    Text(developer)
                        .font(.system(size: 14, weight: .medium, design: .default)) // Reduced from 18 to make developer text more compact
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            // Rating and metadata
            HStack(spacing: 24) {
                if let rating = app.rating, rating > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(index < Int(rating.rounded()) ? .orange : .gray.opacity(0.3))
                            }
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                
                if let fileSize = app.fileSize, !fileSize.isEmpty {
                    Text(fileSize)
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
            }
            
            // Modern action button (stateful)
            statefulHeroButton
        }
        .padding(20) // Reduced from 32 to make card more compact
        .frame(maxWidth: .infinity)
    }

    // MARK: - Download stateful button
    @ViewBuilder
    private var statefulHeroButton: some View {
        let download = currentDownload
        if let download = download {
            Button(action: downloadAction(for: download)) {
                statefulButtonContent(download: download)
            }
        } else {
            Button(action: { onGetTap?() }) {
                primaryButtonLabel(title: "GET", color: .blue, icon: "arrow.down.circle.fill")
            }
        }
    }

    // Current download for this app
    private var currentDownload: Download? {
        downloadManager.downloads.first { download in
            download.fileName.contains(app.bundleIdentifier) || download.id.contains(app.bundleIdentifier)
        }
    }

    // Build label for different states
    @ViewBuilder
    private func statefulButtonContent(download: Download) -> some View {
        if download.isCompleted {
            primaryButtonLabel(title: String(localized: "Open"), color: .green, icon: "checkmark.circle.fill")
        } else if let task = download.task {
            switch task.state {
            case .running:
                HStack(spacing: 12) {
                    ProgressView(value: Double(download.progress))
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 18, height: 18)
                    Text("\(Int(download.progress * 100))%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(height: 44)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            case .suspended:
                primaryButtonLabel(title: String(localized: "Paused"), color: .orange, icon: "pause.circle.fill")
            case .canceling:
                primaryButtonLabel(title: String(localized: "Cancelling"), color: .red, icon: "xmark.circle.fill")
            case .completed:
                primaryButtonLabel(title: String(localized: "Open"), color: .green, icon: "checkmark.circle.fill")
            @unknown default:
                primaryButtonLabel(title: String(localized: "Queued"), color: .blue, icon: "clock.fill")
            }
        } else {
            primaryButtonLabel(title: String(localized: "Queued"), color: .blue, icon: "clock.fill")
        }
    }

    private func primaryButtonLabel(title: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.85)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: color.opacity(0.35), radius: 8, x: 0, y: 4)
        )
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
    
    private var modernCardBackground: some View {
        ZStack {
            // Base background with Apple-style material
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
            
            // Sophisticated gradient overlay
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(isHovered ? 0.12 : 0.06),
                            Color.white.opacity(isHovered ? 0.04 : 0.02),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Modern border with gradient
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(isHovered ? 0.3 : 0.2),
                            Color.gray.opacity(isHovered ? 0.25 : 0.15),
                            Color.clear
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AppHeroCard(
            app: IOSAppDTO(
                id: 1,
                bundleIdentifier: "com.example.app1",
                name: "Sample App 1",
                nameFa: "برنامه نمونه ۱",
                version: "1.0.0",
                description: "This is a sample app description that shows how the hero card looks with longer text content.",
                descriptionFa: "این توضیحات نمونه برنامه است که نشان می‌دهد کارت قهرمان چگونه با متن طولانی‌تر به نظر می‌رسد.",
                shortDescriptionFa: "برنامه نمونه",
                shortDescriptionEn: "Sample App",
                iconUrl: "https://example.com/icon1.png",
                ipaUrl: "https://example.com/app1.ipa",
                screenshots: nil,
                bannerUrl: nil,
                developer: "Developer Name",
                hint: nil,
                fileSize: "25.4 MB",
                isPopular: false,
                isProChoice: false,
                isFeatured: false,
                isAi: false,
                whatsNew: nil,
                whatsNewFa: nil,
                whatsNewEn: nil,
                averageRating: 4.5,
                ratingCount: 128,
                categoryId: 1,
                category: nil,
                createdAt: nil,
                updatedAt: nil,
                reviews: nil
            ),
            onTap: {},
            onGetTap: nil
        )
        .frame(width: 400)
        
        AppHeroCard(
            app: IOSAppDTO(
                id: 2,
                bundleIdentifier: "com.example.app2",
                name: "Another Sample App",
                nameFa: "برنامه نمونه دیگر",
                version: "2.0.0",
                description: "This is another sample app description.",
                descriptionFa: "این توضیحات نمونه برنامه دیگری است.",
                shortDescriptionFa: "برنامه نمونه",
                shortDescriptionEn: "Sample App",
                iconUrl: "https://example.com/icon2.png",
                ipaUrl: "https://example.com/app2.ipa",
                screenshots: nil,
                bannerUrl: nil,
                developer: "Another Developer",
                hint: nil,
                fileSize: "30.2 MB",
                isPopular: false,
                isProChoice: false,
                isFeatured: false,
                isAi: false,
                whatsNew: nil,
                whatsNewFa: nil,
                whatsNewEn: nil,
                averageRating: 4.8,
                ratingCount: 256,
                categoryId: 1,
                category: nil,
                createdAt: nil,
                updatedAt: nil,
                reviews: nil
            ),
            onTap: {},
            onGetTap: nil
        )
        .frame(width: 400)
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}