//
//  DownloadHeaderView.swift
//  Feather
//
//  Created by samara on 16.05.2025.
//

import SwiftUI
import Combine
import NimbleExtensions

struct DownloadHeaderView: View {
	@ObservedObject var downloadManager: DownloadManager
	
	var body: some View {
		ZStack {
			if !downloadManager.manualDownloads.isEmpty {
				VStack {
					VStack(spacing: 12) {
						if let firstDownload = downloadManager.manualDownloads.first {
							DownloadItemView(download: firstDownload)
							
							if downloadManager.manualDownloads.count > 1 {
								HStack {
									Spacer()
									Text(verbatim: "+\(downloadManager.manualDownloads.count - 1)")
										.font(.caption)
										.foregroundColor(.secondary)
										.padding(.vertical, 4)
								}
							}
						}
					}
					.padding(.horizontal)
				}
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(.spring(response: 0.5, dampingFraction: 0.8), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
	let download: Download
	@State private var progress: Double = 0
	@State private var bytesDownloaded: Int64 = 0
	@State private var totalBytes: Int64 = 0
	@State private var unpackageProgress: Double = 0
	@State private var showCompletionMessage: Bool = false
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(download.fileName)
					.font(.subheadline)
					.lineLimit(1)
				
				Spacer()
				
				if download.state == .completed {
					Image(systemName: "checkmark.circle.fill")
						.foregroundColor(.green)
						.font(.caption)
				} else if download.state == .failed {
					Image(systemName: "xmark.circle.fill")
						.foregroundColor(.red)
						.font(.caption)
				}
			}
			
			if download.state == .completed {
				Text(.localized("Import completed successfully"))
					.font(.caption)
					.foregroundColor(.green)
			} else if download.state == .failed {
				Text(download.errorMessage ?? .localized("Import failed"))
					.font(.caption)
					.foregroundColor(.red)
			} else {
				ProgressView(value: overallProgress)
					.progressViewStyle(.linear)
				
				HStack {
					Text(verbatim: "\(Int(overallProgress * 100))%")
						.contentTransition(.numericText())
					Spacer()
					if totalBytes > 0 {
						Text(verbatim: "\($bytesDownloaded.wrappedValue.formattedByteCount) / \(totalBytes.formattedByteCount)")
							.contentTransition(.numericText())
					}
				}
				.font(.caption)
				.foregroundColor(.secondary)
			}
		}
		.padding(.vertical, 4)
		.onReceive(download.$progress) { self.progress = $0 }
		.onReceive(download.$bytesDownloaded) { self.bytesDownloaded = $0 }
		.onReceive(download.$totalBytes) { self.totalBytes = $0 }
		.onReceive(download.$unpackageProgress) { self.unpackageProgress = $0 }
		.onReceive(download.$state) { state in
			if state == .completed {
				// Show completion message briefly
				showCompletionMessage = true
			}
		}
	}
	
	private var overallProgress: Double {
		download.onlyArchiving
		? unpackageProgress
		: (0.3 * unpackageProgress) + (0.7 * progress)
	}
}
