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
    @State private var isLoading = true
    @State private var sections: [HomepageSectionDTO] = []
    @State private var appsById: [String: IOSAppDTO] = [:]
    @State private var categories: [AppCategory] = []
    @State private var featuredApps: [IOSAppDTO] = []
    @State private var selectedApp: IOSAppDTO?
    @State private var filteredApps: [IOSAppDTO] = []
    @State private var showingCategoryFilter = false
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if !sections.isEmpty || !featuredApps.isEmpty || !categories.isEmpty {
                    mainContentView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Apps")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadContent() }
            .refreshable { await loadContent(force: true) }
            .onChange(of: authManager.apiBaseURL) { _ in
                Task { await loadContent(force: true) }
            }
                    .sheet(item: $selectedApp) { app in
            AppDetailView(app: app)
        }
        .sheet(isPresented: $showingCategoryFilter) {
            CategoryAppsView(apps: filteredApps) { app in
                selectedApp = app
                showingCategoryFilter = false
            }
        }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(localizedString("Loading apps..."))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mainContentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Hero Featured Section
                if !featuredApps.isEmpty {
                    heroSection
                        .padding(.bottom, 32)
                }
                
                // Categories Section
                if !categories.isEmpty {
                    categoriesSection
                        .padding(.bottom, 32)
                }
                
                // Dynamic Sections from Backend
                ForEach(sections.sorted(by: { $0.order < $1.order }), id: \.id) { section in
                    if section.enabled {
                        AppStoreSectionView(section: section, appsById: appsById) { app in
                            selectedApp = app
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedString("Featured"))
                    .font(.title.bold())
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(featuredApps.prefix(5), id: \.id) { app in
                        HeroAppCard(app: app) {
                            selectedApp = app
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(localizedString("Categories"))
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.id) { category in
                        CategoryCard(category: category) {
                            // Navigate to category apps
                            loadCategoryApps(categoryId: category.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "app.badge")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(localizedString("No Apps Available"))
                    .font(.title2.bold())
                
                Text(localizedString("Please check your connection and try again"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(localizedString("Retry")) {
                Task { await loadContent(force: true) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        switch key {
        case "Featured":
            return lang == "fa" ? "منتخب‌ها" : "Featured"
        case "Categories":
            return lang == "fa" ? "دسته‌بندی‌ها" : "Categories"
        case "No Apps Available":
            return lang == "fa" ? "برنامه‌ای موجود نیست" : "No Apps Available"
        case "Please check your connection and try again":
            return lang == "fa" ? "لطفاً اتصال اینترنت خود را بررسی کرده و دوباره تلاش کنید" : "Please check your connection and try again"
        case "Retry":
            return lang == "fa" ? "تلاش مجدد" : "Retry"
        case "Loading apps...":
            return lang == "fa" ? "در حال بارگذاری برنامه‌ها..." : "Loading apps..."
        default:
            return key
        }
    }

    private func loadCategoryApps(categoryId: Int) {
        Task {
            do {
                let baseURL = authManager.apiBaseURL.absoluteString
                let url = URL(string: "\(baseURL)/api/v1/apps?categoryId=\(categoryId)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                struct AppsResponse: Decodable { let apps: [IOSAppDTO] }
                let response = try JSONDecoder().decode(AppsResponse.self, from: data)
                
                await MainActor.run {
                    // Show apps in a filtered view or navigate to apps list
                    self.filteredApps = response.apps
                    self.showingCategoryFilter = true
                }
            } catch {
                print("Failed to load category apps: \(error)")
            }
        }
    }
    
    private func loadContent(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load all content from BabaApp backend
            let baseURL = authManager.apiBaseURL.absoluteString
            async let homepageTask: IOSHomepageResponse = fetchJson("\(baseURL)/api/v1/pages/homepage-v2")
            async let categoriesTask: [AppCategory] = fetchJson("\(baseURL)/api/v1/categories")
            async let featuredTask: [IOSAppDTO] = fetchJson("\(baseURL)/api/v1/apps/featured")
            
            let (homepage, categoriesResponse, featuredResponse) = try await (homepageTask, categoriesTask, featuredTask)
            let layout = homepage.sections
            
            // Load all apps referenced in sections
            let appIds = Array(Set(layout.compactMap({ $0.appIds }).flatMap({ $0 })))
            var map: [String: IOSAppDTO] = [:]
            
            if !appIds.isEmpty {
                try await withThrowingTaskGroup(of: (String, IOSAppDTO).self) { group in
                    for id in appIds { 
                        group.addTask { 
                            (id, try await fetchJson("\(baseURL)/api/v1/apps/\(id)")) 
                        } 
                    }
                    for try await (id, app) in group { 
                        map[id] = app 
                    }
                }
            }
            
            await MainActor.run {
                self.sections = layout
                self.appsById = map
                self.categories = categoriesResponse
                self.featuredApps = featuredResponse
            }
            
        } catch {
            print("Failed to load content from backend: \(error)")
            await MainActor.run {
                self.sections = []
                self.appsById = [:]
                self.categories = []
                self.featuredApps = []
            }
        }
    }
}

// MARK: - App Store Section View

private struct AppStoreSectionView: View {
    let section: HomepageSectionDTO
    let appsById: [String: IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = section.localizedTitle {
                HStack {
                    Text(title)
                        .font(.title2.bold())
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            if let ids = section.appIds, !ids.isEmpty {
                let apps = ids.compactMap { id in
                    appsById[id] ?? appsById.values.first(where: { "\($0.id)" == id })
                }
                
                if section.type == "featured" || section.type == "hero" {
                    // Horizontal scrolling for featured apps
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(apps, id: \.id) { app in
                                AppStoreHeroCard(app: app) {
                                    onAppTap(app)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // Grid layout for regular sections
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(apps, id: \.id) { app in
                            AppStoreCard(app: app) {
                                onAppTap(app)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - App Store Style Cards

private struct HeroAppCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Large hero image/icon
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 300, height: 200)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 300, height: 200)
                            .overlay(
                                Image(systemName: "app.badge")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // App info overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let description = app.displayDescription {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.top, 8)
                .frame(width: 300, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct CategoryCard: View {
    let category: AppCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    if let icon = category.icon {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "app.badge")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(category.displayName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .frame(width: 80)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AppStoreCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Image(systemName: "app.badge")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Rating stars
                    if let rating = app.rating, rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    // GET button
                    Button(action: { downloadApp(app) }) {
                        Text(localizedString("GET"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return key == "GET" ? (lang == "fa" ? "دریافت" : "GET") : key
    }
    
    private func downloadApp(_ app: IOSAppDTO) {
        guard let urlString = app.downloadUrl, let url = URL(string: urlString) else { return }
        _ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(app.bundleIdentifier)_\(UUID().uuidString)")
    }
}

private struct CategoryAppsView: View {
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160), spacing: 16)
                ], spacing: 16) {
                    ForEach(apps, id: \.id) { app in
                        AppStoreCard(app: app) {
                            onAppTap(app)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("دسته‌بندی")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("بستن") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AppStoreHeroCard: View {
    let app: IOSAppDTO
    let onTap: () -> Void
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                LazyImage(url: URL(string: app.iconUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .overlay(
                                Image(systemName: "app.badge")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: 160, alignment: .leading)
                    
                    if let developer = app.developer {
                        Text(developer)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Badges and rating
                    HStack(spacing: 4) {
                        if app.isNew == true {
                            Text(localizedString("NEW"))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                        
                        if let rating = app.rating, rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // GET button
                    Button(action: { downloadApp(app) }) {
                        Text(localizedString("GET"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 32)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }
            }
            .frame(width: 180)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        switch key {
        case "GET":
            return lang == "fa" ? "دریافت" : "GET"
        case "NEW":
            return lang == "fa" ? "جدید" : "NEW"
        default:
            return key
        }
    }
    
    private func downloadApp(_ app: IOSAppDTO) {
        guard let urlString = app.downloadUrl, let url = URL(string: urlString) else { return }
        _ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(app.bundleIdentifier)_\(UUID().uuidString)")
    }
}

// MARK: - Fetch helper

@discardableResult
private func fetchJson<T: Decodable>(_ url: String) async throws -> T {
    let (data, response) = try await URLSession.shared.data(from: URL(string: url)!)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { 
        throw URLError(.badServerResponse) 
    }
    return try JSONDecoder().decode(T.self, from: data)
}