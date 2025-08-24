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
        let cacheExpiry: TimeInterval = 900 // 15 minutes - longer cache for better performance
        
        // Smart caching: only force refresh when explicitly requested (pull-to-refresh or app reopen)
        let shouldForceRefresh = forceRefresh
        
        if shouldForceRefresh {
            print("🔄 NetworkManager: Force refreshing homepage data (user-triggered)")
        } else {
            print("📦 NetworkManager: Loading homepage data (cache-first)")
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
            cacheExpiry: cacheExpiry * 2, // Categories change less frequently - 30 minutes
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
            cacheExpiry: 600, // 10 minutes for individual apps
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
    }
    
    func invalidateCacheOnLogin(baseURL: String) {
        print("🔐 NetworkManager: Invalidating cache on login for \(baseURL)")
        clearHomepageCache(baseURL: baseURL)
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