//
//  ScreenshotDetailView.swift
//  Feather
//
//  Created by Assistant on 15.09.2025.
//

import SwiftUI
import NukeUI

struct ScreenshotDetailView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                LazyImage(url: URL(string: imageUrl)) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if state.error != nil {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            
                            Text("Failed to load screenshot")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Text("Please try again later")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

#Preview {
    ScreenshotDetailView(imageUrl: "https://example.com/screenshot.png")
}