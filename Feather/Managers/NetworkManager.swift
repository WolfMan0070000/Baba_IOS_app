//
//  NetworkManager.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation


// MARK: - Network Manager with Caching

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    private let cache = DataCacheManager.shared
    private let session: URLSession
    private var csrfToken: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        // Enable URL caching
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,   // 20MB memory
            diskCapacity: 100 * 1024 * 1024,    // 100MB disk
            diskPath: "BabaAppNetworkCache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Cached Fetch Methods
    
    func fetchWithCache<T: Codable>(
        _ url: String,
        type: T.Type,
        cacheKey: String,
        cacheExpiry: TimeInterval = 300,
        forceRefresh: Bool = false
    ) async throws -> T {
        
        // Try cache first unless force refresh
        if !forceRefresh {
            if let cached = cache.get(cacheKey, type: type) {
                print("📦 NetworkManager: Using cached data for key: \(cacheKey)")
                return cached
            } else {
                print("💾 NetworkManager: No cache found for key: \(cacheKey), fetching from network")
            }
        } else {
            print("🔄 NetworkManager: Force refresh requested, bypassing cache for key: \(cacheKey)")
        }
        
        print("🌐 NetworkManager: Fetching from network: \(url)")
        
        // Fetch from network with cache control
        let data = try await fetchData(url, bypassCache: forceRefresh)
        let decoded = try JSONDecoder().decode(type, from: data)
        
        // Always cache the result for future use
        cache.set(decoded, forKey: cacheKey, expirationTime: cacheExpiry)
        print("💾 NetworkManager: Cached result for key: \(cacheKey) (expires in \(Int(cacheExpiry))s)")
        
        return decoded
    }
    
    func fetchHomepageData(baseURL: String, forceRefresh: Bool = false) async throws -> (
        homepage: IOSHomepageResponse,
        categories: [AppCategory],
        featured: [IOSAppDTO]
    ) {
        let cacheExpiry: TimeInterval = 600 // Reduced to 10 minutes for more frequent updates
        
        // Smart caching: force refresh on initial app launch and user-triggered actions
        let shouldForceRefresh = forceRefresh
        
        if shouldForceRefresh {
            print("🔄 NetworkManager: Force refreshing homepage data (bypassing all caches)")
        } else {
            print("📦 NetworkManager: Loading homepage data (cache-first strategy)")
        }
        
        async let homepageTask = fetchWithCache(
            "\(baseURL)/api/v1/pages/homepage-v2",
            type: IOSHomepageResponse.self,
            cacheKey: DataCacheManager.CacheKey.homepage(baseURL: baseURL),
            cacheExpiry: cacheExpiry,
            forceRefresh: shouldForceRefresh
        )
        
        async let categoriesTask = fetchWithCache(
            "\(baseURL)/api/v1/categories",
            type: [AppCategory].self,
            cacheKey: DataCacheManager.CacheKey.categories(baseURL: baseURL),
            cacheExpiry: cacheExpiry, // Same as homepage cache - 10 minutes
            forceRefresh: shouldForceRefresh
        )
        
        async let featuredTask = fetchWithCache(
            "\(baseURL)/api/v1/apps/featured",
            type: [IOSAppDTO].self,
            cacheKey: DataCacheManager.CacheKey.featuredApps(baseURL: baseURL),
            cacheExpiry: cacheExpiry,
            forceRefresh: shouldForceRefresh
        )
        
        let (homepage, categories, featured) = try await (homepageTask, categoriesTask, featuredTask)
        return (homepage: homepage, categories: categories, featured: featured)
    }
    
    func fetchApp(id: String, baseURL: String, forceRefresh: Bool = false) async throws -> IOSAppDTO {
        return try await fetchWithCache(
            "\(baseURL)/api/v1/apps/\(id)",
            type: IOSAppDTO.self,
            cacheKey: DataCacheManager.CacheKey.app(id: id, baseURL: baseURL),
            cacheExpiry: 300, // Reduced to 5 minutes for individual apps
            forceRefresh: forceRefresh
        )
    }
    
    func fetchCategoryApps(categoryId: Int, baseURL: String, forceRefresh: Bool = false) async throws -> [IOSAppDTO] {
        struct AppsResponse: Codable { let apps: [IOSAppDTO] }
        
        let response = try await fetchWithCache(
            "\(baseURL)/api/v1/apps?categoryId=\(categoryId)",
            type: AppsResponse.self,
            cacheKey: DataCacheManager.CacheKey.categoryApps(categoryId: categoryId, baseURL: baseURL),
            cacheExpiry: 600, // 10 minutes for category apps
            forceRefresh: forceRefresh
        )
        
        return response.apps
    }
    
    func preloadApps(ids: [String], baseURL: String) {
        Task.detached(priority: .background) { [weak self] in
            print("📦 NetworkManager: Background preloading \(ids.count) apps")
            
            // Preload apps in background with lower priority
            for id in ids {
                do {
                    _ = try await self?.fetchApp(id: id, baseURL: baseURL, forceRefresh: false)
                    print("✅ NetworkManager: Preloaded app \(id)")
                } catch {
                    print("⚠️ NetworkManager: Failed to preload app \(id): \(error)")
                }
            }
            
            print("💼 NetworkManager: Background preloading completed")
        }
    }
    
    // MARK: - Smart Background Refresh
    
    func scheduleBackgroundRefresh(baseURL: String, delay: TimeInterval = 30) {
        Task.detached(priority: .background) { [weak self] in
            // Wait before starting background refresh
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                print("🔄 NetworkManager: Starting scheduled background refresh")
                _ = try await self?.fetchHomepageData(baseURL: baseURL, forceRefresh: false)
                print("✅ NetworkManager: Background refresh completed successfully")
            } catch {
                print("⚠️ NetworkManager: Background refresh failed: \(error)")
            }
        }
    }
    
    // MARK: - Background Refresh
    
    func backgroundRefreshHomepage(baseURL: String) {
        Task.detached(priority: .background) { [weak self] in
            do {
                print("🔄 NetworkManager: Starting background homepage refresh")
                _ = try await self?.fetchHomepageData(baseURL: baseURL, forceRefresh: false)
                print("✅ NetworkManager: Background refresh completed")
            } catch {
                print("⚠️ NetworkManager: Background refresh failed: \(error)")
            }
        }
    }
    
    // MARK: - Cache Management
    
    func clearAllCaches() {
        print("🧹 NetworkManager: Clearing all caches")
        cache.clearAllCache()
        session.configuration.urlCache?.removeAllCachedResponses()
    }
    
    func clearHomepageCache(baseURL: String) {
        print("🧹 NetworkManager: Clearing homepage cache for \(baseURL)")
        let homepageKey = DataCacheManager.CacheKey.homepage(baseURL: baseURL)
        let categoriesKey = DataCacheManager.CacheKey.categories(baseURL: baseURL)
        let featuredKey = DataCacheManager.CacheKey.featuredApps(baseURL: baseURL)
        
        cache.remove(key: homepageKey)
        cache.remove(key: categoriesKey)
        cache.remove(key: featuredKey)
        
        // Also clear URL cache for network requests
        session.configuration.urlCache?.removeAllCachedResponses()
        print("🧹 NetworkManager: Homepage cache cleared completely")
    }
    
    func clearAllAppCaches(baseURL: String) {
        print("🧹 NetworkManager: Clearing all app caches for \(baseURL)")
        // Clear all cached individual apps and category apps
        cache.clearAllCache()
        session.configuration.urlCache?.removeAllCachedResponses()
        print("🧹 NetworkManager: All app caches cleared")
    }
    
    func invalidateCacheOnLogin(baseURL: String) {
        print("🔐 NetworkManager: Invalidating cache on login for \(baseURL)")
        clearHomepageCache(baseURL: baseURL)
    }
    
    // MARK: - CSRF Token Management
    
    private func fetchCSRFToken(baseURL: String) async throws -> String {
        if let existingToken = csrfToken {
            return existingToken
        }
        
        guard let url = URL(string: "\(baseURL)/api/csrf-token") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        struct CSRFResponse: Codable {
            let csrfToken: String
        }
        
        let csrfResponse = try JSONDecoder().decode(CSRFResponse.self, from: data)
        self.csrfToken = csrfResponse.csrfToken
        return csrfResponse.csrfToken
    }
    
    
    // MARK: - Review API Methods
    
    func fetchAppReviews(appId: Int, baseURL: String) async throws -> [Review] {
        return try await fetchWithCache(
            "\(baseURL)/api/v1/reviews/\(appId)",
            type: [Review].self,
            cacheKey: DataCacheManager.CacheKey.appReviews(appId: appId, baseURL: baseURL),
            cacheExpiry: 300, // 5 minutes cache for reviews
            forceRefresh: false
        )
    }
    
    func submitAppReview(appId: Int, userName: String, rating: Int, text: String, baseURL: String) async throws -> Review {
        return try await submitAppReviewWithRetry(appId: appId, userName: userName, rating: rating, text: text, baseURL: baseURL, isRetry: false)
    }
    
    private func submitAppReviewWithRetry(appId: Int, userName: String, rating: Int, text: String, baseURL: String, isRetry: Bool) async throws -> Review {
        guard let url = URL(string: "\(baseURL)/api/v1/reviews/\(appId)") else {
            throw NetworkError.invalidURL
        }
        
        let reviewData: [String: Any] = [
            "userName": userName,
            "rating": rating,
            "text": text
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add mobile app identifier to bypass CSRF for mobile requests
        request.setValue("true", forHTTPHeaderField: "X-Mobile-App")
        
        // Add authentication using token refresh mechanism
        do {
            let token = try await AuthManager.shared.getValidAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch {
            throw ReviewError.authenticationRequired
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: reviewData)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle 401 errors by trying to refresh token once more
        if httpResponse.statusCode == 401 && !isRetry {
            do {
                _ = try await AuthManager.shared.refreshAccessToken()
                // Retry the request with new token
                return try await submitAppReviewWithRetry(appId: appId, userName: userName, rating: rating, text: text, baseURL: baseURL, isRetry: true)
            } catch {
                throw ReviewError.authenticationRequired
            }
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 409 {
                throw ReviewError.alreadyReviewed
            }
            if httpResponse.statusCode == 401 {
                throw ReviewError.authenticationRequired
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        let review = try JSONDecoder().decode(Review.self, from: data)
        
        // Clear reviews cache to refresh the list
        let cacheKey = DataCacheManager.CacheKey.appReviews(appId: appId, baseURL: baseURL)
        cache.remove(key: cacheKey)
        
        return review
    }

    // MARK: - Private Methods
    
    private func fetchData(_ urlString: String, bypassCache: Bool = false) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        // Create request with cache control
        var request = URLRequest(url: url)
        
        if bypassCache {
            // Bypass all caches when force refreshing
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            // Add headers to prevent server-side caching
            request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            request.setValue("\(Date().timeIntervalSince1970)", forHTTPHeaderField: "X-Timestamp")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - Review Errors

enum ReviewError: LocalizedError {
    case alreadyReviewed
    case invalidRating
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .alreadyReviewed:
            return String(localized: "You have already reviewed this app")
        case .invalidRating:
            return String(localized: "Rating must be between 1 and 5")
        case .authenticationRequired:
            return String(localized: "Please log in to submit a review")
        }
    }
}