//
//  LazyContentView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI

// MARK: - Lazy Content Container

struct LazyContentView<Content: View>: View {
    let content: () -> Content
    let threshold: CGFloat
    
    @State private var isVisible = false
    @State private var hasAppeared = false
    
    init(threshold: CGFloat = 50, @ViewBuilder content: @escaping () -> Content) {
        self.threshold = threshold
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            if hasAppeared {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                placeholder
                    .onAppear {
                        // Small delay to ensure smooth scrolling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hasAppeared = true
                            }
                        }
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        checkVisibility(geometry: geo)
                    }
                    .onChange(of: geo.frame(in: .global)) { frame in
                        checkVisibility(frame: frame)
                    }
            }
        )
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(height: 120)
            .redacted(reason: .placeholder)
            .shimmering()
    }
    
    private func checkVisibility(geometry: GeometryProxy? = nil, frame: CGRect? = nil) {
        let rect = frame ?? geometry?.frame(in: .global) ?? .zero
        let screenHeight = UIScreen.main.bounds.height
        
        let isInView = rect.minY < screenHeight + threshold && rect.maxY > -threshold
        
        if isInView && !isVisible {
            isVisible = true
        }
    }
}

// MARK: - Viewport Tracking Modifier

struct ViewportTrackingModifier: ViewModifier {
    let onVisible: () -> Void
    let onHidden: () -> Void
    let threshold: CGFloat
    
    @State private var isVisible = false
    
    init(
        threshold: CGFloat = 0,
        onVisible: @escaping () -> Void,
        onHidden: @escaping () -> Void = {}
    ) {
        self.threshold = threshold
        self.onVisible = onVisible
        self.onHidden = onHidden
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            checkVisibility(geometry: geometry)
                        }
                        .onChange(of: geometry.frame(in: .global)) { frame in
                            checkVisibility(frame: frame)
                        }
                }
            )
    }
    
    private func checkVisibility(geometry: GeometryProxy? = nil, frame: CGRect? = nil) {
        let rect = frame ?? geometry?.frame(in: .global) ?? .zero
        let screenBounds = UIScreen.main.bounds
        
        let isInViewport = rect.intersects(
            CGRect(
                x: screenBounds.minX - threshold,
                y: screenBounds.minY - threshold,
                width: screenBounds.width + (2 * threshold),
                height: screenBounds.height + (2 * threshold)
            )
        )
        
        if isInViewport && !isVisible {
            isVisible = true
            onVisible()
        } else if !isInViewport && isVisible {
            isVisible = false
            onHidden()
        }
    }
}

extension View {
    func onViewportEnter(
        threshold: CGFloat = 0,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(ViewportTrackingModifier(
            threshold: threshold,
            onVisible: action
        ))
    }
    
    func onViewportChange(
        threshold: CGFloat = 0,
        onVisible: @escaping () -> Void,
        onHidden: @escaping () -> Void = {}
    ) -> some View {
        modifier(ViewportTrackingModifier(
            threshold: threshold,
            onVisible: onVisible,
            onHidden: onHidden
        ))
    }
}

// MARK: - Performance Monitoring

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var isLowMemory = false
    @Published var renderTime: TimeInterval = 0
    
    private var renderStartTime: CFAbsoluteTime = 0
    
    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowMemory = true
            self?.optimizeForLowMemory()
        }
    }
    
    func startRenderTracking() {
        renderStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func endRenderTracking() {
        renderTime = CFAbsoluteTimeGetCurrent() - renderStartTime
    }
    
    private func optimizeForLowMemory() {
        // Clear caches if memory is low
        DataCacheManager.shared.clearMemoryCache()
        
        // Reset flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isLowMemory = false
        }
    }
}