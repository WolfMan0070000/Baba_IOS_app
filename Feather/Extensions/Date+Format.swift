//
//  Date+Format.swift
//  Feather
//
//  Created by Assistant on 09.09.2025.
//

import Foundation

extension Date {
    /// Formats a date to a relative string (e.g., "2 hours ago", "5 days ago")
    /// - Returns: A human-readable relative date string
    func relativeTimeString() -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: self, to: now)
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "1 day ago"
            } else {
                return "\(days) days ago"
            }
        } else if let hours = components.hour, hours > 0 {
            if hours == 1 {
                return "1 hour ago"
            } else {
                return "\(hours) hours ago"
            }
        } else if let minutes = components.minute, minutes > 0 {
            if minutes == 1 {
                return "1 minute ago"
            } else {
                return "\(minutes) minutes ago"
            }
        } else {
            return "Just now"
        }
    }
}

/// Formats an ISO8601 date string to a relative time string
/// - Parameter dateString: An ISO8601 formatted date string
/// - Returns: A human-readable relative date string or "Unknown date" if parsing fails
func formatReviewDate(_ dateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: dateString) else {
        return "Unknown date"
    }
    
    return date.relativeTimeString()
}