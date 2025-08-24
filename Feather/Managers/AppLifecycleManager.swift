//
//  AppLifecycleManager.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation
import UIKit
import Combine

// MARK: - App Lifecycle Manager for Cache Management

class AppLifecycleManager: ObservableObject {
    static let shared = AppLifecycleManager()
    
    @Published private(set) var shouldRefreshOnNextAppear = false
    private var backgroundTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // Threshold: If app was backgrounded for more than 30 seconds, refresh on reopen
    private let backgroundRefreshThreshold: TimeInterval = 30 // 30 seconds instead of 5 minutes
    
    private init() {
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        // Listen for app lifecycle changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lifecycle Event Handlers
    
    private func handleAppWillResignActive() {
        print("🔄 AppLifecycle: App will resign active")
    }
    
    private func handleAppDidBecomeActive() {
        print("🔄 AppLifecycle: App did become active")
        checkIfShouldRefresh()
    }
    
    private func handleAppDidEnterBackground() {
        print("🔄 AppLifecycle: App entered background")
        backgroundTime = Date()
    }
    
    private func handleAppWillEnterForeground() {
        print("🔄 AppLifecycle: App will enter foreground")
        checkIfShouldRefresh()
    }
    
    private func checkIfShouldRefresh() {
        guard let backgroundTime = backgroundTime else {
            // First app launch - no refresh needed
            print("📱 AppLifecycle: First app launch, no refresh needed")
            return
        }
        
        let timeSinceBackground = Date().timeIntervalSince(backgroundTime)
        
        if timeSinceBackground > backgroundRefreshThreshold {
            print("⏰ AppLifecycle: App was backgrounded for \(Int(timeSinceBackground))s (threshold: \(Int(backgroundRefreshThreshold))s)")
            print("🔄 AppLifecycle: Triggering cache refresh on next homepage appear")
            
            // Clear cache and mark for refresh
            let baseURL = AuthManager.shared.apiBaseURL.absoluteString
            NetworkManager.shared.clearHomepageCache(baseURL: baseURL)
            
            DispatchQueue.main.async {
                self.shouldRefreshOnNextAppear = true
            }
        } else {
            print("✅ AppLifecycle: App was only backgrounded for \(Int(timeSinceBackground))s, using cached data")
            
            // Even for short backgrounding, still mark for refresh to ensure fresh data
            if timeSinceBackground > 10 { // More than 10 seconds
                print("🔄 AppLifecycle: Short background time but still refreshing for better UX")
                DispatchQueue.main.async {
                    self.shouldRefreshOnNextAppear = true
                }
            }
        }
        
        // Reset background time
        self.backgroundTime = nil
    }
    
    // MARK: - Public Methods
    
    func markRefreshHandled() {
        DispatchQueue.main.async {
            self.shouldRefreshOnNextAppear = false
        }
    }
    
    func forceRefreshOnNextAppear() {
        DispatchQueue.main.async {
            self.shouldRefreshOnNextAppear = true
        }
    }
    
    // Reset all state (useful for testing or manual reset)
    func reset() {
        DispatchQueue.main.async {
            self.shouldRefreshOnNextAppear = false
            self.backgroundTime = nil
        }
    }
}