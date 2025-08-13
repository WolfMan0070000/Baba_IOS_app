//
//  CypwnFeedService.swift
//  Feather
//
//  Parses feeds like https://ipa.cypwn.xyz/cypwn.json
//

import Foundation

struct CypwnApp: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameFa: String?
    let bundleIdentifier: String
    let version: String?
    let developer: String?
    let iconUrl: String?
    let downloadUrl: String
    let size: String?
    let screenshots: [String]
    let isFeatured: Bool

    init(
        id: String,
        name: String,
        nameFa: String?,
        bundleIdentifier: String,
        version: String?,
        developer: String?,
        iconUrl: String?,
        downloadUrl: String,
        size: String?,
        screenshots: [String],
        isFeatured: Bool
    ) {
        self.id = id
        self.name = name
        self.nameFa = nameFa
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.developer = developer
        self.iconUrl = iconUrl
        self.downloadUrl = downloadUrl
        self.size = size
        self.screenshots = screenshots
        self.isFeatured = isFeatured
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)

        func str(_ keys: [String]) -> String? {
            for k in keys {
                if let v = try? c.decode(String.self, forKey: .init(k)), !v.isEmpty { return v }
            }
            return nil
        }
        func bool(_ keys: [String]) -> Bool {
            for k in keys {
                if let v = try? c.decode(Bool.self, forKey: .init(k)) { return v }
                if let s = try? c.decode(String.self, forKey: .init(k)) { return (s == "1" || s.lowercased() == "true") }
            }
            return false
        }
        func array(_ keys: [String]) -> [String] {
            for k in keys {
                if let arr = (try? c.decode([String].self, forKey: .init(k))) { return arr }
            }
            return []
        }

        let name = str(["name", "title"]) ?? "Unknown"
        let nameFa = str(["name_fa", "nameFa", "title_fa"]) 
        let bundle = str(["bundleIdentifier", "bundleId", "identifier", "bundle"]) ?? UUID().uuidString
        let version = str(["version", "ver"])
        let developer = str(["developer", "dev", "author"]) 
        let iconUrl = str(["icon", "iconUrl", "icon_url", "image"])
        let download = str(["ipa", "ipaUrl", "download", "downloadURL", "url"]) ?? ""
        let size = str(["size", "fileSize", "filesize"]) 
        let screenshots = array(["screenshots", "images"]) 
        let isFeatured = bool(["isFeatured", "featured"]) 

        self.init(
            id: bundle,
            name: name,
            nameFa: nameFa,
            bundleIdentifier: bundle,
            version: version,
            developer: developer,
            iconUrl: iconUrl,
            downloadUrl: download,
            size: size,
            screenshots: screenshots,
            isFeatured: isFeatured
        )
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(_ string: String) { self.stringValue = string; self.intValue = nil }
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}

enum CypwnFeedService {
    static func fetch(from url: URL) async throws -> [CypwnApp] {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // The feed might be an array or an object with an apps array
        if let arr = try? JSONDecoder().decode([CypwnApp].self, from: data) {
            return arr
        }
        struct Root: Decodable { let apps: [CypwnApp]? }
        let root = try JSONDecoder().decode(Root.self, from: data)
        return root.apps ?? []
    }
}


