//
//  HomeView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//  Last Updated: 06.09.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - Section Apps Data Model
struct SectionAppsData: Identifiable {
    let id = UUID()
    let title: String
    let apps: [IOSAppDTO]
}

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
    @State private var selectedSectionForNavigation: SectionAppsData? = nil
    @State private var hasInitialLoad = false  // Track if we've loaded data at least once
    @State private var errorMessage: String? = nil // For error handling
    @State private var showingErrorAlert = false
    
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
                
                // Hidden NavigationLink for section apps navigation
                NavigationLink(
                    destination: Group {
                        if let sectionData = selectedSectionForNavigation {
                            SectionAppsView(
                                title: sectionData.title,
                                apps: sectionData.apps,
                                onAppTap: { app in
                                    selectedApp = app
                                }
                            )
                            .onAppear {
                                print("📱 SectionAppsView: Appeared for section '\(sectionData.title)' with \(sectionData.apps.count) apps")
                            }
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: Binding<Bool>(
                        get: { 
                            let isActive = selectedSectionForNavigation != nil
                            if isActive {
                                print("➡️ NavigationLink: Becoming active for section '\(selectedSectionForNavigation?.title ?? "unknown")'")
                            }
                            return isActive
                        },
                        set: { newValue in
                            print("⬅️ NavigationLink: Set active to \(newValue) (was: \(selectedSectionForNavigation != nil))")
                            if !newValue { 
                                selectedSectionForNavigation = nil 
                                print("📱 NavigationLink: Cleared selectedSectionForNavigation")
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
            .overlay(
                // Show refresh indicator when manually refreshing
                Group {
                    if isLoading && hasInitialLoad {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                                Text(String(localized: "Refreshing..."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            )
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
                } else if !sections.isEmpty {
                    // We have data already - just log for debugging
                    print("📊 HomeView: Already have \(sections.count) sections loaded")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Home screen with app sections")
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
        .alert("Error", isPresented: $showingErrorAlert, presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
            Button("Retry") {
                Task { await loadContent(force: true, reason: "error_retry") }
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            Text(String(localized: "Loading apps..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel(String(localized: "Loading apps"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .accessibilityElement(children: .combine)
    }
    
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Process only the configured sections from admin panel
                let enabledSections = sections.filter { $0.enabled }
                let sortedSections = enabledSections.sorted { $0.order < $1.order }
                
                ForEach(sortedSections, id: \.id) { section in
                    Group {
                        switch section.type {
                        case "featured":
                            featuredSectionContent(section: section)
                            
                        case "categories":
                            categoriesSectionContent(section: section)
                            
                        case "appStoreCategories":
                            appStoreCategoriesSectionContent(section: section)
                            
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
                    .id(section.id) // Add ID for better SwiftUI diffing
                }
                
                // Bottom spacing
                Spacer(minLength: 100)
            }
            .padding(.top, 20)
        }
        .scrollIndicators(.hidden) // Cleaner UI
        .refreshable {
            await loadContent(force: true, reason: "pull_to_refresh")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text(String(localized: "No Apps Available"))
                    .font(.title2.bold())
                    .accessibilityLabel(String(localized: "No apps available"))
                
                Text(String(localized: "Please check your connection and try again"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(String(localized: "Please check your connection and try again"))
            }
            
            Button(String(localized: "Retry")) {
                Task { await loadContent(force: true, reason: "user_retry") }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(String(localized: "Retry loading apps"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Empty state with no apps available"))
    }
    
    // MARK: - Data Loading
    
    private func showSectionApps(title: String, apps: [IOSAppDTO]) {
        selectedSectionForNavigation = SectionAppsData(title: title, apps: apps)
        print("📱 HomeView: Navigating to section apps for '\(title)' with \(apps.count) apps")
    }
    
    private func loadCategoryApps(categoryId: Int) {
        print("📱 HomeView: loadCategoryApps called with categoryId: \(categoryId)")
        
        // Prevent duplicate loading
        guard !isLoadingCategoryApps else {
            print("⚠️ HomeView: Already loading category apps, skipping")
            return
        }
        
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
                print("❌ HomeView: Failed to load category apps: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingCategoryApps = false
                    self.errorMessage = "Failed to load category apps: \(error.localizedDescription)"
                    self.showingErrorAlert = true
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
            
            // Load apps in parallel for better performance
            await withTaskGroup(of: (String, IOSAppDTO?).self) { group in
                for id in sectionAppIds {
                    group.addTask {
                        do {
                            let app = try await self.networkManager.fetchApp(
                                id: id,
                                baseURL: baseURL,
                                forceRefresh: force
                            )
                            return (id, app)
                        } catch {
                            print("❌ HomeView: Failed to load app \(id): \(error.localizedDescription)")
                            return (id, nil)
                        }
                    }
                }
                
                for await (id, app) in group {
                    if let app = app {
                        map[id] = app
                    }
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
            
            // Load categories only if there's a "categories" or "appStoreCategories" section configured
            var categoriesResponseFiltered: [AppCategory] = []
            let hasCategoriesSection = enabledSections.contains { $0.type == "categories" || $0.type == "appStoreCategories" }
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
                    
                    // Preload critical data for smooth UX
                    Task.detached(priority: .background) {
                        await self.preloadCriticalData()
                    }
                }
            }
            
        } catch {
            print("❌ HomeView: Failed to load content (reason: \(reason)): \(error.localizedDescription)")
            await MainActor.run {
                // Don't clear existing data on error, just stop loading
                if sections.isEmpty {
                    // Only set empty state if we have no data at all
                    self.sections = []
                    self.appsById = [:]
                    self.categories = []
                    self.featuredApps = []
                    
                    // Show error message for critical failures
                    if reason == "initial_app_launch" || reason == "user_retry" {
                        self.errorMessage = "Failed to load app data: \(error.localizedDescription)"
                        self.showingErrorAlert = true
                    }
                } else {
                    // For refresh actions, show a temporary error message
                    if reason == "pull_to_refresh" || reason == "user_retry" {
                        self.errorMessage = "Failed to refresh data: \(error.localizedDescription)"
                        self.showingErrorAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Performance Optimization
    
    private func preloadCriticalData() async {
        // Preload the most important data in background
        guard !sections.isEmpty else { return }
        
        let baseURL = authManager.apiBaseURL.absoluteString
        
        // Preload first few apps from each section for smooth scrolling
        for section in sections.filter({ $0.enabled }).prefix(3) {
            if let appIds = section.appIds?.prefix(3) {
                await withTaskGroup(of: Void.self) { group in
                    for appId in appIds {
                        group.addTask {
                            do {
                                _ = try await self.networkManager.fetchApp(
                                    id: appId,
                                    baseURL: baseURL,
                                    forceRefresh: false
                                )
                            } catch {
                                // Silently fail for preloading
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Section Content Builders
    
    @ViewBuilder
    private func featuredSectionContent(section: HomepageSectionDTO) -> some View {
        // Featured section with apps from admin panel
        if let appIds = section.appIds, !appIds.isEmpty {
            let sectionApps = appIds.compactMap { id in
                appsById[id] ?? appsById.values.first(where: { "\($0.id)" == id })
            }
            if !sectionApps.isEmpty {
                let title = section.localizedTitle ?? String(localized: "Featured")
                FeaturedSectionView(
                    title: title,
                    apps: sectionApps,
                    onAppTap: { app in
                        selectedApp = app
                    },
                    onSectionTap: showSectionApps
                )
            }
        }
    }
    
    @ViewBuilder
    private func categoriesSectionContent(section: HomepageSectionDTO) -> some View {
        // Categories section - show selected categories from admin panel
        let categoriesToShow: [AppCategory] = {
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
            let title = section.localizedTitle ?? String(localized: "Categories")
            CategoriesSectionView(
                title: title,
                categories: categoriesToShow,
                onCategoryTap: { categoryId in
                    print("🏷️ HomeView: Category tap received for ID \(categoryId)")
                    loadCategoryApps(categoryId: categoryId)
                },
                onSectionTap: { title in
                    print("🏷️ HomeView: Categories section tapped: \(title)")
                    showSectionApps(title: title, apps: [])
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
    }
    
    @ViewBuilder
    private func appStoreCategoriesSectionContent(section: HomepageSectionDTO) -> some View {
        // App Store-style categories section
        let categoriesToShow: [AppCategory] = {
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
                        print("🔗 App Store Categories section tapped: \(title)")
                        showSectionApps(title: title, apps: [])
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
                        let limitedCategories = Array(categoriesToShow.prefix(10))
                        ForEach(limitedCategories, id: \.id) { category in
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
                    ForEach(Array(apps.prefix(5)), id: \.id) { app in
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
                        for category in categories.prefix(5) {
                            print("   - \(category.displayName) (ID: \(category.id))")
                        }
                        if categories.count > 5 {
                            print("   ... and \(categories.count - 5) more categories")
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
                // App Icon with loading states
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .accessibility(label: Text("\(app.displayName) app icon"))
                    } else if state.error != nil {
                        // Error state
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            )
                            .accessibility(label: Text("Failed to load \(app.displayName) app icon"))
                    } else {
                        // Loading state
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                ProgressView()
                            )
                            .accessibility(label: Text("Loading \(app.displayName) app icon"))
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
                            .accessibility(label: Text("Developer: \(developer)"))
                    }
                    
                    // Rating stars - reserved space for consistency
                    HStack(spacing: 1) {
                        if let rating = app.rating, rating > 0 {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                            .accessibility(label: Text("Rating: \(rating, specifier: "%.1f") out of 5 stars"))
                        } else {
                            // Invisible spacer to maintain consistent height
                            HStack(spacing: 1) {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "star")
                                        .font(.caption2)
                                        .foregroundColor(.clear)
                                }
                            }
                            .accessibility(hidden: true)
                        }
                    }
                }
                .frame(width: 120)
            }
        }
        .onTapGesture {
            onTap()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppStoreCategoryCard: View {
    let category: AppCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            print("🏷️ AppStoreCategoryCard: Tapped on category '\(category.displayName)' (ID: \(category.id))")
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
            print("🏷️ CategoryCard: Tapped on category '\(category.displayName)' (ID: \(category.id))")
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
        .onTapGesture {
            action()
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
                        
                        // Auto-swap indicator
                        if section.autoScroll == true {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int((section.scrollInterval ?? 7000) / 1000))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            }
            
            // Apps List with auto-swap capability
            if let appIds = section.appIds {
                let apps = appIds.compactMap { id in
                    appsById[id] ?? appsById.values.first(where: { "\($0.id)" == id })
                }
                
                if !apps.isEmpty {
                    // Use AutoSwapSectionContent for sections with auto-swap enabled
                    if section.autoScroll == true {
                        AutoSwapSectionContent(
                            section: section,
                            apps: apps,
                            onAppTap: onAppTap
                        )
                    } else {
                        // Use regular static content
                        StaticSectionContent(
                            section: section,
                            apps: apps,
                            onAppTap: onAppTap
                        )
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

// MARK: - Auto-Swap Section Content
private struct AutoSwapSectionContent: View {
    let section: HomepageSectionDTO
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    
    @State private var currentPage = 0
    @State private var timer: Timer?
    @State private var isUserInteracting = false
    @State private var interactionTimer: Timer?
    
    // Calculate how many apps to show per page based on section type
    private var appsPerPage: Int {
        switch section.type {
        case "grid":
            return 6 // 2 rows of 3 apps
        case "banner":
            return 3 // 3 large banner cards
        case "hero":
            return 2 // 2 hero cards
        case "mustHave":
            return 3 // 3 must-have cards
        default:
            return 5 // Default for carousel and others
        }
    }
    
    // Split apps into pages
    private var appPages: [[IOSAppDTO]] {
        let chunks = Array(apps).chunkedInto(appsPerPage)
        return chunks.isEmpty ? [[]] : chunks
    }
    
    private var currentApps: [IOSAppDTO] {
        guard !appPages.isEmpty, currentPage < appPages.count else { return [] }
        return appPages[currentPage]
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Use the same approach as StaticSectionContent but with manual page control
            switch section.type {
            case "mustHave":
                // Must-Have Apps layout (App Store style) - Paginated groups of 3
                let appsChunks = Array(apps).chunkedInto(3) // Split apps into groups of 3
                
                if !appsChunks.isEmpty {
                    TabView(selection: $currentPage) {
                        ForEach(0..<appsChunks.count, id: \.self) { chunkIndex in
                            VStack(spacing: 0) {
                                ForEach(0..<appsChunks[chunkIndex].count, id: \.self) { appIndex in
                                    let app = appsChunks[chunkIndex][appIndex]
                                    AppMustHaveCard(app: app) {
                                        // Only trigger tap if not dragging
                                        if !isUserInteracting {
                                            onAppTap(app)
                                        }
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
                            .tag(chunkIndex)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 270) // Fixed height for 3 apps
                    .onTapGesture {
                        // Reset auto-scroll timer on any tap
                        resetAutoScrollTimer()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { _ in
                                pauseAutoScroll()
                            }
                            .onEnded { _ in
                                resumeAutoScroll()
                            }
                    )
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
                }
                
            case "grid":
                // Grid layout with auto-swap functionality
                // Using the same LazyVGrid approach as StaticSectionContent but with pagination
                let appsChunks = Array(apps).chunkedInto(6) // 2 rows of 3 apps per page
                
                if !appsChunks.isEmpty {
                    TabView(selection: $currentPage) {
                        ForEach(0..<appsChunks.count, id: \.self) { chunkIndex in
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                                ForEach(appsChunks[chunkIndex], id: \.id) { app in
                                    AppGridCard(app: app) {
                                        // Only trigger tap if not dragging
                                        if !isUserInteracting {
                                            onAppTap(app)
                                        }
                                    }
                                }
                                
                                // Add spacer to fill remaining space if less than 6 apps
                                if appsChunks[chunkIndex].count < 6 {
                                    ForEach(0..<(6 - appsChunks[chunkIndex].count)) { _ in
                                        Color.clear.frame(height: 100)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .tag(chunkIndex)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 250) // Fixed height for 2 rows of grid cards
                    .onTapGesture {
                        // Reset auto-scroll timer on any tap
                        resetAutoScrollTimer()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { _ in
                                pauseAutoScroll()
                            }
                            .onEnded { _ in
                                resumeAutoScroll()
                            }
                    )
                }
                
            case "banner":
                // Banner layout with auto-swap functionality
                // Using the same ScrollView approach as StaticSectionContent but with pagination
                let appsChunks = Array(apps).chunkedInto(3) // 3 banner cards per page
                
                if !appsChunks.isEmpty {
                    TabView(selection: $currentPage) {
                        ForEach(0..<appsChunks.count, id: \.self) { chunkIndex in
                            HStack(spacing: 16) {
                                ForEach(Array(appsChunks[chunkIndex].enumerated()), id: \.element.id) { _, app in
                                    AppBannerCard(app: app) {
                                        // Only trigger tap if not dragging
                                        if !isUserInteracting {
                                            onAppTap(app)
                                        }
                                    }
                                }
                                
                                // Fill empty spaces if less than 3 apps
                                if appsChunks[chunkIndex].count < 3 {
                                    ForEach(0..<(3 - appsChunks[chunkIndex].count)) { _ in
                                        Color.clear.frame(height: 140)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .tag(chunkIndex)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 140) // Fixed height for banner cards
                    .onTapGesture {
                        // Reset auto-scroll timer on any tap
                        resetAutoScrollTimer()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { _ in
                                pauseAutoScroll()
                            }
                            .onEnded { _ in
                                resumeAutoScroll()
                            }
                    )
                }
                
            case "hero":
                // Hero layout with auto-swap functionality
                // Using the same TabView approach as StaticSectionContent but with pagination
                let appsChunks = Array(apps).chunkedInto(2) // 2 hero cards per page
                
                // Calculate height separately to avoid type checker complexity
                let heroHeight: CGFloat = {
                    guard !appsChunks.isEmpty, !appsChunks[0].isEmpty else { return 200 }
                    let cardsPerPage = appsChunks[0].count
                    let cardHeight = 160
                    let spacing = 16
                    let padding = 40
                    return CGFloat(cardsPerPage * cardHeight + (cardsPerPage - 1) * spacing + padding)
                }()
                
                if !appsChunks.isEmpty {
                    TabView(selection: $currentPage) {
                        ForEach(0..<appsChunks.count, id: \.self) { chunkIndex in
                            VStack(spacing: 16) {
                                ForEach(Array(appsChunks[chunkIndex].enumerated()), id: \.element.id) { _, app in
                                    AppHeroCard(app: app) {
                                        // Only trigger tap if not dragging
                                        if !isUserInteracting {
                                            onAppTap(app)
                                        }
                                    }
                                }
                                
                                // Add spacer to fill remaining space if less than 2 apps
                                if appsChunks[chunkIndex].count < 2 {
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 20)
                            .tag(chunkIndex)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: heroHeight)
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
                    .onTapGesture {
                        // Reset auto-scroll timer on any tap
                        resetAutoScrollTimer()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { _ in
                                pauseAutoScroll()
                            }
                            .onEnded { _ in
                                resumeAutoScroll()
                            }
                    )
                }
                
            default:
                // For other types (editorsChoice, personalized, trending, newReleases, and default carousel), 
                // use horizontal scrolling approach with AppListCard
                let appsChunks = Array(apps).chunkedInto(5) // 5 list cards per page
                
                if !appsChunks.isEmpty {
                    TabView(selection: $currentPage) {
                        ForEach(0..<appsChunks.count, id: \.self) { chunkIndex in
                            HStack(spacing: 16) {
                                ForEach(Array(appsChunks[chunkIndex].enumerated()), id: \.element.id) { _, app in
                                    AppListCard(app: app) {
                                        // Only trigger tap if not dragging
                                        if !isUserInteracting {
                                            onAppTap(app)
                                        }
                                    }
                                }
                                
                                // Fill empty spaces if less than 5 apps
                                if appsChunks[chunkIndex].count < 5 {
                                    ForEach(0..<(5 - appsChunks[chunkIndex].count)) { _ in
                                        Color.clear.frame(width: 80, height: 100)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .tag(chunkIndex)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 100) // Fixed height for list cards
                    .onTapGesture {
                        // Reset auto-scroll timer on any tap
                        resetAutoScrollTimer()
                    }
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onChanged { _ in
                                pauseAutoScroll()
                            }
                            .onEnded { _ in
                                resumeAutoScroll()
                            }
                    )
                }
            }
            
            // Page indicator for auto-swap sections with multiple pages (only for TabView-based sections)
            if appPages.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<appPages.count, id: \.self) { index in
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                currentPage = index
                                // Reset auto-scroll timer when user interacts with page indicator
                                resetAutoScrollTimer()
                            }
                        }) {
                            Circle()
                                .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            startAutoSwap()
        }
        .onDisappear {
            stopAutoSwap()
        }
        .onChange(of: section.id) { _ in
            // Restart timer if section changes
            stopAutoSwap()
            currentPage = 0
            startAutoSwap()
        }
    }
    
    private func startAutoSwap() {
        guard appPages.count > 1,
              let interval = section.scrollInterval,
              interval > 0 else { return }
        
        let timeInterval = TimeInterval(interval) / 1000.0 // Convert milliseconds to seconds
        
        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
            // Only auto-scroll if user is not interacting
            if !isUserInteracting {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentPage = (currentPage + 1) % max(1, appPages.count)
                    }
                }
            }
        }
    }
    
    private func stopAutoSwap() {
        timer?.invalidate()
        timer = nil
        interactionTimer?.invalidate()
        interactionTimer = nil
    }
    
    // Pause auto-scroll when user interacts
    private func pauseAutoScroll() {
        isUserInteracting = true
    }
    
    // Resume auto-scroll after a delay when user stops interacting
    private func resumeAutoScroll() {
        // Reset the interaction timer
        interactionTimer?.invalidate()
        interactionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            DispatchQueue.main.async {
                self.isUserInteracting = false
            }
        }
    }
    
    // Reset auto-scroll timer
    private func resetAutoScrollTimer() {
        stopAutoSwap()
        startAutoSwap()
    }
}
// Add extension for notification names
extension Notification.Name {
    static let userInteractionStarted = Notification.Name("UserInteractionStarted")
    static let userInteractionEnded = Notification.Name("UserInteractionEnded")
}

// MARK: - Static Section Content (No Auto-Swap)
private struct StaticSectionContent: View {
    let section: HomepageSectionDTO
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    
    var body: some View {
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
            let heroAppsChunks = Array(apps).chunkedInto(2) // Split hero apps into groups of 2 for better display
            
            // Calculate height separately to avoid type checker complexity
            let heroHeight: CGFloat = {
                guard !heroAppsChunks.isEmpty, !heroAppsChunks[0].isEmpty else { return 200 }
                let cardsPerPage = heroAppsChunks[0].count
                let cardHeight = 160
                let spacing = 16
                let padding = 40
                return CGFloat(cardsPerPage * cardHeight + (cardsPerPage - 1) * spacing + padding)
            }()
            
            if !heroAppsChunks.isEmpty {
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
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
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
            }
            
        case "mustHave":
            // Must-Have Apps layout (App Store style) - Paginated groups of 3 with TabView
            let appsChunks = Array(apps).chunkedInto(3) // Split apps into groups of 3
            
            if !appsChunks.isEmpty {
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
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
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
            }
            
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
        
        // No apps configured
        if apps.isEmpty {
            Text("No apps configured for this section")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
        }
    }
}