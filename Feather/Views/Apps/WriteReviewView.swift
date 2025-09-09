//
//  WriteReviewView.swift
//  Feather
//
//  Created by Assistant on 15.09.2025.
//

import SwiftUI
import Feather

struct WriteReviewView: View {
    let app: IOSAppDTO
    let onReviewSubmitted: (Review) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 0
    @State private var reviewText: String = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    
    var body: some View {
        NavigationView {
            VStack {
                appInfoHeader
                ratingSelector
                reviewInput
                Spacer()
            }
            .padding()
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReview()
                    }
                    .disabled(rating == 0 || isSubmitting)
                }
            }
            .alert("Error", isPresented: .constant(submitError != nil), presenting: submitError) { _ in
                Button("OK") {
                    submitError = nil
                }
            } message: { errorMessage in
                Text(errorMessage)
            }
        }
    }
    
    private var appInfoHeader: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: app.iconUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let developer = app.developer {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.bottom)
    }
    
    private var ratingSelector: some View {
        VStack(spacing: 16) {
            Text("Tap to rate:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                ForEach(1..<6) { star in
                    Button(action: {
                        rating = star
                    }) {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundColor(star <= rating ? .yellow : .gray)
                    }
                }
            }
            
            if rating > 0 {
                Text(ratingText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical)
    }
    
    private var reviewInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review (optional):")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextEditor(text: $reviewText)
                .frame(height: 120)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .disableAutocorrection(true)
            
            Text("Your review will be public and may be edited for clarity and relevance.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var ratingText: String {
        switch rating {
        case 1: return "Not good"
        case 2: return "Okay"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return ""
        }
    }
    
    private func submitReview() {
        guard rating > 0 else { return }
        
        isSubmitting = true
        
        Task {
            do {
                // Get the current user's name from AuthManager
                let userName = AuthManager.shared.currentUserEmail ?? "Anonymous User"
                
                // Submit the review to the backend
                let newReview = try await NetworkManager.shared.submitAppReview(
                    appId: app.id,
                    userName: userName,
                    rating: rating,
                    text: reviewText.isEmpty ? "No comment" : reviewText,
                    baseURL: AuthManager.shared.apiBaseURL.absoluteString
                )
                
                await MainActor.run {
                    isSubmitting = false
                    onReviewSubmitted(newReview)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submitError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    WriteReviewView(
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
        onReviewSubmitted: { _ in }
    )
}