//
//  AllReviewsView.swift
//  Feather
//
//  Created by Assistant on 15.09.2025.
//

import SwiftUI
import Feather

struct AllReviewsView: View {
    let app: IOSAppDTO
    let reviews: [Review]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if reviews.isEmpty {
                    emptyStateView
                } else {
                    reviewsListView
                }
            }
            .navigationTitle("All Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Reviews")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This app doesn't have any reviews yet")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var reviewsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(reviews, id: \.id) { review in
                    ReviewRowView(review: review)
                        .padding(.horizontal)
                    
                    if review.id != reviews.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

struct ReviewRowView: View {
    let review: Review
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User Avatar
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Text(String((review.userName ?? "Anonymous").prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // User name and rating
                HStack {
                    Text(review.userName ?? "Anonymous User")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(review.rating.rounded()) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text(String(format: "%.1f", review.rating))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // Review text
                if let reviewText = review.text ?? review.comment, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Date
                if let createdAt = review.createdAt {
                    Text(formatReviewDate(createdAt))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    private func formatReviewDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
}

#Preview {
    AllReviewsView(
        app: IOSAppDTO(
            id: 1,
            bundleIdentifier: "com.example.app",
            name: "Sample App",
            nameFa: "برنامه نمونه",
            version: "1.0.0",
            description: "This is a sample app description.",
            descriptionFa: "این توضیحات نمونه برنامه است.",
            shortDescriptionFa: "برنامه نمونه",
            shortDescriptionEn: "Sample App",
            iconUrl: "https://example.com/icon.png",
            ipaUrl: "https://example.com/app.ipa",
            screenshots: nil,
            bannerUrl: nil,
            developer: "Developer Name",
            hint: nil,
            fileSize: "25.4 MB",
            isPopular: false,
            isProChoice: false,
            isFeatured: false,
            isAi: false,
            whatsNew: nil,
            whatsNewFa: nil,
            whatsNewEn: nil,
            averageRating: 4.5,
            ratingCount: 128,
            categoryId: 1,
            category: nil,
            createdAt: nil,
            updatedAt: nil,
            reviews: nil
        ),
        reviews: [
            Review(
                id: 1,
                rating: 5.0,
                text: "This app is amazing! I love all the features.",
                comment: nil,
                userName: "John Doe",
                userId: 123,
                appId: 1,
                createdAt: "2025-09-10T10:00:00.000Z"
            )
        ]
    )
}