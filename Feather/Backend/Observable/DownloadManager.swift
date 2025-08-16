//
//  enum.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import Foundation
import Combine
import UIKit.UIImpactFeedbackGenerator

enum DownloadState {
    case waiting      // In queue, not started
    case downloading  // Currently downloading
    case paused      // Paused by user
    case completed   // Successfully completed
    case failed      // Failed with error
}

class Download: ObservableObject, Identifiable, @unchecked Sendable {
	@Published var progress: Double = 0.0
	@Published var bytesDownloaded: Int64 = 0
	@Published var totalBytes: Int64 = 0
	@Published var unpackageProgress: Double = 0.0
	@Published var isCompleted: Bool = false
    @Published var state: DownloadState = .waiting
	
	var overallProgress: Double {
		onlyArchiving
		? unpackageProgress
		: (0.3 * unpackageProgress) + (0.7 * progress)
	}
	
    var task: URLSessionDownloadTask?
    var resumeData: Data?
	
	let id: String
	let url: URL
	let fileName: String
	let onlyArchiving: Bool
    
    init(
		id: String,
		url: URL,
		onlyArchiving: Bool = false
	) {
		self.id = id
        self.url = url
		self.onlyArchiving = onlyArchiving
        self.fileName = url.lastPathComponent
    }
}

class DownloadManager: NSObject, ObservableObject {
	static let shared = DownloadManager()
	
    @Published private var internalDownloads: [Download] = []
    @Published private var downloadQueue: [Download] = []
    
    // Computed property that sorts downloads (active first, completed last)
    var downloads: [Download] {
        return internalDownloads.sorted { first, second in
            if first.isCompleted && !second.isCompleted {
                return false // Completed goes to end
            } else if !first.isCompleted && second.isCompleted {
                return true // Active goes to beginning
            } else {
                // Both same completion status, maintain original order
                return false
            }
        }
    }
    
    // Trigger UI updates when downloads change
    private func notifyDownloadsChanged() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    private let maxConcurrentDownloads = 1 // Download one at a time
	
	var manualDownloads: [Download] {
		internalDownloads.filter { isManualDownload($0.id) }
	}
	
    private var _session: URLSession!
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        _session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    func startDownload(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
        if let existingDownload = internalDownloads.first(where: { $0.url == url }) {
            // If already queued or paused, just return it; don't auto-resume on start
            return existingDownload
        }
        
		let download = Download(id: id, url: url)
        internalDownloads.append(download)
        
        // Add to queue and process
        downloadQueue.append(download)
        processQueue()
        
        return download
    }
    
    private func processQueue() {
        // Count truly active downloads (running state)
        let activeDownloads = internalDownloads.filter { 
            $0.task?.state == .running || $0.state == .downloading
        }
        
        print("ProcessQueue: Active downloads: \(activeDownloads.count), Queue: \(downloadQueue.count)")
        
        // Start only one download if we are under the limit
        if activeDownloads.count < maxConcurrentDownloads, let nextDownload = downloadQueue.first {
            // Prevent duplicates: only start if it has no running task
            if nextDownload.task == nil || nextDownload.task?.state != .running {
                _ = downloadQueue.removeFirst()
                print("Starting download from queue: \(nextDownload.fileName)")
                startActualDownload(nextDownload)
            }
        }
    }
    
    private func startActualDownload(_ download: Download) {
        let task = _session.downloadTask(with: download.url)
        download.task = task
        download.state = .downloading
        task.resume()
    }
	
	func startArchive(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
		let download = Download(id: id, url: url, onlyArchiving: true)
		internalDownloads.append(download)
		return download
	}
    
    func resumeDownload(_ download: Download) {
        if let resumeData = download.resumeData {
            // Resume from where we left off
            let task = _session.downloadTask(withResumeData: resumeData)
            download.task = task
            download.resumeData = nil // Clear resume data after use
            download.state = .downloading
            task.resume()
        } else if download.task?.state == .suspended {
            // Just resume the suspended task
            download.state = .downloading
            download.task?.resume()
        } else {
            // Start a new download task
            let task = _session.downloadTask(with: download.url)
            download.task = task
            download.state = .downloading
            task.resume()
        }
    }
    
    func pauseDownload(_ download: Download) {
        // Mark as paused and cancel by producing resume data
        download.state = .paused
        (download.task as? URLSessionDownloadTask)?.cancel(byProducingResumeData: { resumeDataOrNil in
            // Store resume data then process queue for next item
            DispatchQueue.main.async {
                download.resumeData = resumeDataOrNil
                self.processQueue()
            }
        })
    }
    
