//
//  HomeView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

struct HomeView: View {
    @State private var isLoading = false  // Start with false for better UX
    @State private var sections: [HomepageSectionDTO] = []
    @State private var appsById: [String: IOSAppDTO] = [:]
    @State private var categories: [AppCategory] = []
    @State private var featuredApps: [IOSAppDTO] = []
    @State private var selectedApp: IOSAppDTO?
    @State private var selectedCategory: AppCategory?
    @State private var categoryApps: [IOSAppDTO] = []
    @State private var isLoadingCategoryApps = false
    @State private var selectedSectionApps: [IOSAppDTO] = []
    @State private var selectedSectionTitle: String? = nil
    @State private var showingSectionApps = false
    @State private var hasInitialLoad = false  // Track if we've loaded data at least once
    
    // Performance and Caching
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var cacheManager = DataCacheManager.shared
    @StateObject private var lifecycleManager = AppLifecycleManager.shared
    @ObservedObject private var authManager = AuthManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if isLoading {
                        loadingView
                    } else if !sections.filter({ $0.enabled }).isEmpty {
                        mainContentView
                    } else {
                        emptyStateView
                    }
                }
                .navigationTitle(String(localized: "Home"))
                .navigationBarTitleDisplayMode(.large)
                
                // Hidden NavigationLink for programmatic navigation
                NavigationLink(
                    destination: Group {
                        if let category = selectedCategory {
                            CategoryAppsView(
                                category: category,
                                apps: categoryApps,
                                onAppTap: { app in
                                    selectedApp = app
                                }
                            )
                            .onAppear {
                                print("📱 CategoryAppsView: Appeared for category '\(category.displayName)' with \(categoryApps.count) apps")
                            }
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: Binding<Bool>(
                        get: { 
                            let isActive = selectedCategory != nil
                            if isActive {
                                print("➡️ NavigationLink: Becoming active for category '\(selectedCategory?.displayName ?? "unknown")'")
                            }
                            return isActive
                        },
                        set: { newValue in
                            print("⬅️ NavigationLink: Set active to \(newValue) (was: \(selectedCategory != nil))")
                            if !newValue { 
                                selectedCategory = nil 
                                print("📱 NavigationLink: Cleared selectedCategory")
                            }
                        }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .task {
                // Always load fresh data on initial app launch to ensure up-to-date content
                if !hasInitialLoad {
                    await loadContent(force: true, reason: "initial_app_launch")
                }
            }
            .refreshable { 
                // User explicitly pulled to refresh - get fresh data
                await loadContent(force: true, reason: "pull_to_refresh")
            }
            .onChange(of: authManager.apiBaseURL) { _ in
                // API base URL changed (different server) - clear cache and reload
                networkManager.clearHomepageCache(baseURL: authManager.apiBaseURL.absoluteString)
                Task { await loadContent(force: true, reason: "api_url_changed") }
            }
            .onAppear {
                // Check if we need to refresh due to app lifecycle
                if lifecycleManager.shouldRefreshOnNextAppear {
                    print("🔄 HomeView: App lifecycle triggered refresh")
                    lifecycleManager.markRefreshHandled()
                    Task { await loadContent(force: true, reason: "app_reopen") }
                } else if sections.isEmpty && !hasInitialLoad {
                    // Force fresh data if we have no data at all (empty state) 
                    Task { await loadContent(force: true, reason: "first_appear_no_data") }
                }
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    // User just logged in - refresh data
                    Task { await loadContent(force: true, reason: "user_login") }
                } else {
                    // User logged out - clear data
                    sections = []
                    appsById = [:]
                    categories = []
                    featuredApps = []
                    hasInitialLoad = false
                }
            }
        }
        .sheet(item: $selectedApp) { app in
            AppDetailView(app: app)
        }
        .sheet(isPresented: $showingSectionApps) {
            if let title = selectedSectionTitle {
                SectionAppsView(
                    title: title,
                    apps: selectedSectionApps,
                    onAppTap: { app in
                        showingSectionApps = false
                        selectedApp = app
                    }
                )
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(.localized("Loading apps..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Process only the configured sections from admin panel
                ForEach(sections.filter({ $0.enabled }).sorted(by: { $0.order < $1.order }), id: \.id) { section in
                    Group {
                        switch section.type {
                        case "featured":
                            // Featured section with apps from admin panel
                            if let appIds = section.appIds, !appIds.isEmpty {
                                let sectionApps = appIds.compactMap { id in
                                    appsById[id] ?? appsById.values.first(where: { "\($0.id)" == id })
                                }
                                if !sectionApps.isEmpty {
                                    FeaturedSectionView(
                                        title: section.localizedTitle ?? String(localized: "Featured"), 
                                        apps: sectionApps,
                                        onAppTap: { app in
                                            selectedApp = app
                                        },
                                        onSectionTap: showSectionApps
                                    )
                                }
                            }
                            
                        case "categories":
                            // Categories section - show selected categories from admin panel
                            let categoriesToShow = {
                                if let categoryIds = section.categoryIds, !categoryIds.isEmpty {
                                    // Show only the categories selected by admin
                                    let filtered = categoryIds.compactMap { id in
                                        categories.first(where: { $0.id == id })
                                    }
                                    print("🏷️ HomeView: Showing \(filtered.count) admin-selected categories from \(categoryIds.count) IDs")
                                    return filtered
                                } else {
                                    // Fallback: show all categories if none specifically selected
                                    print("🏷️ HomeView: Showing all \(categories.count) categories (no specific selection)")
                                    return categories
                                }
                            }()
                            
                            if !categoriesToShow.isEmpty {
                                CategoriesSectionView(
                                    title: section.localizedTitle ?? String(localized: "Categories"),
                                    categories: categoriesToShow,
                                    onCategoryTap: { categoryId in
                                        print("🏷️ HomeView: Category tap received for ID \(categoryId)")
                                        loadCategoryApps(categoryId: categoryId)
                                    },
                                    onSectionTap: { title in
                                        // Show all categories as apps (you can customize this)
                                        print("🏷️ HomeView: Categories section tapped: \(title)")
                                        // For now, just show a sample message - you can implement category list view
                                    }
                                )
                            } else {
                                Text("No categories available")
                                    .padding()
                                    .foregroundColor(.secondary)
                                    .onAppear {
                                        print("⚠️ HomeView: No categories to display - total categories: \(categories.count)")
                                    }
                            }
                            
                        case "appStoreCategories":
                            // App Store-style categories section
                            let categoriesToShow = {
                                if let categoryIds = section.categoryIds, !categoryIds.isEmpty {
                                    // Show only the categories selected by admin
                                    let filtered = categoryIds.compactMap { id in
                                        categories.first(where: { $0.id == id })
                                    }
                                    print("🏷️ HomeView: Showing \(filtered.count) admin-selected App Store categories from \(categoryIds.count) IDs")
                                    return filtered
                                } else {
                                    // Fallback: show all categories if none specifically selected
                                    print("🏷️ HomeView: Showing all \(categories.count) App Store categories (no specific selection)")
                                    return categories
                                }
                            }()
                            
                            if !categoriesToShow.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Section Title - Clickable
                                    if let title = section.localizedTitle {
                                        Button(action: {
                                            // Navigate to categories list
                                            print("🔗 App Store Categories section tapped: \(title)")
                                            // Show all categories as a list (you can implement this)
                                        }) {
                                            HStack {
                                                Text(title)
                                                    .font(.title2.bold())
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.headline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.horizontal, 20)
                                    }
                                    
                                    // App Store-style Categories
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(categoriesToShow.prefix(10), id: \.id) { category in
                                                AppStoreCategoryCard(category: category) {
                                                    print("🏷️ HomeView: App Store Category tap received for ID \(category.id)")
                                                    loadCategoryApps(categoryId: category.id)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            } else {
                                Text("No categories available")
                                    .padding()
                                    .foregroundColor(.secondary)
                                    .onAppear {
                                        print("⚠️ HomeView: No App Store categories to display - total categories: \(categories.count)")
                                    }
                            }
                            
                        case "editorsChoice", "personalized", "trending", "newReleases", "banner", "carousel", "grid", "hero":
                            // Regular app sections with configured apps
                            AppSectionView(section: section, appsById: appsById, onAppTap: { app in
                                selectedApp = app
                            }, onSectionTap: showSectionApps)
                            
                        default:
                            // Handle any other section types as regular app sections
                            AppSectionView(section: section, appsById: appsById, onAppTap: { app in
                                selectedApp = app
                            }, onSectionTap: showSectionApps)
                        }
                    }
                }
                
                // Bottom spacing
                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .refreshable {
            await loadContent(force: true, reason: "pull_to_refresh")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(String(localized: "No Apps Available"))
                    .font(.title2.bold())
                
                Text(String(localized: "Please check your connection and try again"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(String(localized: "Retry")) {
                Task { await loadContent(force: true, reason: "user_retry") }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Data Loading
    
    private func showSectionApps(title: String, apps: [IOSAppDTO]) {
        selectedSectionTitle = title
        selectedSectionApps = apps
        showingSectionApps = true
        print("📱 HomeView: Showing section apps for '\(title)' with \(apps.count) apps")
    }
    
    private func loadCategoryApps(categoryId: Int) {
        print("📱 HomeView: loadCategoryApps called with categoryId: \(categoryId)")
        
        // Find the category from our categories list
        guard let category = categories.first(where: { $0.id == categoryId }) else {
            print("❌ HomeView: Category with ID \(categoryId) not found in categories list of \(categories.count) items")
            for cat in categories {
                print("   Available category: ID=\(cat.id), name=\(cat.displayName)")
            }
            return
        }
        
        print("✅ HomeView: Found category '\(category.displayName)' (ID: \(categoryId))")
        isLoadingCategoryApps = true
        
        Task {
            do {
                let baseURL = authManager.apiBaseURL.absoluteString
                print("🌐 HomeView: Fetching apps for category \(categoryId) from \(baseURL)")
                
                let apps = try await networkManager.fetchCategoryApps(
                    categoryId: categoryId,
                    baseURL: baseURL,
                    forceRefresh: false
                )
                
                print("📦 HomeView: Loaded \(apps.count) apps for category '\(category.displayName)'")
                
                await MainActor.run {
                    self.categoryApps = apps
                    self.selectedCategory = category
                    self.isLoadingCategoryApps = false
                    print("📱 HomeView: Navigation should trigger - selectedCategory set to '\(category.displayName)'")
                    print("📱 HomeView: Current selectedCategory is now: \(self.selectedCategory?.displayName ?? "nil")")
                }
            } catch {
                print("❌ HomeView: Failed to load category apps: \(error)")
                await MainActor.run {
                    self.isLoadingCategoryApps = false
                }
            }
        }
    }
    
    private func loadContent(force: Bool = false, reason: String = "unknown") async {
        // Avoid duplicate loading requests
        guard !isLoading else {
            print("⚠️ HomeView: Already loading, skipping request (reason: \(reason))")
            return
        }
        
        isLoading = true
        defer { 
            isLoading = false 
            hasInitialLoad = true
        }
        
        print("🔄 HomeView: Loading content (force: \(force), reason: \(reason))")
        
        do {
            let baseURL = authManager.apiBaseURL.absoluteString
            print("🌐 HomeView: Fetching from baseURL: \(baseURL)")
            
            // Clear cache for fresh data requests and user-triggered refreshes
            if force && (reason == "pull_to_refresh" || reason == "user_retry" || reason == "initial_app_launch" || reason == "first_appear_no_data") {
                if reason == "initial_app_launch" || reason == "first_appear_no_data" {
                    // For app launch, clear ALL caches to ensure completely fresh data
                    networkManager.clearAllAppCaches(baseURL: baseURL)
                    print("🧹 HomeView: Cleared ALL caches for app launch (reason: \(reason))")
                } else {
                    // For user actions, clear only homepage cache
                    networkManager.clearHomepageCache(baseURL: baseURL)
                    print("🧹 HomeView: Cleared homepage cache for user action (reason: \(reason))")
                }
            }
            
            // Load data with appropriate caching strategy
            let (homepage, categoriesResponse, featuredResponse) = try await networkManager.fetchHomepageData(
                baseURL: baseURL,
                forceRefresh: force
            )
            
            let layout = homepage.sections
            print("📱 HomeView: Loaded \(layout.count) sections from admin panel")
            
            // Print section details for debugging
            for (index, section) in layout.enumerated() {
                print("   Section \(index + 1): \(section.localizedTitle ?? "Untitled") (\(section.type), enabled: \(section.enabled))")
            }
            
            // Load all referenced apps from enabled sections only
            let enabledSections = layout.filter({ $0.enabled })
            let sectionAppIds = Array(Set(enabledSections.compactMap({ $0.appIds }).flatMap({ $0 })))
            var map: [String: IOSAppDTO] = [:]
            
            print("📦 HomeView: Loading \(sectionAppIds.count) apps from \(enabledSections.count) enabled sections")
            
            for id in sectionAppIds {
                do {
                    let app = try await networkManager.fetchApp(
                        id: id,
                        baseURL: baseURL,
                        forceRefresh: force
                    )
                    map[id] = app
                } catch {
                    print("❌ HomeView: Failed to load app \(id): \(error)")
                }
            }
            
            // Load featured apps only if there's a "featured" section configured
            var featuredAppsResponse: [IOSAppDTO] = []
            let hasFeaturedSection = enabledSections.contains { $0.type == "featured" }
            if hasFeaturedSection {
                print("⭐ HomeView: Loading featured apps (featured section configured)")
                featuredAppsResponse = featuredResponse
            } else {
                print("⚠️ HomeView: Skipping featured apps (no featured section configured)")
            }
            
            // Load categories only if there's a "categories" section configured
            var categoriesResponseFiltered: [AppCategory] = []
            let hasCategoriesSection = enabledSections.contains { $0.type == "categories" }
            if hasCategoriesSection {
                print("🏷️ HomeView: Loading categories (categories section configured)")
                categoriesResponseFiltered = categoriesResponse
                
                // Debug category icons
                for category in categoriesResponseFiltered {
                    let iconStatus = category.icon?.isEmpty == false ? "✅ Has icon: \(category.icon!)" : "❌ No icon"
                    print("🏷️ Category '\(category.displayName)': \(iconStatus)")
                }
            } else {
                print("⚠️ HomeView: Skipping categories (no categories section configured)")
            }
            
            await MainActor.run {
                self.sections = layout
                self.appsById = map
                self.categories = categoriesResponseFiltered
                self.featuredApps = featuredAppsResponse
                
                print("✅ HomeView: Content loaded successfully (reason: \(reason))")
                print("   📊 Enabled Sections: \(enabledSections.count)")
                print("   🏷️ Categories: \(categoriesResponseFiltered.count)")
                print("   ⭐ Featured: \(featuredAppsResponse.count)")
                print("   📱 Apps: \(map.count)")
                if force {
                    print("   🆕 Fresh data loaded from backend (no cache used)")
                } else {
                    print("   📦 Data loaded with cache-first strategy")
                }
                
                // Background preloading for better performance (only if we have data)
                if !force && !sectionAppIds.isEmpty {
                    // Schedule background refresh to keep cache warm
                    networkManager.scheduleBackgroundRefresh(baseURL: baseURL, delay: 60)
                    print("💼 HomeView: Scheduled background refresh in 60 seconds")
                }
            }
            
        } catch {
            print("❌ HomeView: Failed to load content (reason: \(reason)): \(error)")
            await MainActor.run {
                // Don't clear existing data on error, just stop loading
                if sections.isEmpty {
                    // Only set empty state if we have no data at all
                    self.sections = []
                    self.appsById = [:]
                    self.categories = []
                    self.featuredApps = []
                }
            }
        }
    }

}
// MARK: - Simple Card Components

private struct FeaturedSectionView: View {
    let title: String
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    let onSectionTap: (String, [IOSAppDTO]) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Clickable title
            Button(action: {
                // Navigate to show all featured apps
                onSectionTap(title, apps)
            }) {
                HStack {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(apps.prefix(5), id: \.id) { app in
                        FeaturedAppCard(app: app) {
                            onAppTap(app)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct CategoriesSectionView: View {
    let title: String
    let categories: [AppCategory]
    let onCategoryTap: (Int) -> Void
    let onSectionTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Clickable title
            Button(action: {
                // Navigate to show all categories
                onSectionTap(title)
            }) {
                HStack {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(categories, id: \.id) { category in
                        CategoryCard(category: category) {
                            print("📱 CategoriesSectionView: Category tapped, calling onCategoryTap with ID \(category.id)")
                            onCategoryTap(category.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .onAppear {
                    print("📱 CategoriesSectionView: Displayed \(categories.count) categories")
                    for category in categories {
                        print("   - \(category.displayName) (ID: \(category.id))")
                    }
                }
            }
        }
    }
}

private struct FeaturedAppCard: View {
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
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                ProgressView()
                            )
                    }
                }
                
                // App Info
                VStack(spacing: 4) {
                    Text(app.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Rating stars - reserved space for consistency
                    HStack(spacing: 1) {
                        if let rating = app.rating, rating > 0 {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        } else {
                            // Invisible spacer to maintain consistent height
                            HStack(spacing: 1) {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "star")
                                        .font(.caption2)
                                        .foregroundColor(.clear)
                                }
                            }
                        }
                    }
                }
                .frame(width: 120)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppStoreCategoryCard: View {
    let category: AppCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            print("💆 AppStoreCategoryCard: Tapped on category '\(category.displayName)' (ID: \(category.id))")
            action()
        }) {
            VStack(spacing: 12) {
                // Large Category Icon Background
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.blue.gradient)
                        .frame(width: 120, height: 120)
                    
                    Group {
                        if let icon = category.icon, !icon.isEmpty {
                            // Check if it's a URL or system icon name
                            if icon.hasPrefix("http") || icon.hasPrefix("https") {
                                LazyImage(url: URL(string: icon)) { state in
                                    if let image = state.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 60)
                                            .foregroundColor(.white)
                                    } else {
                                        // Loading or failed to load
                                        Image(systemName: "photo")
                                            .font(.system(size: 40, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                .onAppear {
                                    print("🖼️ AppStoreCategoryCard: Loading URL icon for '\(category.displayName)': \(icon)")
                                }
                            } else {
                                // System icon
                                Image(systemName: icon)
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                                    .onAppear {
                                        print("📱 AppStoreCategoryCard: Using system icon for '\(category.displayName)': \(icon)")
                                    }
                            }
                        } else {
                            // Default fallback icon
                            Image(systemName: "folder")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.white)
                                .onAppear {
                                    print("📁 AppStoreCategoryCard: Using fallback icon for '\(category.displayName)' (icon was: \(category.icon ?? "nil"))")
                                }
                        }
                    }
                }
                
                // Category Info with proper spacing to prevent clipping
                VStack(spacing: 6) {
                    Text(category.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                    
                    Text("Explore & Discover")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 120)
                .frame(minHeight: 50) // Ensure enough space for text
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: 220) // Fixed total height to prevent clipping
    }
}

private struct CategoryCard: View {
    let category: AppCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            print("💆 CategoryCard: Tapped on category '\(category.displayName)' (ID: \(category.id))")
            action()
        }) {
            VStack(spacing: 8) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.gradient)
                        .frame(width: 60, height: 60)
                    
                    Group {
                        if let icon = category.icon, !icon.isEmpty {
                            // Check if it's a URL or system icon name
                            if icon.hasPrefix("http") || icon.hasPrefix("https") {
                                LazyImage(url: URL(string: icon)) { state in
                                    if let image = state.image {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.white)
                                    } else {
                                        // Loading or failed to load
                                        Image(systemName: "photo")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                }
                                .onAppear {
                                    print("🖼️ CategoryCard: Loading URL icon for '\(category.displayName)': \(icon)")
                                }
                            } else {
                                // System icon
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .onAppear {
                                        print("📱 CategoryCard: Using system icon for '\(category.displayName)': \(icon)")
                                    }
                            }
                        } else {
                            // Default fallback icon
                            Image(systemName: "folder")
                                .font(.title2)
                                .foregroundColor(.white)
                                .onAppear {
                                    print("📁 CategoryCard: Using fallback icon for '\(category.displayName)' (icon was: \(category.icon ?? "nil"))")
                                }
                        }
                    }
                }
                
                // Category Name
                Text(category.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppSectionView: View {
    let section: HomepageSectionDTO
    let appsById: [String: IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    let onSectionTap: (String, [IOSAppDTO]) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Title - Clickable
            if let title = section.localizedTitle {
                Button(action: {
                    // Navigate to section apps list
                    let apps = section.appIds?.compactMap { id in
                        appsById[id] ?? appsById.values.first(where: { "\($0.id)" == id })
                    } ?? []
                    onSectionTap(title, apps)
                }) {
                    HStack {
                        Text(title)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            }
            
            // Apps List with different layouts based on section type
            if let appIds = section.appIds {
                let apps = appIds.compactMap { id in
                    appsById[id] ?? appsById.values.first(where: { "\($0.id)" == id })
                }
                
                if !apps.isEmpty {
                    switch section.type {
                    case "grid":
                        // Grid layout (3 columns)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                            ForEach(apps, id: \.id) { app in
                                AppGridCard(app: app) {
                                    onAppTap(app)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                    case "banner":
                        // Banner layout (large cards)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(apps, id: \.id) { app in
                                    AppBannerCard(app: app) {
                                        onAppTap(app)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                    case "hero":
                        // Hero layout - TabView with smooth paging like must-have cards
                        let heroAppsChunks = apps.chunked(into: 2) // Split hero apps into groups of 2 for better display
                        
                        // Calculate height separately to avoid type checker complexity
                        let heroHeight: CGFloat = {
                            guard heroAppsChunks.count > 0 else { return 200 }
                            let cardsPerPage = heroAppsChunks[0].count
                            let cardHeight = 160
                            let spacing = 16
                            let padding = 40
                            return CGFloat(cardsPerPage * cardHeight + (cardsPerPage - 1) * spacing + padding)
                        }()
                        
                        TabView {
                            ForEach(0..<heroAppsChunks.count, id: \.self) { chunkIndex in
                                VStack(spacing: 16) {
                                    ForEach(0..<heroAppsChunks[chunkIndex].count, id: \.self) { appIndex in
                                        let app = heroAppsChunks[chunkIndex][appIndex]
                                        AppHeroCard(app: app) {
                                            onAppTap(app)
                                        }
                                    }
                                    
                                    // Add spacer to fill remaining space if less than 2 apps
                                    if heroAppsChunks[chunkIndex].count < 2 {
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: heroHeight)
                        .overlay(
                            // Peek preview overlay - show next page preview on the right edge
                            HStack {
                                Spacer()
                                if heroAppsChunks.count > 1 {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.clear,
                                                Color(UIColor.systemBackground).opacity(0.3)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: 40)
                                }
                            },
                            alignment: .trailing
                        )
                        
                    case "mustHave":
                        // Must-Have Apps layout (App Store style) - Paginated groups of 3 with TabView
                        let appsChunks = apps.chunked(into: 3) // Split apps into groups of 3
                        
                        TabView {
                            ForEach(0..<appsChunks.count, id: \.self) { chunkIndex in
                                VStack(spacing: 0) {
                                    ForEach(0..<appsChunks[chunkIndex].count, id: \.self) { appIndex in
                                        let app = appsChunks[chunkIndex][appIndex]
                                        AppMustHaveCard(app: app) {
                                            onAppTap(app)
                                        }
                                        
                                        // Divider line between apps (except for last item in chunk)
                                        if appIndex < appsChunks[chunkIndex].count - 1 {
                                            Divider()
                                                .padding(.leading, 100) // Align with text content
                                        }
                                    }
                                    
                                    // Add spacer to fill remaining space if less than 3 apps
                                    if appsChunks[chunkIndex].count < 3 {
                                        Spacer()
                                    }
                                }
                                .padding(.top, 10)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 270) // Fixed height for 3 apps
                        .overlay(
                            // Peek preview overlay - show next page preview on the right edge
                            HStack {
                                Spacer()
                                if appsChunks.count > 1 {
                                    Rectangle()
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.clear,
                                                Color(UIColor.systemBackground).opacity(0.3)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: 40)
                                }
                            },
                            alignment: .trailing
                        )
                        
                    case "editorsChoice", "personalized", "trending", "newReleases":
                        // Default carousel layout for these section types
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(apps, id: \.id) { app in
                                    AppListCard(app: app) {
                                        onAppTap(app)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                    default:
                        // Default carousel layout (horizontal scroll)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(apps, id: \.id) { app in
                                    AppListCard(app: app) {
                                        onAppTap(app)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else {
                    // No apps configured
                    Text("No apps configured for this section")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
            }
        }
    }
}

private struct AppGridCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // App Icon
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
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                }
                
                // App Name
                Text(app.displayName)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    
                // Rating stars for grid cards - reserved space for consistency
                HStack(spacing: 1) {
                    if let rating = app.rating, rating > 0 {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    } else {
                        // Invisible spacer to maintain consistent height
                        ForEach(0..<5) { _ in
                            Image(systemName: "star")
                                .font(.caption2)
                                .foregroundColor(.clear)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppBannerCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    // Check if this app is currently being downloaded
    private var currentDownload: Download? {
        let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
        return downloadManager.downloads.first { $0.id == downloadId }
    }
    
    private var downloadButtonImage: String {
        guard let download = currentDownload else {
            return "arrow.down.circle.fill"
        }
        
        switch download.state {
        case .waiting:
            return "clock"
        case .downloading:
            return "pause.circle.fill"
        case .paused:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var downloadButtonColor: Color {
        guard let download = currentDownload else {
            return .blue
        }
        
        switch download.state {
        case .waiting:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Large App Icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .overlay(
                                ProgressView()
                            )
                    }
                }
                
                // App Info with Download Button
                VStack(spacing: 4) {
                    HStack {
                        Text(app.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Download Button
                        Button(action: {
                            handleDownloadButtonTap()
                        }) {
                            Image(systemName: downloadButtonImage)
                                .font(.title3)
                                .foregroundColor(downloadButtonColor)
                                .frame(width: 44, height: 44) // Larger touch target
                                .contentShape(Rectangle()) // Improve touch detection
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.clear) // Ensure touch area is active
                    }
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let description = app.displayShortDescription {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Rating stars for banner cards - reserved space for consistency
                    HStack(spacing: 1) {
                        if let rating = app.rating, rating > 0 {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        } else {
                            // Invisible spacer to maintain consistent height
                            ForEach(0..<5) { _ in
                                Image(systemName: "star")
                                    .font(.caption)
                                    .foregroundColor(.clear)
                            }
                        }
                        Spacer()
                    }
                }
                .frame(width: 140)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleDownloadButtonTap() {
        // Provide immediate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if let download = currentDownload {
            // Handle existing download states
            switch download.state {
            case .waiting:
                downloadManager.resumeDownload(download)
            case .downloading:
                downloadManager.pauseDownload(download)
            case .paused:
                downloadManager.resumeDownload(download)
            case .completed:
                return
            case .failed:
                downloadManager.resumeDownload(download)
            }
        } else {
            // Start new download
            if let ipaUrl = app.ipaUrl, let url = URL(string: ipaUrl) {
                let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
                let downloadResult = downloadManager.startDownload(from: url, id: downloadId)
                if downloadResult != nil {
                    // Success haptic feedback for new download
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    print("Download started successfully for: \(app.displayName)")
                } else {
                    // Error haptic feedback for blocked download
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    print("Download blocked: App already completed")
                }
            } else {
                // Error haptic feedback for missing URL
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                print("No IPA URL available for app: \(app.displayName)")
            }
        }
    }
}

private struct AppHeroCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    // Check if this app is currently being downloaded
    private var currentDownload: Download? {
        let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
        return downloadManager.downloads.first { $0.id == downloadId }
    }
    
    private var downloadButtonImage: String {
        guard let download = currentDownload else {
            return "arrow.down.circle.fill"
        }
        
        switch download.state {
        case .waiting:
            return "clock"
        case .downloading:
            return "pause.circle.fill"
        case .paused:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var downloadButtonColor: Color {
        guard let download = currentDownload else {
            return .blue
        }
        
        switch download.state {
        case .waiting:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // App Icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .overlay(
                                ProgressView()
                            )
                    }
                }
                
                // App Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(app.displayName)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        // Download Button
                        Button(action: {
                            handleDownloadButtonTap()
                        }) {
                            Image(systemName: downloadButtonImage)
                                .font(.title2)
                                .foregroundColor(downloadButtonColor)
                                .frame(width: 44, height: 44) // Larger touch target
                                .contentShape(Rectangle()) // Improve touch detection
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(Color.clear) // Ensure touch area is active
                    }
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let description = app.displayShortDescription {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    // Rating stars for hero cards - reserved space for consistency
                    HStack(spacing: 2) {
                        if let rating = app.rating, rating > 0 {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            // Invisible spacer to maintain consistent height
                            ForEach(0..<5) { _ in
                                Image(systemName: "star")
                                    .font(.caption)
                                    .foregroundColor(.clear)
                            }
                            Text("0.0")
                                .font(.caption)
                                .foregroundColor(.clear)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .frame(width: 320, height: 140) // Fixed width for horizontal scrolling
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.4), lineWidth: 4)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleDownloadButtonTap() {
        // Provide immediate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if let download = currentDownload {
            // Handle existing download states
            switch download.state {
            case .waiting:
                downloadManager.resumeDownload(download)
            case .downloading:
                downloadManager.pauseDownload(download)
            case .paused:
                downloadManager.resumeDownload(download)
            case .completed:
                return
            case .failed:
                downloadManager.resumeDownload(download)
            }
        } else {
            // Start new download
            if let ipaUrl = app.ipaUrl, let url = URL(string: ipaUrl) {
                let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
                let downloadResult = downloadManager.startDownload(from: url, id: downloadId)
                if downloadResult != nil {
                    // Success haptic feedback for new download
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    print("Download started successfully for: \(app.displayName)")
                } else {
                    // Error haptic feedback for blocked download
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    print("Download blocked: App already completed")
                }
            } else {
                // Error haptic feedback for missing URL
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                print("No IPA URL available for app: \(app.displayName)")
            }
        }
    }
}



private struct AppMustHaveCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    // Check if this app is currently being downloaded
    private var currentDownload: Download? {
        let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
        return downloadManager.downloads.first { $0.id == downloadId }
    }
    
    private var downloadButtonImage: String {
        guard let download = currentDownload else {
            return "arrow.down.circle.fill"
        }
        
        switch download.state {
        case .waiting:
            return "clock"
        case .downloading:
            return "pause.circle"
        case .paused:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var downloadButtonColor: Color {
        guard let download = currentDownload else {
            return .blue
        }
        
        switch download.state {
        case .waiting:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // App Icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 64, height: 64)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                }
                
                // App Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let description = app.displayShortDescription {
                        Text(description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Download Button with State
                VStack {
                    Button(action: {
                        handleDownloadButtonTap()
                    }) {
                        ZStack {
                            if let download = currentDownload, download.state == .downloading {
                                // Show progress circle for downloading state
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                
                                Circle()
                                    .trim(from: 0, to: download.progress)
                                    .stroke(downloadButtonColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .frame(width: 24, height: 24)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.2), value: download.progress)
                                
                                Image(systemName: downloadButtonImage)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(downloadButtonColor)
                            } else {
                                Image(systemName: downloadButtonImage)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(downloadButtonColor)
                            }
                        }
                        .frame(width: 44, height: 44) // Larger touch target
                        .contentShape(Rectangle()) // Improve touch detection
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.clear) // Ensure touch area is active
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(height: 80) // Fixed height for consistent layout
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleDownloadButtonTap() {
        // Provide immediate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if let download = currentDownload {
            // Handle existing download states
            switch download.state {
            case .waiting:
                // Start the download (move to front of queue if needed)
                downloadManager.resumeDownload(download)
            case .downloading:
                // Pause the download
                downloadManager.pauseDownload(download)
            case .paused:
                // Resume the download
                downloadManager.resumeDownload(download)
            case .completed:
                // Do nothing for completed downloads
                return
            case .failed:
                // Retry the download
                downloadManager.resumeDownload(download)
            }
        } else {
            // Start new download
            if let ipaUrl = app.ipaUrl, let url = URL(string: ipaUrl) {
                let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
                let downloadResult = downloadManager.startDownload(from: url, id: downloadId)
                if downloadResult != nil {
                    // Success haptic feedback for new download
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    print("Download started successfully for: \(app.displayName)")
                } else {
                    // Error haptic feedback for blocked download
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    print("Download blocked: App already completed")
                }
            } else {
                // Error haptic feedback for missing URL
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                print("No IPA URL available for app: \(app.displayName)")
            }
        }
    }
}

private struct AppListCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // App Icon
            Button(action: onTap) {
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
            }
            .buttonStyle(PlainButtonStyle())
            
            // App Info
            VStack(spacing: 4) {
                Text(app.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    
                // Rating stars for list cards - reserved space for consistency
                HStack(spacing: 1) {
                    if let rating = app.rating, rating > 0 {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    } else {
                        // Invisible spacer to maintain consistent height
                        ForEach(0..<5) { _ in
                            Image(systemName: "star")
                                .font(.caption2)
                                .foregroundColor(.clear)
                        }
                    }
                }
            }
            .frame(width: 100)
        }
    }
}


// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Section Apps View
private struct SectionAppsView: View {
    let title: String
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(apps, id: \.id) { app in
                        SectionAppRow(app: app, onTap: {
                            onAppTap(app)
                        })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

private struct SectionAppRow: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    // Check if this app is currently being downloaded
    private var currentDownload: Download? {
        let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
        return downloadManager.downloads.first { $0.id == downloadId }
    }
    
    private var downloadButtonImage: String {
        guard let download = currentDownload else {
            return "arrow.down.circle.fill"
        }
        
        switch download.state {
        case .waiting:
            return "clock"
        case .downloading:
            return "pause.circle.fill"
        case .paused:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var downloadButtonColor: Color {
        guard let download = currentDownload else {
            return .blue
        }
        
        switch download.state {
        case .waiting:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // App Icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 64, height: 64)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.7)
                            )
                    }
                }
                
                // App Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let description = app.displayShortDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Rating stars
                    HStack(spacing: 2) {
                        if let rating = app.rating, rating > 0 {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Download Button
                Button(action: {
                    handleDownloadButtonTap()
                }) {
                    Image(systemName: downloadButtonImage)
                        .font(.title2)
                        .foregroundColor(downloadButtonColor)
                        .frame(width: 44, height: 44) // Larger touch target
                        .contentShape(Rectangle()) // Improve touch detection
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.clear) // Ensure touch area is active
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleDownloadButtonTap() {
        // Provide immediate haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if let download = currentDownload {
            // Handle existing download states
            switch download.state {
            case .waiting:
                downloadManager.resumeDownload(download)
            case .downloading:
                downloadManager.pauseDownload(download)
            case .paused:
                downloadManager.resumeDownload(download)
            case .completed:
                return
            case .failed:
                downloadManager.resumeDownload(download)
            }
        } else {
            // Start new download
            if let ipaUrl = app.ipaUrl, let url = URL(string: ipaUrl) {
                let downloadId = "BabaApp_\(app.bundleIdentifier)_\(app.id)"
                let downloadResult = downloadManager.startDownload(from: url, id: downloadId)
                if downloadResult != nil {
                    // Success haptic feedback for new download
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)
                    print("Download started successfully for: \(app.displayName)")
                } else {
                    // Error haptic feedback for blocked download
                    let errorFeedback = UINotificationFeedbackGenerator()
                    errorFeedback.notificationOccurred(.error)
                    print("Download blocked: App already completed")
                }
            } else {
                // Error haptic feedback for missing URL
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                print("No IPA URL available for app: \(app.displayName)")
            }
        }
    }
}