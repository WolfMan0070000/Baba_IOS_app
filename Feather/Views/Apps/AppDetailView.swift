//
//  AppDetailView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//  Last Updated: 15.09.2025 - Apple-style redesign
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

    // Animation states
    @State private var headerOpacity: Double = 0.0
    @State private var headerOffset: CGFloat = 50
    @State private var screenshotsOpacity: Double = 0.0
    @State private var screenshotsOffset: CGFloat = 30
    @State private var descriptionOpacity: Double = 0.0
    @State private var descriptionOffset: CGFloat = 30
    @State private var infoOpacity: Double = 0.0
    @State private var infoOffset: CGFloat = 30
    @State private var reviewsOpacity: Double = 0.0
    @State private var reviewsOffset: CGFloat = 30
    @State private var downloadButtonScale: CGFloat = 0.8
    @State private var downloadButtonOpacity: Double = 0.0

    var body: some View {
        NavigationView {
            ZStack {
                // Apple-style background
                appleStyleBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Spacer(minLength: 20)

                        // Enhanced Header Section with Apple-style design
                        headerSection

                        // Screenshots Section with improved design
                        if let screenshots = app.screenshotUrls, !screenshots.isEmpty {
                            screenshotsSection(screenshots)
                        }

                        // Description Section with modern card design
                        if let description = app.displayDescription, !description.isEmpty {
                            descriptionSection(description)
                        }

                        // Information Section with Apple-style cards
                        informationSection

                        // Reviews Section with enhanced design
                        reviewsSection

                        Spacer(minLength: 120) // Space for floating download button
                    }
                    .padding(.horizontal, 20)
                }
                .ignoresSafeArea(.keyboard)
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topLeading) {
                // Custom back button with Apple-style design
                backButton
            }
            .overlay(alignment: .bottom) {
                // Enhanced floating download button
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
            setupInitialAnimations()
            loadReviews()
        }
    }
    
    // MARK: - Apple-style Background
    private var appleStyleBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.secondarySystemGroupedBackground).opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle pattern overlay
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    // Create subtle circular patterns
                    for i in 0..<6 {
                        let centerX = width * 0.15 + (width * 0.2 * CGFloat(i))
                        let centerY = height * 0.25 + (height * 0.15 * CGFloat(i))
                        let radius = min(width, height) * 0.1

                        path.addArc(
                            center: CGPoint(x: centerX, y: centerY),
                            radius: radius,
                            startAngle: .zero,
                            endAngle: .degrees(360),
                            clockwise: false
                        )
                    }
                }
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.02),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: min(geometry.size.width, geometry.size.height) * 0.1
                    )
                )
            }
        }
    }

    // MARK: - Custom Back Button
    private var backButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                dismiss()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.leading, 20)
        .padding(.top, 16)
        .accessibilityLabel("Go back")
        .accessibilityHint("Double tap to return to previous screen")
    }

    private var headerSection: some View {
        VStack(spacing: 24) {
            // Hero Banner Section
            heroBannerSection
        }
        .opacity(headerOpacity)
        .offset(y: headerOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                headerOpacity = 1.0
                headerOffset = 0
            }
        }
    }

    // MARK: - Hero Banner Section
    private var heroBannerSection: some View {
        ZStack {
            if let bannerUrl = app.bannerUrl, let url = URL(string: bannerUrl) {
                LazyImage(url: url) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.clear,
                                        Color.black.opacity(0.3)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        // Fallback banner with app icon
                        fallbackBanner
                    }
                }
            } else {
                fallbackBanner
            }

            // Overlay content
            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                HStack(spacing: 16) {
                    // App Icon on banner
                    LazyImage(url: URL(string: app.iconUrl)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "app.badge.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                )
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.displayName)
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)

                        if let developer = app.developer {
                            Text(developer)
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private var fallbackBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.blue.opacity(0.4)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Pattern overlay
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    for i in 0..<8 {
                        let x = width * 0.1 * CGFloat(i + 1)
                        let y = height * 0.2 + (height * 0.05 * CGFloat(i))
                        path.addEllipse(in: CGRect(x: x - 10, y: y - 10, width: 20, height: 20))
                    }
                }
                .fill(Color.white.opacity(0.1))
            }
        }
    }

    
    private func screenshotsSection(_ screenshots: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Screenshots")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(screenshots.count)")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(screenshots.indices, id: \.self) { index in
                        let screenshot = screenshots[index]

                        ZStack {
                            LazyImage(url: URL(string: screenshot)) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 220, height: 380)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                        .frame(width: 220, height: 380)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.secondary)
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                            }
                                        )
                                }
                            }
                            .frame(width: 220, height: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                            // Screenshot number badge
                            VStack {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 24, height: 24)
                                        Text("\(index + 1)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(8)
                                }
                                Spacer()
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedScreenshotURL = screenshot
                                showingScreenshotViewer = true
                            }
                        }
                        .accessibilityLabel("Screenshot \(index + 1) of \(screenshots.count)")
                        .accessibilityHint("Double tap to view full size")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .opacity(screenshotsOpacity)
        .offset(y: screenshotsOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                screenshotsOpacity = 1.0
                screenshotsOffset = 0
            }
        }
    }
    
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)

                Text("About This App")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Description Text
            Text(description)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            // What's New section (if available)
            if let whatsNew = app.displayWhatsNew, !whatsNew.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)

                        Text("What's New")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                    }

                    Text(whatsNew)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .opacity(descriptionOpacity)
        .offset(y: descriptionOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                descriptionOpacity = 1.0
                descriptionOffset = 0
            }
        }
    }
    
    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)

                Text("Information")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.primary)

                Spacer()
            }

            // Information Grid
            VStack(spacing: 12) {
                // Version and Size row
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "tag")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            Text("Version")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                        }

                        Text(app.version)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let size = app.size {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)

                                Text("Size")
                                    .font(.system(size: 14, weight: .medium, design: .default))
                                    .foregroundColor(.secondary)
                            }

                            Text(size)
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                // Bundle ID row
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "number.square")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        Text("Bundle ID")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                    }

                    Text(app.bundleIdentifier)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Category row
                if let category = app.category {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            Text("Category")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: category.icon ?? "folder")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)

                            Text(category.displayName)
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Compatibility section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        Text("Compatibility")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "iphone")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("iPhone")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "ipad")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text("iPad")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .opacity(infoOpacity)
        .offset(y: infoOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                infoOpacity = 1.0
                infoOffset = 0
            }
        }
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "star.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.orange)

                Text("Reviews & Ratings")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.primary)

                Spacer()

                if !reviews.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingAllReviews = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.blue)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            // Rating Summary
            if let rating = app.rating, rating > 0 {
                VStack(spacing: 12) {
                    // Overall Rating
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yellow)
                                }
                            }

                            if let reviewCount = app.reviewCount, reviewCount > 0 {
                                Text("\(reviewCount) reviews")
                                    .font(.system(size: 14, weight: .medium, design: .default))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Rating Distribution (real data)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(1...5, id: \.self) { star in
                                HStack(spacing: 8) {
                                    Text("\(star)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .frame(width: 12)

                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow)

                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.secondary.opacity(0.2))
                                                .frame(height: 4)

                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.yellow)
                                                .frame(width: geometry.size.width * ratingDistribution(for: star), height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                }
                            }
                        }
                        .frame(width: 120)
                    }
                }
                .padding(20)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // Reviews Content
            if isLoadingReviews {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading reviews...")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundColor(.primary)

                        Text("Please wait while we fetch the latest reviews")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(20)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if reviews.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "star.circle")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.orange)
                    }

                    VStack(spacing: 8) {
                        Text("No Reviews Yet")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.primary)

                        Text("Be the first to share your experience with this app!")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if authManager.isAuthenticated {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingWriteReview = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 16, weight: .medium))

                                Text("Write a Review")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 8) {
                            Text("Please sign in to write a review")
                                .font(.system(size: 14, weight: .regular, design: .default))
                                .foregroundColor(.secondary)

                            Button(action: {
                                // Navigate to login
                            }) {
                                Text("Sign In")
                                    .font(.system(size: 14, weight: .semibold, design: .default))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(24)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 16) {
                    // Write Review Button
                    if authManager.isAuthenticated {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingWriteReview = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 16, weight: .medium))

                                Text("Write a Review")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    // Recent Reviews
                    VStack(spacing: 0) {
                        ForEach(reviews.prefix(2), id: \.id) { review in
                            VStack(spacing: 12) {
                                HStack(alignment: .top, spacing: 12) {
                                    // User Avatar
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 40, height: 40)

                                        Text(String((review.userName ?? "Anonymous").prefix(1)).uppercased())
                                            .font(.system(size: 16, weight: .semibold, design: .default))
                                            .foregroundColor(.blue)
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        // User name and rating
                                        HStack {
                                            Text(review.userName ?? "Anonymous User")
                                                .font(.system(size: 16, weight: .semibold, design: .default))
                                                .foregroundColor(.primary)

                                            Spacer()

                                            HStack(spacing: 2) {
                                                ForEach(0..<5) { index in
                                                    Image(systemName: index < Int(review.rating.rounded()) ? "star.fill" : "star")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.yellow)
                                                }
                                            }

                                            Text(String(format: "%.1f", review.rating))
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }

                                        // Review text
                                        if let reviewText = review.text ?? review.comment, !reviewText.isEmpty {
                                            Text(reviewText)
                                                .font(.system(size: 15, weight: .regular, design: .default))
                                                .foregroundColor(.secondary)
                                                .lineLimit(3)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }

                                        // Date
                                        if let createdAt = review.createdAt {
                                            Text(formatReviewDate(createdAt))
                                                .font(.system(size: 13, weight: .regular, design: .default))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(16)

                            if review.id != reviews.prefix(2).last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .opacity(reviewsOpacity)
        .offset(y: reviewsOffset)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                reviewsOpacity = 1.0
                reviewsOffset = 0
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
    
    // MARK: - Rating Distribution Helper
    private func ratingDistribution(for star: Int) -> Double {
        guard !reviews.isEmpty else { return 0.0 }
        
        let starCount = reviews.filter { Int($0.rating.rounded()) == star }.count
        let totalReviews = reviews.count
        
        return totalReviews > 0 ? Double(starCount) / Double(totalReviews) : 0.0
    }
    
    private func formatReviewDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
    
    private var downloadButton: some View {
        VStack(spacing: 0) {

            // Download button
            Button(action: downloadApp) {
                ZStack {
                    // Background with gradient
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(downloadButtonColor)
                        .frame(height: 60)
                        .shadow(
                            color: downloadButtonColor.opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )

                    // Button content
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Image(systemName: downloadButtonIcon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        // Text content
                        VStack(alignment: .leading, spacing: 2) {
                            Text(downloadButtonText)
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .foregroundColor(.white)

                            if let download = currentDownload, !download.isCompleted && download.progress > 0 {
                                Text("\(Int(download.progress * 100))% complete")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                    .foregroundColor(.white.opacity(0.9))
                            } else if let download = currentDownload, download.isCompleted {
                                Text("Ready to install")
                                    .font(.system(size: 13, weight: .regular, design: .default))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }

                        Spacer()

                        // Action indicator
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 20)
                }
            }
            .disabled(isDownloadDisabled)
            .opacity(isDownloadDisabled ? 0.6 : 1.0)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .opacity(downloadButtonOpacity)
            .scaleEffect(downloadButtonScale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(1.2)) {
                    downloadButtonScale = 1.0
                    downloadButtonOpacity = 1.0
                }
            }
        }
        .accessibilityLabel("\(downloadButtonText) button")
        .accessibilityHint("Double tap to \(downloadButtonText.lowercased()) this app")
    }

    // MARK: - Helper Methods
    private func setupInitialAnimations() {
        // Reset all animation states
        headerOpacity = 0.0
        headerOffset = 50
        screenshotsOpacity = 0.0
        screenshotsOffset = 30
        descriptionOpacity = 0.0
        descriptionOffset = 30
        infoOpacity = 0.0
        infoOffset = 30
        reviewsOpacity = 0.0
        reviewsOffset = 30
        downloadButtonScale = 0.8
        downloadButtonOpacity = 0.0

        // Start staggered animations
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            headerOpacity = 1.0
            headerOffset = 0
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            screenshotsOpacity = 1.0
            screenshotsOffset = 0
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
            descriptionOpacity = 1.0
            descriptionOffset = 0
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
            infoOpacity = 1.0
            infoOffset = 0
        }

        withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
            reviewsOpacity = 1.0
            reviewsOffset = 0
        }

        withAnimation(.easeOut(duration: 0.8).delay(1.2)) {
            downloadButtonScale = 1.0
            downloadButtonOpacity = 1.0
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