    func pauseDownloadWithResumeData(_ download: Download) {
        pauseDownload(download) // Same as pauseDownload now
    }
    
    func cancelDownload(_ download: Download) {
        print("Canceling download: \(download.fileName)")
        
        // Cancel the task if it exists
        download.task?.cancel()
        download.state = .failed
        
        // Remove from downloads and queue
        if let index = internalDownloads.firstIndex(where: { $0.id == download.id }) {
            internalDownloads.remove(at: index)
            
            print("Removed download from internalDownloads at index \(index)")
        }
        if let queueIndex = downloadQueue.firstIndex(where: { $0.id == download.id }) {
            downloadQueue.remove(at: queueIndex)
            print("Removed download from queue at index \(queueIndex)")
        }
        
        // Process queue to start next download if available
        print("Processing queue after cancel...")
        processQueue()
    }
    
	func isManualDownload(_ string: String) -> Bool {
		return string.contains("FeatherManualDownload")
	}
	
	func getDownload(by id: String) -> Download? {
		return internalDownloads.first(where: { $0.id == id })
	}
	
	func getDownloadIndex(by id: String) -> Int? {
		return internalDownloads.firstIndex(where: { $0.id == id })
	}
	
	func getDownloadTask(by task: URLSessionDownloadTask) -> Download? {
		return internalDownloads.first(where: { $0.task == task })
	}
}

extension DownloadManager: URLSessionDownloadDelegate {
	
	func handlePachageFile(url: URL, dl: Download) throws {
		FR.handlePackageFile(url, download: dl) { err in
			DispatchQueue.main.async {
				if err != nil {
					let generator = UINotificationFeedbackGenerator()
					generator.notificationOccurred(.error)
					
					// Remove on error
					if let index = DownloadManager.shared.getDownloadIndex(by: dl.id) {
						DownloadManager.shared.internalDownloads.remove(at: index)
					}
				} else {
					// Mark as completed instead of removing
					dl.isCompleted = true
					dl.state = .completed
					dl.progress = 1.0
					dl.unpackageProgress = 1.0
					
					// Notify UI of changes
					self.notifyDownloadsChanged()
					
					// Process queue for next download
					self.processQueue()
					
					let generator = UINotificationFeedbackGenerator()
					generator.notificationOccurred(.success)
				}
			}
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		guard let download = getDownloadTask(by: downloadTask) else { return }
		
		let tempDirectory = FileManager.default.temporaryDirectory
		let customTempDir = tempDirectory.appendingPathComponent("FeatherDownloads", isDirectory: true)
		
		do {
			try FileManager.default.createDirectoryIfNeeded(at: customTempDir)
			
			// Use the server-suggested filename if available, otherwise fallback
			let suggestedFileName = downloadTask.response?.suggestedFilename ?? download.fileName
			let destinationURL = customTempDir.appendingPathComponent(suggestedFileName)
			
			try FileManager.default.removeFileIfNeeded(at: destinationURL)
			try FileManager.default.moveItem(at: location, to: destinationURL)
			
			try handlePachageFile(url: destinationURL, dl: download)
			
			// Process queue for next download
			DispatchQueue.main.async {
				self.processQueue()
			}
		} catch {
			print("Error handling downloaded file: \(error.localizedDescription)")
		}
	}
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let download = getDownloadTask(by: downloadTask) else { return }
        
        DispatchQueue.main.async {
            download.progress = totalBytesExpectedToWrite > 0
			? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
			: 0
            download.bytesDownloaded = totalBytesWritten
            download.totalBytes = totalBytesExpectedToWrite
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard
			let error = error,
			let downloadTask = task as? URLSessionDownloadTask,
			let download = getDownloadTask(by: downloadTask)
		else {
			return
		}
		
		// Check if this is a cancellation for pause (with resume data) or actual cancellation
		if let urlError = error as? URLError {
			switch urlError.code {
			case .cancelled:
                // If we have resume data or state is paused, this was a pause - keep it in list
                if download.resumeData != nil || download.state == .paused {
                    print("Download paused with resume data: \(download.fileName)")
                    return
                }
				// If no resume data, this was an actual cancellation - remove from list
				DispatchQueue.main.async {
					if let index = self.getDownloadIndex(by: download.id) {
						self.internalDownloads.remove(at: index)
					}
					// Process queue for next download
					self.processQueue()
				}
			default:
				// Other errors - remove from list
				DispatchQueue.main.async {
					if let index = self.getDownloadIndex(by: download.id) {
						self.internalDownloads.remove(at: index)
					}
					self.processQueue()
				}
			}
		}
    }
}
