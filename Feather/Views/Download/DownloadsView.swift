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
            .navigationTitle(localizedString("Downloads"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !downloadManager.downloads.isEmpty {
                        Button(localizedString("Clear All")) {
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
                Text(localizedString("No Downloads"))
                    .font(.title2.bold())
                
                Text(localizedString("Your downloads will appear here"))
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
                        Text(localizedString("Active Downloads"))
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
                        Text(localizedString("Completed Downloads"))
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
    
    private func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "en"
        switch key {
        case "Downloads":
            return lang == "fa" ? "دانلودها" : "Downloads"
        case "Clear All":
            return lang == "fa" ? "پاک کردن همه" : "Clear All"
        case "No Downloads":
            return lang == "fa" ? "دانلودی وجود ندارد" : "No Downloads"
        case "Your downloads will appear here":
            return lang == "fa" ? "دانلودهای شما اینجا نمایش داده می‌شوند" : "Your downloads will appear here"
        case "Active Downloads":
            return lang == "fa" ? "دانلودهای فعال" : "Active Downloads"
        case "Completed Downloads":
            return lang == "fa" ? "دانلودهای تکمیل شده" : "Completed Downloads"
        default:
            return key
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
                
                // Expandable details
                if isExpanded {
                    expandedDetails
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
            
            VStack(alignment: .leading, spacing: 4) {
                DetailRow(title: localizedString("Download ID"), value: String(download.id.prefix(8)) + "...")
                DetailRow(title: localizedString("URL"), value: download.url.host ?? download.url.absoluteString)
                
                if download.onlyArchiving {
                    DetailRow(title: localizedString("Type"), value: localizedString("Archive Only"))
                } else {
                    DetailRow(title: localizedString("Type"), value: localizedString("Download & Install"))
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    downloadManager.cancelDownload(download)
                }) {
                    Label(localizedString("Cancel"), systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if let url = download.task?.originalRequest?.url {
                    Button(action: {
                        UIPasteboard.general.string = url.absoluteString
                    }) {
                        Label(localizedString("Copy URL"), systemImage: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
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
            return "xmark.circle.fill"
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
            return .red
        }
    }
    
    private var downloadStatusText: String {
        switch download.state {
        case .waiting:
            return localizedString("Waiting")
        case .downloading:
            return localizedString("Downloading...")
        case .paused:
            return localizedString("Paused")
        case .completed:
            return localizedString("Completed")
        case .failed:
            return localizedString("Failed")
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
    
    private func localizedString(_ key: String) -> String {
        let lang = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? "en"
        switch key {
        case "Download ID":
            return lang == "fa" ? "شناسه دانلود" : "Download ID"
        case "URL":
            return lang == "fa" ? "آدرس" : "URL"
        case "Type":
            return lang == "fa" ? "نوع" : "Type"
        case "Archive Only":
            return lang == "fa" ? "فقط آرشیو" : "Archive Only"
        case "Download & Install":
            return lang == "fa" ? "دانلود و نصب" : "Download & Install"
        case "Cancel":
            return lang == "fa" ? "لغو" : "Cancel"
        case "Copy URL":
            return lang == "fa" ? "کپی آدرس" : "Copy URL"
        case "Preparing...":
            return lang == "fa" ? "در حال آماده‌سازی..." : "Preparing..."
        case "Downloading...":
            return lang == "fa" ? "در حال دانلود..." : "Downloading..."
        case "Paused":
            return lang == "fa" ? "متوقف شده" : "Paused"
        case "Canceling...":
            return lang == "fa" ? "در حال لغو..." : "Canceling..."
        case "Completed":
            return lang == "fa" ? "تکمیل شده" : "Completed"
        case "Unknown":
            return lang == "fa" ? "نامشخص" : "Unknown"
        default:
            return key
        }
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
