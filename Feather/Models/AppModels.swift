//
//  AppModels.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation

// MARK: - App Data Models

struct IOSAppDTO: Codable, Identifiable {
    let id: Int
    let bundleIdentifier: String
    let name: String
    let nameFa: String
    let version: String
    let description: String
    let descriptionFa: String
    let shortDescriptionFa: String?
    let shortDescriptionEn: String?
    let iconUrl: String
    let ipaUrl: String
    let screenshots: String?
    let bannerUrl: String?
    let developer: String?
    let hint: String?
    let fileSize: String?
    let isPopular: Bool?
    let isProChoice: Bool?
    let isFeatured: Bool?
    let isAi: Bool?
    let whatsNew: String?
    let whatsNewFa: String?
    let whatsNewEn: String?
    let averageRating: Double?
    let ratingCount: Int?
    let categoryId: Int?
    let category: AppCategory?
    let createdAt: String?
    let updatedAt: String?
    let reviews: [Review]?

    var displayName: String { 
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? nameFa : name
    }
    
    var displayDescription: String? {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? descriptionFa : description
    }
    
    var displayShortDescription: String? {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? shortDescriptionFa : shortDescriptionEn
    }
    
    var displayWhatsNew: String? {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? (whatsNewFa ?? whatsNew) : (whatsNewEn ?? whatsNew)
    }
    
    var rating: Double? {
        return averageRating
    }
    
    var reviewCount: Int? {
        return ratingCount
    }
    
    var downloadUrl: String? {
        return ipaUrl
    }
    
    var size: String? {
        return fileSize
    }
    
    var isNew: Bool? {
        // Consider app as new if created within last 30 days
        guard let createdAt = createdAt else { return false }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: createdAt) else { return false }
        return Date().timeIntervalSince(date) < 30 * 24 * 60 * 60 // 30 days
    }
    
    var screenshotUrls: [String]? {
        guard let screenshots = screenshots else { return nil }
        
        // If it's already an array (from backend), parse as JSON string
        if screenshots.hasPrefix("[") {
            do {
                let urls = try JSONDecoder().decode([String].self, from: screenshots.data(using: .utf8) ?? Data())
                return urls
            } catch {
                return nil
            }
        }
        
        // If it's a JSON object with screenshots key
        if screenshots.hasPrefix("{") {
            do {
                let jsonData = screenshots.data(using: .utf8) ?? Data()
                let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                return jsonObject?["screenshots"] as? [String]
            } catch {
                return nil
            }
        }
        
        // Fallback: split by comma if it's a simple string
        return screenshots.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

struct AppCategory: Codable, Identifiable {
    let id: Int
    let nameEn: String
    let nameFa: String
    let icon: String?
    
    var displayName: String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? nameFa : nameEn
    }
    
    // For backward compatibility
    var name: String { nameEn }
}

struct Review: Codable, Identifiable {
    let id: Int
    let rating: Double
    let comment: String?
    let userId: Int?
    let appId: Int
    let createdAt: String?
}

// MARK: - Homepage Layout Models

struct HomepageSectionDTO: Codable {
    let id: String
    let type: String
    let title_fa: String?
    let title_en: String?
    let subtitle_fa: String?
    let subtitle_en: String?
    let appIds: [String]?
    let enabled: Bool
    let order: Int

    var localizedTitle: String? {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? (title_fa ?? title_en) : (title_en ?? title_fa)
    }
    
    var localizedSubtitle: String? {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "fa"
        return lang == "fa" ? (subtitle_fa ?? subtitle_en) : (subtitle_en ?? subtitle_fa)
    }
}

struct PageResponse: Codable {
    let blocks: [HomepageSectionDTO]
}

struct IOSHomepageResponse: Codable {
    let sections: [HomepageSectionDTO]
    let banners: String?
    let editorsChoice: String?
    let personalized: String?
    let trending: String?
    let metadata: String?
}
