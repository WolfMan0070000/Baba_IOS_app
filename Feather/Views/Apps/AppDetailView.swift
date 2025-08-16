//
//  AppDetailView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI

struct AppDetailView: View {
    let app: IOSAppDTO
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScreenshot: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Screenshots Section
                    if let screenshots = app.screenshotUrls, !screenshots.isEmpty {
                        screenshotsSection(screenshots)
                    }
                    
                    // Description Section
                    if let description = app.displayDescription, !description.isEmpty {
                        descriptionSection(description)
                    }
                    
                    // Information Section
                    informationSection
                    
                    Spacer(minLength: 100) // Space for floating download button
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                downloadButton
            }
        }
        .sheet(item: Binding<ScreenshotItem?>(
            get: { selectedScreenshot.map(ScreenshotItem.init) },
            set: { selectedScreenshot = $0?.url }
        )) { item in
            ScreenshotDetailView(imageUrl: item.url)
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // App Icon
            LazyImage(url: URL(string: app.iconUrl)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "app.badge")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(app.displayName)
                    .font(.title2.bold())
                    .lineLimit(2)
                
                if let developer = app.developer {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let category = app.category {
                    Text(category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                
                // Rating and Reviews
                if let rating = app.rating, rating > 0 {
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let reviewCount = app.reviewCount, reviewCount > 0 {
                            Text("(\(reviewCount))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Badges
                HStack(spacing: 8) {
                    if app.isNew == true {
                        Text("NEW")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    
                    if app.isFeatured == true {
                        Text("FEATURED")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func screenshotsSection(_ screenshots: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screenshots")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(screenshots, id: \.self) { screenshot in
                        LazyImage(url: URL(string: screenshot)) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 200, height: 350)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 200, height: 350)
                                    .overlay(
                                        ProgressView()
                                    )
                            }
                        }
                        .onTapGesture {
                            selectedScreenshot = screenshot
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
            
            Text(description)
                .font(.body)
                .lineSpacing(4)
        }
    }
    
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(title: "Version", value: app.version)
                
                if let size = app.size {
                    InfoRow(title: "Size", value: size)
                }
                
                InfoRow(title: "Bundle ID", value: app.bundleIdentifier)
                
                if let category = app.category {
                    InfoRow(title: "Category", value: category.displayName)
                }
            }
        }
    }
    
    private var downloadButton: some View {
        VStack {
            Spacer()
            
            Button(action: downloadApp) {
                HStack {
                    Image(systemName: downloadButtonIcon)
                        .font(.title2)
                    
                    if let download = currentDownload, !download.isCompleted {
                        VStack(spacing: 2) {
                            Text(downloadButtonText)
                                .font(.headline)
                            if download.progress > 0 {
                                Text("\(Int(download.progress * 100))%")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                    } else {
                        Text(downloadButtonText)
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(downloadButtonColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .disabled(isDownloadDisabled)
            .padding(.horizontal)
            .padding(.bottom, 34) // Safe area bottom
            .background(
                LinearGradient(
                    colors: [Color.clear, Color(uiColor: .systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
            )
        }
    }
    
    // Computed properties for download button state
    private var currentDownload: Download? {
        downloadManager.downloads.first { download in
            download.fileName.contains(app.bundleIdentifier) || download.id.contains(app.bundleIdentifier)
        }
    }
    
    private var downloadButtonText: String {
        guard let download = currentDownload else { return "دانلود" }
        
        if download.isCompleted {
            return "نصب شده"
        }
        
        guard let task = download.task else {
            return "در صف"
        }
        
        switch task.state {
        case .running:
            return "در حال دانلود"
        case .suspended:
            return "متوقف شده"
        case .canceling:
            return "لغو..."
        case .completed:
            return "تکمیل شده"
        @unknown default:
            return "آماده"
        }
    }
    
    private var downloadButtonIcon: String {
        guard let download = currentDownload else { return "arrow.down.circle.fill" }
        
        if download.isCompleted {
            return "checkmark.circle.fill"
        }
        
        guard let task = download.task else {
            return "clock.circle.fill"
        }
        
        switch task.state {
        case .running:
            return "arrow.down.circle.fill"
        case .suspended:
            return "pause.circle.fill"
        case .canceling:
            return "xmark.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        @unknown default:
            return "arrow.down.circle.fill"
        }
    }
    
    private var downloadButtonColor: Color {
        guard let download = currentDownload else { return .blue }
        
        if download.isCompleted {
            return .green
        }
        
        guard let task = download.task else {
            return .orange
        }
        
        switch task.state {
        case .running:
            return .blue
        case .suspended:
            return .orange
        case .canceling:
            return .red
        case .completed:
            return .green
        @unknown default:
            return .blue
        }
    }
    
    private var isDownloadDisabled: Bool {
        guard let download = currentDownload else { return false }
        return download.isCompleted || download.task?.state == .canceling
    }
    
    private func downloadApp() {
        // Check if already downloading or completed
        if let existingDownload = currentDownload {
            if existingDownload.isCompleted {
                // Already installed, do nothing
                return
            }
            
            // If paused/suspended, resume it
            if let task = existingDownload.task, task.state == .suspended {
                downloadManager.resumeDownload(existingDownload)
                return
            }
            
            // If in queue or running, do nothing
            return
        }
        
        // Start new download
        if let url = URL(string: app.ipaUrl) {
            let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
            _ = downloadManager.startDownload(from: url, id: downloadId)
        } else {
            // Fallback: try to add as source if no direct download
            let sourceUrl = "https://example.com/\(app.bundleIdentifier).json" // This should come from backend
            if let url = URL(string: sourceUrl) {
                Storage.shared.addSource(url, name: app.displayName, identifier: app.bundleIdentifier, iconURL: URL(string: app.iconUrl), deferSave: false) { _ in }
            }
        }
    }
}

private struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

private struct ScreenshotItem: Identifiable {
    let id = UUID()
    let url: String
}

private struct ScreenshotDetailView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                LazyImage(url: URL(string: imageUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    AppDetailView(app: IOSAppDTO(
        id: 1,
        bundleIdentifier: "com.example.app",
        name: "Sample App",
        nameFa: "برنامه نمونه",
        version: "1.0.0",
        description: "This is a sample app description that shows how the app works and what it does.",
        descriptionFa: "این توضیحات نمونه برنامه است که نشان می‌دهد برنامه چگونه کار می‌کند.",
        shortDescriptionFa: "برنامه نمونه",
        shortDescriptionEn: "Sample App",
        iconUrl: "https://example.com/icon.png",
        ipaUrl: "https://example.com/app.ipa",
        screenshots: "{\"screenshots\":[\"https://example.com/screenshot1.png\", \"https://example.com/screenshot2.png\"]}",
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
        category: AppCategory(id: 1, nameEn: "Games", nameFa: "بازی‌ها", icon: "gamecontroller"),
        createdAt: nil,
        updatedAt: nil,
        reviews: nil
    ))
}
