//
//  DownloadsView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    
    var body: some View {
        NavigationView {
            Group {
                if downloadManager.downloads.isEmpty {
                    emptyStateView
                } else {
                    downloadsList
                }
            }
            .navigationTitle(.localized("Downloads"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !downloadManager.downloads.isEmpty {
                        Button(.localized("Clear All")) {
                            clearAllDownloads()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(.localized("No Downloads"))
                    .font(.title2.bold())
                
                Text(.localized("Your downloads will appear here"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var downloadsList: some View {
        List {
            // Active Downloads
            let activeDownloads = downloadManager.downloads.filter { !$0.isCompleted }
            if !activeDownloads.isEmpty {
                Section {
                    ForEach(activeDownloads) { download in
                        DownloadRowView(download: download)
                    }
                    .onDelete { offsets in
                        deleteActiveDownloads(offsets: offsets, from: activeDownloads)
                    }
                } header: {
                    HStack {
                        Text(.localized("Active Downloads"))
                        Spacer()
                        Text("\(activeDownloads.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Completed Downloads
            let completedDownloads = downloadManager.downloads.filter { $0.isCompleted }
            if !completedDownloads.isEmpty {
                Section {
                    ForEach(completedDownloads) { download in
                        DownloadRowView(download: download)
                    }
                    .onDelete { offsets in
                        deleteCompletedDownloads(offsets: offsets, from: completedDownloads)
                    }
                } header: {
                    HStack {
                        Text(.localized("Completed Downloads"))
                        Spacer()
                        Text("\(completedDownloads.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func deleteDownloads(offsets: IndexSet) {
        for index in offsets {
            let download = downloadManager.downloads[index]
            downloadManager.cancelDownload(download)
        }
    }
    
    private func deleteActiveDownloads(offsets: IndexSet, from activeDownloads: [Download]) {
        for index in offsets {
            let download = activeDownloads[index]
            downloadManager.cancelDownload(download)
        }
    }
    
    private func deleteCompletedDownloads(offsets: IndexSet, from completedDownloads: [Download]) {
        for index in offsets {
            let download = completedDownloads[index]
            // For completed downloads, use cancelDownload to properly remove
            downloadManager.cancelDownload(download)
        }
    }
    
    private func clearAllDownloads() {
        let downloads = downloadManager.downloads
        for download in downloads {
            downloadManager.cancelDownload(download)
        }
    }
}

struct DownloadRowView: View {
    @ObservedObject var download: Download
    @ObservedObject private var downloadManager = DownloadManager.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with app info and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(downloadStatusText)
                            .font(.caption)
                            .foregroundColor(downloadStatusColor)
                        
                        if download.totalBytes > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatFileSize(download.totalBytes))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                downloadControlButton
            }
            
            // Progress section
            VStack(alignment: .leading, spacing: 8) {
                // Progress bar
                ProgressView(value: download.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressBarColor))
                
                // Progress details
                HStack {
                    Text("\(Int(download.overallProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if download.totalBytes > 0 {
                        Text("\(formatFileSize(download.bytesDownloaded)) / \(formatFileSize(download.totalBytes))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Expandable details - only show for active downloads
                if isExpanded && !download.isCompleted {
                    expandedDetails
                }
                
                // Hint for completed downloads
                if download.isCompleted {
                    completedDownloadHint
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            // Action buttons
            HStack(spacing: 12) {
                if download.state == .failed {
                    Button(action: {
                        downloadManager.resumeDownload(download)
                    }) {
                        Label(.localized("Retry"), systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: {
                    downloadManager.cancelDownload(download)
                }) {
                    Label(.localized("Cancel"), systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
    }
    
    private var completedDownloadHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isExpanded {
                Divider()
                
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.localized("Download Complete!"))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(.localized("Go to Library to sign and install this file"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                        .font(.caption2)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var downloadControlButton: some View {
        Button(action: toggleDownload) {
            Image(systemName: downloadControlIcon)
                .font(.title2)
                .foregroundColor(downloadControlColor)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(download.state == .completed) // Disable button for completed downloads
    }
    
    private var downloadControlIcon: String {
        switch download.state {
        case .waiting:
            return "clock.circle.fill"
        case .downloading:
            return "pause.circle.fill"
        case .paused:
            return "play.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "arrow.clockwise.circle.fill" // Changed to retry icon for failed downloads
        }
    }
    
    private var downloadControlColor: Color {
        switch download.state {
        case .waiting:
            return .orange
        case .downloading:
            return .orange
        case .paused:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .blue // Changed to blue for retry indication
        }
    }
    
    private var downloadStatusText: String {
        switch download.state {
        case .waiting:
            return String(localized: "Waiting")
        case .downloading:
            return String(localized: "Downloading...")
        case .paused:
            return String(localized: "Paused")
        case .completed:
            return String(localized: "Completed")
        case .failed:
            if let errorMessage = download.errorMessage {
                return "\(String(localized: "Failed")): \(errorMessage)"
            } else {
                return String(localized: "Failed")
            }
        }
    }
    
    private var downloadStatusColor: Color {
        // Check if download is completed first
        if download.isCompleted {
            return .green
        }
        
        guard let task = download.task else {
            return .secondary
        }
        
        switch task.state {
        case .running:
            return .blue
        case .suspended:
            return .orange
        case .canceling:
            return .red
        case .completed:
            return .green
        @unknown default:
            return .secondary
        }
    }
    
    private var progressBarColor: Color {
        if download.overallProgress >= 1.0 {
            return .green
        } else if download.task?.state == .suspended {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func toggleDownload() {
        switch download.state {
        case .waiting:
            // Start the download (move to front of queue if needed)
            downloadManager.resumeDownload(download)
        case .downloading:
            // Pause the download
            downloadManager.pauseDownload(download)
        case .paused:
            // Resume the download
            downloadManager.resumeDownload(download)
        case .completed:
            // Do nothing for completed downloads
            return
        case .failed:
            // Retry the download
            downloadManager.resumeDownload(download)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    DownloadsView()
}
