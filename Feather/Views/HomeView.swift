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
                                    FeaturedSectionView(title: section.localizedTitle ?? String(localized: "Featured"), apps: sectionApps) { app in
                                        selectedApp = app
                                    }
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
                                    categories: categoriesToShow
                                ) { categoryId in
                                    print("🏷️ HomeView: Category tap received for ID \(categoryId)")
                                    loadCategoryApps(categoryId: categoryId)
                                }
                            } else {
                                Text("No categories available")
                                    .padding()
                                    .foregroundColor(.secondary)
                                    .onAppear {
                                        print("⚠️ HomeView: No categories to display - total categories: \(categories.count)")
                                    }
                            }
                            
                        case "editorsChoice", "personalized", "trending", "newReleases", "banner", "carousel", "grid", "hero":
                            // Regular app sections with configured apps
                            AppSectionView(section: section, appsById: appsById) { app in
                                selectedApp = app
                            }
                            
                        default:
                            // Handle any other section types as regular app sections
                            AppSectionView(section: section, appsById: appsById) { app in
                                selectedApp = app
                            }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Spacer()
            }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Spacer()
            }
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
                }
                .frame(width: 120)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Title
            if let title = section.localizedTitle {
                HStack {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    Spacer()
                }
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
                        // Hero layout (multiple large featured apps with horizontal scroll)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(apps, id: \.id) { app in
                                    AppHeroCard(app: app) {
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
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppBannerCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    
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
                    
                    if let description = app.displayShortDescription {
                        Text(description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(width: 140)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppHeroCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    
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
                    Text(app.displayName)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
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
                    
                    Spacer()
                    
                    // Get button
                    Text(String(localized: "GET"))
                        .font(.footnote.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .frame(width: 320, height: 140) // Fixed width for horizontal scrolling
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppListCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
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
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // GET Button
                Button(action: { downloadApp(app) }) {
                    Text(String(localized: "GET"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                        .frame(width: 60, height: 24)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 100)
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private func downloadApp(_ app: IOSAppDTO) {
        guard let urlString = app.downloadUrl, !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return
        }
        
        let downloadId = "FeatherManualDownload_\(app.bundleIdentifier)_\(UUID().uuidString)"
        _ = downloadManager.startDownload(from: url, id: downloadId)
    }
}


// MARK: - Fetch helper removed - now using NetworkManager