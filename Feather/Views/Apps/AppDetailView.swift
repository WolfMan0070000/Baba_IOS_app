//
//  AppDetailView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI
import Feather


struct AppDetailView: View {
    let app: IOSAppDTO
    @ObservedObject private var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScreenshotURL: String?
    @State private var showingScreenshotViewer = false
    @State private var reviews: [Review] = []
    @State private var isLoadingReviews = false
    @State private var showingAllReviews = false
    @State private var showingWriteReview = false
    @StateObject private var networkManager = NetworkManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
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
                    
                    // Reviews Section
                    reviewsSection
                    
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
        .sheet(isPresented: $showingScreenshotViewer) {
            if let imageUrl = selectedScreenshotURL {
                ScreenshotDetailView(imageUrl: imageUrl)
            }
        }
        .sheet(isPresented: $showingAllReviews) {
            AllReviewsView(app: app, reviews: reviews)
        }
        .sheet(isPresented: $showingWriteReview) {
            WriteReviewView(app: app) { newReview in
                reviews.insert(newReview, at: 0)
            }
        }
        .onAppear {
            loadReviews()
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
                        Text(.localized("NEW"))
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    
                    if app.isFeatured == true {
                        Text(.localized("FEATURED"))
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
            Text(.localized("Screenshots"))
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
                            selectedScreenshotURL = screenshot
                            showingScreenshotViewer = true
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.localized("About"))
                .font(.headline)
            
            Text(description)
                .font(.body)
                .lineSpacing(4)
        }
    }
    
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.localized("Information"))
                .font(.headline)
            
            VStack(spacing: 12) {
                InfoRow(title: .localized("Version"), value: app.version)
                
                if let size = app.size {
                    InfoRow(title: .localized("Size"), value: size)
                }
                
                InfoRow(title: .localized("Bundle ID"), value: app.bundleIdentifier)
                
                if let category = app.category {
                    InfoRow(title: .localized("Category"), value: category.displayName)
                }
            }
        }
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(.localized("Reviews"))
                    .font(.headline)
                
                Spacer()
                
                if !reviews.isEmpty {
                    Button(action: { showingAllReviews = true }) {
                        Text(.localized("See All"))
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if isLoadingReviews {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(.localized("Loading reviews..."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else if reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(.localized("No reviews yet"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(.localized("Be the first to review this app!"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if authManager.isAuthenticated {
                        Button(action: { showingWriteReview = true }) {
                            Text(.localized("Write a Review"))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    } else {
                        Text(.localized("Please log in to write a review"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    // Write Review Button
                    if authManager.isAuthenticated {
                        Button(action: { showingWriteReview = true }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                Text(.localized("Write a Review"))
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    ForEach(reviews.prefix(3), id: \.id) { review in
                        ReviewRowView(review: review)
                        
                        if review.id != reviews.prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private func loadReviews() {
        guard !isLoadingReviews else { return }
        
        isLoadingReviews = true
        
        Task {
            do {
                let fetchedReviews = try await networkManager.fetchAppReviews(
                    appId: app.id,
                    baseURL: authManager.apiBaseURL.absoluteString
                )
                
                await MainActor.run {
                    self.reviews = fetchedReviews
                    self.isLoadingReviews = false
                }
            } catch {
                print("Failed to load reviews: \(error)")
                await MainActor.run {
                    self.isLoadingReviews = false
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
        guard let download = currentDownload else { return String(localized: "Download") }
        
        if download.isCompleted {
            return String(localized: "Downloaded")
        }
        
        guard let task = download.task else {
            return String(localized: "Queued")
        }
        
        switch task.state {
        case .running:
            return String(localized: "Downloading")
        case .suspended:
            return String(localized: "Paused")
        case .canceling:
            return String(localized: "Cancelling")
        case .completed:
            return String(localized: "Completed")
        @unknown default:
            return String(localized: "Ready")
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
                // Navigate to Library when download is completed
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToLibraryTab"), object: nil)
                dismiss() // Also dismiss the current view
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
        if let ipaUrl = app.ipaUrl, let url = URL(string: ipaUrl) {
            let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
            let downloadResult = downloadManager.startDownload(from: url, id: downloadId)
            if downloadResult == nil {
                print("Download blocked: App already completed")
                // The UI should update automatically to show completed state
            }
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

private struct ReviewRowView: View {
    let review: Review
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(review.rating.rounded()) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        Text(String(format: "%.1f", review.rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(review.userName ?? "Anonymous User")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let createdAt = review.createdAt {
                    Text(formatReviewDate(createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let reviewText = review.text ?? review.comment, !reviewText.isEmpty {
                Text(reviewText)
                    .font(.body)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatReviewDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

private struct AllReviewsView: View {
    let app: IOSAppDTO
    let reviews: [Review]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(reviews, id: \.id) { review in
                        ReviewRowView(review: review)
                        Divider()
                    }
                }
                .padding()
            }
            .navigationTitle("Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct WriteReviewView: View {
    let app: IOSAppDTO
    let onReviewSubmitted: (Review) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var rating: Int = 5
    @State private var reviewText: String = ""
    @State private var userName: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    @StateObject private var networkManager = NetworkManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // App info
                        HStack {
                            LazyImage(url: URL(string: app.iconUrl)) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 60, height: 60)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.displayName)
                                    .font(.headline)
                                
                                if let developer = app.developer {
                                    Text(developer)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Rating Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(.localized("Rating"))
                                .font(.headline)
                            
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button(action: { rating = star }) {
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundColor(star <= rating ? .yellow : .gray)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Spacer()
                                
                                Text(ratingText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    TextField(.localized("Your name (optional)"), text: $userName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } header: {
                    Text(.localized("Name"))
                }
                
                Section {
                    TextEditor(text: $reviewText)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if reviewText.isEmpty {
                                Text(.localized("Write your review here..."))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text(.localized("Review"))
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(.localized("Write Review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(.localized("Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(.localized("Submit")) {
                        submitReview()
                    }
                    .disabled(isSubmitting || reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(isSubmitting)
        }
    }
    
    private var ratingText: String {
        switch rating {
        case 1: return String(localized: "Poor")
        case 2: return String(localized: "Fair")
        case 3: return String(localized: "Good")
        case 4: return String(localized: "Very Good")
        case 5: return String(localized: "Excellent")
        default: return ""
        }
    }
    
    private func submitReview() {
        guard !isSubmitting else { return }
        guard !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "Please write a review")
            return
        }
        
        errorMessage = nil
        isSubmitting = true
        
        let displayName = userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "Anonymous User" 
            : userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                let review = try await networkManager.submitAppReview(
                    appId: app.id,
                    userName: displayName,
                    rating: rating,
                    text: reviewText.trimmingCharacters(in: .whitespacesAndNewlines),
                    baseURL: authManager.apiBaseURL.absoluteString
                )
                
                await MainActor.run {
                    onReviewSubmitted(review)
                    dismiss()
                }
            } catch ReviewError.alreadyReviewed {
                await MainActor.run {
                    errorMessage = String(localized: "You have already reviewed this app")
                    isSubmitting = false
                }
            } catch ReviewError.authenticationRequired {
                await MainActor.run {
                    errorMessage = String(localized: "Please log in to submit a review")
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
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
