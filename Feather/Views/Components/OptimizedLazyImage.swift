//
//  OptimizedLazyImage.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import NukeUI

// MARK: - Optimized Lazy Image Component

struct OptimizedLazyImage<Placeholder: View, ErrorView: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    let errorView: (Error) -> ErrorView
    let contentMode: ContentMode
    let animation: Animation
    
    @State private var isLoaded = false
    @State private var hasError = false
    
    init(
        url: URL?,
        contentMode: ContentMode = .fit,
        animation: Animation = .easeInOut(duration: 0.3),
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder errorView: @escaping (Error) -> ErrorView
    ) {
        self.url = url
        self.contentMode = contentMode
        self.animation = animation
        self.placeholder = placeholder
        self.errorView = errorView
    }
    
    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .opacity(isLoaded ? 1.0 : 0.0)
                    .animation(animation, value: isLoaded)
                    .onAppear {
                        if !isLoaded {
                            isLoaded = true
                        }
                    }
            } else if state.error != nil {
                errorView(state.error!)
                    .onAppear {
                        hasError = true
                    }
            } else {
                placeholder()
                    .redacted(reason: .placeholder)
                    .shimmering()
            }
        }
    }
}

// MARK: - Convenience Initializers

extension OptimizedLazyImage where Placeholder == AppIconPlaceholder, ErrorView == AppIconErrorView {
    init(
        url: URL?,
        contentMode: ContentMode = .fit,
        animation: Animation = .easeInOut(duration: 0.3)
    ) {
        self.init(
            url: url,
            contentMode: contentMode,
            animation: animation,
            placeholder: { AppIconPlaceholder() },
            errorView: { _ in AppIconErrorView() }
        )
    }
}

extension OptimizedLazyImage where Placeholder == ScreenshotPlaceholder, ErrorView == ScreenshotErrorView {
    init(
        screenshotURL url: URL?,
        contentMode: ContentMode = .fill,
        animation: Animation = .easeInOut(duration: 0.3)
    ) {
        self.init(
            url: url,
            contentMode: contentMode,
            animation: animation,
            placeholder: { ScreenshotPlaceholder() },
            errorView: { _ in ScreenshotErrorView() }
        )
    }
}

// MARK: - Placeholder Views

struct AppIconPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "app.badge")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

struct AppIconErrorView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("صورت")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            )
    }
}

struct ScreenshotPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.1),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "photo")
                    .font(.title)
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

struct ScreenshotErrorView: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("تصویر یافت نشد")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.6),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}