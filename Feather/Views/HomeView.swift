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
    @AppStorage("Feather.apiBaseURL") private var apiBaseURL: String = "http://localhost:4000"
    @AppStorage("Feather.cypwnFeedURL") private var cypwnFeedURL: String = "https://ipa.cypwn.xyz/cypwn.json"
    @State private var cypwnApps: [CypwnApp] = []

    var body: some View {
        NBNavigationView(.localized("Home")) {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !cypwnApps.isEmpty {
                    // Render Cypwn feed
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage"), lang == "fa" {
                                Text("منتخب‌ها").font(.headline)
                            } else {
                                Text("Featured").font(.headline)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(cypwnApps.filter { $0.isFeatured }) { app in
                                        CypwnFeaturedCard(app: app)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            if let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage"), lang == "fa" {
                                Text("همه برنامه‌ها").font(.headline)
                            } else {
                                Text("All Apps").font(.headline)
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                                ForEach(cypwnApps) { app in
                                    CypwnAppCard(app: app)
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sections.sorted(by: { $0.order < $1.order }), id: \.id) { section in
                                if section.enabled {
                                    SectionView(section: section, appsById: appsById)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .task { await load() }
            .refreshable { await load(force: true) }
        }
    }

    private func load(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // First try Cypwn feed
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
            // ignore and fallback to backend layout
        }
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
                self.cypwnApps = []
                self.sections = layout
                self.appsById = map
            }
        } catch {
            await MainActor.run { self.sections = []; self.appsById = [:]; self.cypwnApps = [] }
        }
    }
}

private struct SectionView: View {
    let section: HomepageSectionDTO
    let appsById: [String: IOSAppDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.localizedTitle {
                Text(title).font(.headline)
            }
            if let ids = section.appIds, !ids.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(ids, id: \.self) { id in
                        if let app = appsById[id] ?? appsById.values.first(where: { $0.bundleIdentifier == id }) {
                            AppCard(app: app)
                        }
                    }
                }
            }
        }
    }
}

private struct AppCard: View {
    let app: IOSAppDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyImage(url: URL(string: app.iconUrl)) { state in
                if let image = state.image { image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Color.gray.opacity(0.1)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            Text(app.displayName)
                .font(.subheadline)
                .lineLimit(1)
            Text(app.developer ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Cypwn UI
private struct CypwnAppCard: View {
    let app: CypwnApp
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyImage(url: URL(string: app.iconUrl ?? "")) { state in
                if let image = state.image { image
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    Color.gray.opacity(0.1)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            Text(displayName)
                .font(.subheadline)
                .lineLimit(1)
            Text(app.developer ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            HStack {
                Button(action: onDownload) {
                    Text(.localized("Install"))
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .quaternarySystemFill))
                        .clipShape(Capsule())
                }
                Spacer()
                if let size = app.size, !size.isEmpty {
                    Text(size).font(.caption2).foregroundColor(.secondary)
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

private struct CypwnFeaturedCard: View {
    let app: CypwnApp
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyImage(url: URL(string: app.iconUrl ?? "")) { state in
                if let image = state.image { image
                        .resizable()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Color.gray.opacity(0.1)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            Text(displayName)
                .font(.subheadline)
                .lineLimit(1)
            Button(action: onDownload) {
                Text(.localized("Install"))
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .quaternarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .frame(width: 140)
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


