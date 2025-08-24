//
//  DataCacheManager.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation
import UIKit

// MARK: - Cache Manager for API Data

class DataCacheManager: ObservableObject {
    static let shared = DataCacheManager()
    
    private let cache = NSCache<NSString, CacheItem>()
    private let fileManager = FileManager.default
    private let diskCacheDirectory: URL
    
    private init() {
        // Create disk cache directory
        let documentsPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheDirectory = documentsPath.appendingPathComponent("BabaAppDataCache")
        
        if !fileManager.fileExists(atPath: diskCacheDirectory.path) {
            try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure memory cache
        cache.countLimit = 50 // Limit number of items
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearMemoryCache()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Cache Operations
    
    func get<T: Codable>(_ key: String, type: T.Type) -> T? {
        // Check memory cache first
        if let item = cache.object(forKey: NSString(string: key)),
           !item.isExpired {
            do {
                return try JSONDecoder().decode(type, from: item.data)
            } catch {
                print("⚠️ DataCache: Failed to decode cached data for key: \(key)")
            }
        }
        
        // Check disk cache
        return getDiskCached(key, type: type)
    }
    
    func set<T: Codable>(_ value: T, forKey key: String, expirationTime: TimeInterval = 300) {
        do {
            let data = try JSONEncoder().encode(value)
            let cost = data.count
            
            // Store in memory cache
            let item = CacheItem(
                data: data,
                expirationTime: Date().addingTimeInterval(expirationTime)
            )
            cache.setObject(item, forKey: NSString(string: key), cost: cost)
            
            // Store in disk cache (async)
            Task.detached { [weak self] in
                self?.setDiskCached(data, forKey: key, expirationTime: expirationTime)
            }
        } catch {
            print("⚠️ DataCache: Failed to encode data for key: \(key)")
        }
    }
    
    func remove(key: String) {
        cache.removeObject(forKey: NSString(string: key))
        
        let diskPath = diskCacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: diskPath)
    }
    
    func clearMemoryCache() {
        cache.removeAllObjects()
        print("🧹 DataCache: Memory cache cleared")
    }
    
    func clearAllCache() {
        clearMemoryCache()
        try? fileManager.removeItem(at: diskCacheDirectory)
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        print("🧹 DataCache: All cache cleared")
    }
    
    func getCacheSize() -> (memory: Int, disk: Int) {
        let memorySize = cache.totalCostLimit
        
        var diskSize = 0
        if let enumerator = fileManager.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    diskSize += fileSize
                }
            }
        }
        
        return (memory: memorySize, disk: diskSize)
    }
    
    func getCacheStats() -> (itemCount: Int, totalSize: Int, oldestExpiry: Date?, newestExpiry: Date?) {
        var itemCount = 0
        var totalSize = 0
        var oldestExpiry: Date?
        var newestExpiry: Date?
        
        if let enumerator = fileManager.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                guard url.pathExtension == "cache" else { continue }
                
                if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    
                    // Try to read cache item to get expiry
                    if let data = try? Data(contentsOf: url),
                       let item = try? JSONDecoder().decode(DiskCacheItem.self, from: data) {
                        itemCount += 1
                        totalSize += fileSize
                        
                        if oldestExpiry == nil || item.expirationTime < oldestExpiry! {
                            oldestExpiry = item.expirationTime
                        }
                        if newestExpiry == nil || item.expirationTime > newestExpiry! {
                            newestExpiry = item.expirationTime
                        }
                    }
                }
            }
        }
        
        return (itemCount: itemCount, totalSize: totalSize, oldestExpiry: oldestExpiry, newestExpiry: newestExpiry)
    }
    
    func cleanExpiredCache() {
        Task.detached { [weak self] in
            await self?.performCacheCleanup()
        }
    }
    
    @MainActor
    private func performCacheCleanup() {
        guard let enumerator = fileManager.enumerator(at: diskCacheDirectory, includingPropertiesForKeys: nil) else { return }
        
        var removedCount = 0
        var reclaimedBytes = 0
        
        for case let url as URL in enumerator {
            guard url.pathExtension == "cache" else { continue }
            
            do {
                let data = try Data(contentsOf: url)
                let item = try JSONDecoder().decode(DiskCacheItem.self, from: data)
                
                if item.isExpired {
                    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    try fileManager.removeItem(at: url)
                    removedCount += 1
                    reclaimedBytes += fileSize
                }
            } catch {
                // If we can't read the file, it's corrupted - remove it
                try? fileManager.removeItem(at: url)
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            print("🧹 DataCache: Cleaned \(removedCount) expired items, reclaimed \(reclaimedBytes) bytes")
        }
    }
    
    // MARK: - Private Disk Cache Methods
    
    private func getDiskCached<T: Codable>(_ key: String, type: T.Type) -> T? {
        let diskPath = diskCacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: diskPath.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: diskPath)
            let item = try JSONDecoder().decode(DiskCacheItem.self, from: data)
            
            if item.isExpired {
                try? fileManager.removeItem(at: diskPath)
                return nil
            }
            
            return try JSONDecoder().decode(type, from: item.data)
        } catch {
            print("⚠️ DataCache: Failed to load disk cache for key: \(key)")
            return nil
        }
    }
    
    private func setDiskCached(_ data: Data, forKey key: String, expirationTime: TimeInterval) {
        let diskPath = diskCacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            let item = DiskCacheItem(
                data: data,
                expirationTime: Date().addingTimeInterval(expirationTime)
            )
            let cacheData = try JSONEncoder().encode(item)
            try cacheData.write(to: diskPath)
        } catch {
            print("⚠️ DataCache: Failed to save to disk cache for key: \(key)")
        }
    }
}

// MARK: - Cache Item Models

private class CacheItem {
    let data: Data
    let expirationTime: Date
    
    init(data: Data, expirationTime: Date) {
        self.data = data
        self.expirationTime = expirationTime
    }
    
    var isExpired: Bool {
        return Date() > expirationTime
    }
}

private struct DiskCacheItem: Codable {
    let data: Data
    let expirationTime: Date
    
    var isExpired: Bool {
        return Date() > expirationTime
    }
}

// MARK: - Cache Keys

extension DataCacheManager {
    enum CacheKey {
        static func homepage(baseURL: String) -> String {
            return "homepage_\(baseURL.hash)"
        }
        
        static func categories(baseURL: String) -> String {
            return "categories_\(baseURL.hash)"
        }
        
        static func featuredApps(baseURL: String) -> String {
            return "featured_apps_\(baseURL.hash)"
        }
        
        static func app(id: String, baseURL: String) -> String {
            return "app_\(id)_\(baseURL.hash)"
        }
        
        static func categoryApps(categoryId: Int, baseURL: String) -> String {
            return "category_apps_\(categoryId)_\(baseURL.hash)"
        }
    }
}