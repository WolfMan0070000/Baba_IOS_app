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
    @ObservedObject private var authManager = AuthManager.shared
    @AppStorage("Feather.apiBaseURL") private var apiBaseURL: String = "http://localhost:4000"
    @AppStorage("Feather.cypwnFeedURL") private var cypwnFeedURL: String = "https://ipa.cypwn.xyz/cypwn.json"
    @State private var cypwnApps: [CypwnApp] = []

    var body: some View {
        NBNavigationView(.localized("Home")) {
            Group {
                if isLoading {
                    ProgressView("Loading apps...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !sections.isEmpty {
                    // Render backend layout with App Store style
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(sections.sorted(by: { $0.order < $1.order }), id: \.id) { section in
                                if section.enabled {
                                    AppStoreSectionView(section: section, appsById: appsById)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                } else if !cypwnApps.isEmpty {
                    // Fallback to Cypwn feed with App Store style
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            // Hero section for featured apps
                            if !cypwnApps.filter({ $0.isFeatured }).isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(localizedString("Featured"))
                                            .font(.title2.bold())
                                        Spacer()
                                    }
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(cypwnApps.filter { $0.isFeatured }) { app in
                                                CypwnHeroCard(app: app)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            
                            // All apps section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(localizedString("All Apps"))
                                        .font(.title2.bold())
                                    Spacer()
                                }
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ], spacing: 16) {
                                    ForEach(cypwnApps) { app in
                                        CypwnAppCard(app: app)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "app.badge")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Apps Available")
                            .font(.title2.bold())
                        
                        Text("Check your connection and try again")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            Task { await load(force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task { await load() }
            .refreshable { await load(force: true) }
        }
    }
    
    private func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        switch key {
        case "Featured":
            return lang == "fa" ? "منتخب‌ها" : "Featured"
        case "All Apps":
            return lang == "fa" ? "همه برنامه‌ها" : "All Apps"
        default:
            return key
        }
    }

    private func load(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        // First try backend layout (prioritize BabaApp website data)
        do {
            let page: PageResponse = try await fetchJson("\(apiBaseURL)/api/v1/pages/homepage-layout")
            let layout = page.blocks
            let appIds = Array(Set(layout.compactMap({ $0.appIds }).flatMap({ $0 })))
            var map: [String: IOSAppDTO] = [:]
            try await withThrowingTaskGroup(of: (String, IOSAppDTO).self) { group in
                for id in appIds { group.addTask { (id, try await fetchJson("\(apiBaseURL)/api/v1/apps/\(id)")) } }
                for try await (id, app) in group { map[id] = app }
            }
            await MainActor.run {
                self.sections = layout
                self.appsById = map
                self.cypwnApps = []
            }
            return
        } catch {
            // Fallback to Cypwn feed if backend fails
            print("Backend failed, trying Cypwn feed: \(error)")
        }
        
        do {
            if let url = URL(string: cypwnFeedURL) {
                let feed = try await CypwnFeedService.fetch(from: url)
                if !feed.isEmpty {
                    await MainActor.run {
                        self.cypwnApps = feed
                        self.sections = []
                        self.appsById = [:]
                    }
                    return
                }
            }
        } catch {
            print("Cypwn feed also failed: \(error)")
        }
        
        // Both failed - clear data
        await MainActor.run { 
            self.sections = []
            self.appsById = [:]
            self.cypwnApps = []
        }
    }
}

private struct AppStoreSectionView: View {
    let section: HomepageSectionDTO
    let appsById: [String: IOSAppDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = section.localizedTitle {
                HStack {
                    Text(title)
                        .font(.title2.bold())
                    Spacer()
                }
            }
            
            if let ids = section.appIds, !ids.isEmpty {
                let apps = ids.compactMap { id in
                    appsById[id] ?? appsById.values.first(where: { $0.bundleIdentifier == id })
                }
                
                if section.type == "featured" || section.type == "hero" {
                    // Horizontal scrolling for featured apps
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(apps, id: \.id) { app in
                                AppStoreHeroCard(app: app)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    // Grid layout for regular sections
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(apps, id: \.id) { app in
                            AppStoreCard(app: app)
                        }
                    }
                }
            }
        }
    }
}

private struct AppStoreCard: View {
    let app: IOSAppDTO
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
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
                    .lineLimit(1)
                
                if let developer = app.developer {
                    Text(developer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Button(action: onDownload) {
                    Text(.localized("GET"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func onDownload() {
        // TODO: Implement download from backend
        print("Download app: \(app.displayName)")
    }
}

private struct AppStoreHeroCard: View {
    let app: IOSAppDTO
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
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
                    .lineLimit(2)
                    .frame(maxWidth: 160, alignment: .leading)
                
                if let developer = app.developer {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Button(action: onDownload) {
                    Text(.localized("GET"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 32)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(width: 180)
    }
    
    private func onDownload() {
        // TODO: Implement download from backend
        print("Download app: \(app.displayName)")
    }
}

// MARK: - Cypwn UI
private struct CypwnAppCard: View {
    let app: CypwnApp
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyImage(url: URL(string: app.iconUrl ?? "")) { state in
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
                Text(displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                
                if let developer = app.developer {
                    Text(developer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Button(action: onDownload) {
                        Text(.localized("GET"))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if let size = app.size, !size.isEmpty {
                        Text(size)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var displayName: String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? (app.nameFa ?? app.name) : app.name
    }

    private func onDownload() {
        guard let url = URL(string: app.downloadUrl) else { return }
        _ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(app.bundleIdentifier)_\(UUID().uuidString)")
    }
}

private struct CypwnHeroCard: View {
    let app: CypwnApp
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyImage(url: URL(string: app.iconUrl ?? "")) { state in
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
                Text(displayName)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: 160, alignment: .leading)
                
                if let developer = app.developer {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Button(action: onDownload) {
                    Text(.localized("GET"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 32)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(width: 180)
    }

    private var displayName: String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? (app.nameFa ?? app.name) : app.name
    }

    private func onDownload() {
        guard let url = URL(string: app.downloadUrl) else { return }
        _ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(app.bundleIdentifier)_\(UUID().uuidString)")
    }
}

// MARK: - DTOs and fetch helper

private struct HomepageSectionDTO: Decodable {
    let id: String
    let type: String
    let title_fa: String?
    let title_en: String?
    let appIds: [String]?
    let enabled: Bool
    let order: Int

    var localizedTitle: String? {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? (title_fa ?? title_en) : (title_en ?? title_fa)
    }
}

private struct IOSAppDTO: Decodable {
    let id: Int
    let bundleIdentifier: String
    let name: String
    let nameFa: String
    let developer: String?
    let iconUrl: String

    var displayName: String { (UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa") == "fa" ? nameFa : name }
}

private struct PageResponse: Decodable {
    let blocks: [HomepageSectionDTO]
}

@discardableResult
private func fetchJson<T: Decodable>(_ url: String) async throws -> T {
    let (data, response) = try await URLSession.shared.data(from: URL(string: url)!)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    return try JSONDecoder().decode(T.self, from: data)
}


