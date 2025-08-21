//
//  enum.swift
//  Feather
//
//  Created by samara on 3.05.2025.
//

import Foundation
import Combine
import UIKit.UIImpactFeedbackGenerator
import UIKit.UIApplication

enum DownloadState: Int {
    case waiting = 0      // In queue, not started
    case downloading = 1  // Currently downloading
    case paused = 2      // Paused by user
    case completed = 3   // Successfully completed
    case failed = 4      // Failed with error
}

class Download: ObservableObject, Identifiable, @unchecked Sendable {
	@Published var progress: Double = 0.0
	@Published var bytesDownloaded: Int64 = 0
	@Published var totalBytes: Int64 = 0
	@Published var unpackageProgress: Double = 0.0
	@Published var isCompleted: Bool = false
    @Published var state: DownloadState = .waiting
    @Published var errorMessage: String?
	
	var overallProgress: Double {
		onlyArchiving
		? unpackageProgress
		: (0.3 * unpackageProgress) + (0.7 * progress)
	}
	
    var task: URLSessionDownloadTask?
    var resumeData: Data?
    var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
	
	let id: String
	let url: URL
	let fileName: String
	let onlyArchiving: Bool
    let createdAt: Date
    
    init(
		id: String,
		url: URL,
		onlyArchiving: Bool = false
	) {
		self.id = id
        self.url = url
		self.onlyArchiving = onlyArchiving
        self.fileName = url.lastPathComponent
        self.createdAt = Date()
    }
    
    // MARK: - Persistence
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "url": url.absoluteString,
            "fileName": fileName,
            "onlyArchiving": onlyArchiving,
            "state": state.rawValue,
            "progress": progress,
            "bytesDownloaded": bytesDownloaded,
            "totalBytes": totalBytes,
            "unpackageProgress": unpackageProgress,
            "isCompleted": isCompleted,
            "createdAt": createdAt.timeIntervalSince1970,
            "resumeData": resumeData?.base64EncodedString() ?? ""
        ]
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> Download? {
        guard 
            let id = dict["id"] as? String,
            let urlString = dict["url"] as? String,
            let url = URL(string: urlString),
            let fileName = dict["fileName"] as? String,
            let onlyArchiving = dict["onlyArchiving"] as? Bool,
            let stateRaw = dict["state"] as? Int,
            let state = DownloadState(rawValue: stateRaw),
            let progress = dict["progress"] as? Double,
            let bytesDownloaded = dict["bytesDownloaded"] as? Int64,
            let totalBytes = dict["totalBytes"] as? Int64,
            let unpackageProgress = dict["unpackageProgress"] as? Double,
            let isCompleted = dict["isCompleted"] as? Bool,
            let createdAtInterval = dict["createdAt"] as? TimeInterval
        else {
            return nil
        }
        
        let download = Download(id: id, url: url, onlyArchiving: onlyArchiving)
        download.state = state
        download.progress = progress
        download.bytesDownloaded = bytesDownloaded
        download.totalBytes = totalBytes
        download.unpackageProgress = unpackageProgress
        download.isCompleted = isCompleted
        
        if let resumeDataString = dict["resumeData"] as? String, !resumeDataString.isEmpty {
            download.resumeData = Data(base64Encoded: resumeDataString)
        }
        
        return download
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
                return first.createdAt < second.createdAt
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
    private let persistenceKey = "Feather.DownloadManager.persistedDownloads"
	
	var manualDownloads: [Download] {
		internalDownloads.filter { isManualDownload($0.id) && !$0.isCompleted }
	}
	
    private var _session: URLSession!
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    override init() {
        super.init()
        setupBackgroundSession()
        loadPersistedDownloads()
        setupAppStateObservers()
    }
    
    private func setupBackgroundSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "Feather.DownloadManager.BackgroundSession")
        configuration.sessionSendsLaunchEvents = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 3600 // 1 hour for large files
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        
        _session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    private func setupAppStateObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("App entered background - ensuring downloads continue")
        
        // Start background task to keep downloads running
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Feather.DownloadManager.BackgroundTask") { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Ensure all active downloads have background task IDs
        for download in internalDownloads where download.state == .downloading {
            if download.backgroundTaskID == .invalid {
                download.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Download.\(download.id)") { [weak self] in
                    self?.endDownloadBackgroundTask(download)
                }
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("App will enter foreground - cleaning up background tasks")
        endBackgroundTask()
        
        // End individual download background tasks
        for download in internalDownloads {
            endDownloadBackgroundTask(download)
        }
        
        // Resume any downloads that were interrupted
        resumeInterruptedDownloads()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func endDownloadBackgroundTask(_ download: Download) {
        if download.backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(download.backgroundTaskID)
            download.backgroundTaskID = .invalid
        }
    }
    
    private func resumeInterruptedDownloads() {
        for download in internalDownloads where download.state == .downloading && download.task?.state != .running {
            print("Resuming interrupted download: \(download.fileName)")
            resumeDownload(download)
        }
    }
    
    // MARK: - Persistence
    private func saveDownloads() {
        let downloadsData = internalDownloads.map { $0.toDictionary() }
        UserDefaults.standard.set(downloadsData, forKey: persistenceKey)
    }
    
    private func loadPersistedDownloads() {
        guard let downloadsData = UserDefaults.standard.array(forKey: persistenceKey) as? [[String: Any]] else {
            return
        }
        
        for downloadDict in downloadsData {
            if let download = Download.fromDictionary(downloadDict) {
                // Only restore non-completed downloads
                if !download.isCompleted {
                    internalDownloads.append(download)
                    if download.state == .waiting {
                        downloadQueue.append(download)
                    }
                }
            }
        }
        
        print("Restored \(internalDownloads.count) downloads from persistence")
    }
    
    func startDownload(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
        print("Starting download for URL: \(url.lastPathComponent)")
        
        // Check if download already exists and is not completed
        if let existingDownload = internalDownloads.first(where: { $0.url == url && !$0.isCompleted }) {
            print("Download already exists for URL: \(url.lastPathComponent)")
            return existingDownload
        }
        
        // Check if download was completed before
        if let completedDownload = internalDownloads.first(where: { $0.url == url && $0.isCompleted }) {
            print("Download already completed for URL: \(url.lastPathComponent)")
            return completedDownload
        }
        
		let download = Download(id: id, url: url)
        internalDownloads.append(download)
        
        // Add to queue and process
        downloadQueue.append(download)
        processQueue()
        
        // Save state
        saveDownloads()
        
        print("Download added to queue: \(download.fileName) (ID: \(download.id))")
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
        let task: URLSessionDownloadTask
        
        if let resumeData = download.resumeData {
            task = _session.downloadTask(withResumeData: resumeData)
            download.resumeData = nil // Clear resume data after use
        } else {
            task = _session.downloadTask(with: download.url)
        }
        
        download.task = task
        download.state = .downloading
        download.errorMessage = nil
        
        // Start background task for this download
        download.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Download.\(download.id)") { [weak self] in
            self?.endDownloadBackgroundTask(download)
        }
        
        task.resume()
        saveDownloads()
    }
	
	func startArchive(
		from url: URL,
		id: String = UUID().uuidString
	) -> Download {
		let download = Download(id: id, url: url, onlyArchiving: true)
		internalDownloads.append(download)
        saveDownloads()
		return download
	}
    
    func resumeDownload(_ download: Download) {
        if download.state == .completed {
            print("Cannot resume completed download: \(download.fileName)")
            return
        }
        
        if download.state == .downloading && download.task?.state == .running {
            print("Download already running: \(download.fileName)")
            return
        }
        
        // If it's in queue, move it to front
        if let queueIndex = downloadQueue.firstIndex(where: { $0.id == download.id }) {
            downloadQueue.remove(at: queueIndex)
        }
        
        downloadQueue.insert(download, at: 0)
        processQueue()
        saveDownloads()
    }
    
    func pauseDownload(_ download: Download) {
        guard download.state == .downloading else { return }
        
        // Mark as paused and cancel by producing resume data
        download.state = .paused
        (download.task as? URLSessionDownloadTask)?.cancel(byProducingResumeData: { resumeDataOrNil in
            DispatchQueue.main.async {
                download.resumeData = resumeDataOrNil
                download.task = nil
                self.endDownloadBackgroundTask(download)
                self.saveDownloads()
                // Don't call processQueue() here - let user manually resume
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
        download.errorMessage = "Download cancelled by user"
        
        // End background task
        endDownloadBackgroundTask(download)
        
        // Remove from downloads and queue immediately
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
        saveDownloads()
        notifyDownloadsChanged()
    }
    
	func isManualDownload(_ string: String) -> Bool {
		return string.contains("FeatherManualDownload") || string.contains("BabaApp_")
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
    
    // MARK: - Cleanup
    func cleanupCompletedDownloads() {
        let completedDownloads = internalDownloads.filter { $0.isCompleted }
        for download in completedDownloads {
            if let index = internalDownloads.firstIndex(where: { $0.id == download.id }) {
                internalDownloads.remove(at: index)
            }
        }
        saveDownloads()
        notifyDownloadsChanged()
    }
    
    func clearAllDownloads() {
        internalDownloads.removeAll()
        downloadQueue.removeAll()
        saveDownloads()
        notifyDownloadsChanged()
    }
    
    // MARK: - Testing and Debug
    func forceCleanupCompletedDownloads() {
        cleanupCompletedDownloads()
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
	
	func handlePachageFile(url: URL, dl: Download) throws {
		print("Handling package file: \(url.lastPathComponent) for download: \(dl.fileName)")
		
		FR.handlePackageFile(url, download: dl) { err in
			DispatchQueue.main.async {
				if let err = err {
					print("Package file handling failed: \(err.localizedDescription)")
					let generator = UINotificationFeedbackGenerator()
					generator.notificationOccurred(.error)
					
					// Mark as failed instead of removing
					dl.state = .failed
					dl.errorMessage = err.localizedDescription
					dl.isCompleted = false
					
					// End background task
					self.endDownloadBackgroundTask(dl)
					
					// Remove from queue if present
					if let queueIndex = self.downloadQueue.firstIndex(where: { $0.id == dl.id }) {
						self.downloadQueue.remove(at: queueIndex)
					}
					
					// Process queue for next download
					self.processQueue()
					
					self.saveDownloads()
					
					// Auto-remove failed download after 5 seconds
					DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
						if let index = self.internalDownloads.firstIndex(where: { $0.id == dl.id }) {
							self.internalDownloads.remove(at: index)
							self.saveDownloads()
							self.notifyDownloadsChanged()
						}
					}
				} else {
					print("Package file handling completed successfully: \(dl.fileName)")
					// Mark as completed
					dl.isCompleted = true
					dl.state = .completed
					dl.progress = 1.0
					dl.unpackageProgress = 1.0
					dl.errorMessage = nil
					
					// End background task
					self.endDownloadBackgroundTask(dl)
					
					// Notify UI of changes
					self.notifyDownloadsChanged()
					
					// Process queue for next download
					self.processQueue()
					
					let generator = UINotificationFeedbackGenerator()
					generator.notificationOccurred(.success)
					
					self.saveDownloads()
					
					// Auto-remove completed download after 3 seconds
					DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
						if let index = self.internalDownloads.firstIndex(where: { $0.id == dl.id }) {
							self.internalDownloads.remove(at: index)
							self.saveDownloads()
							self.notifyDownloadsChanged()
						}
					}
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
			
			DispatchQueue.main.async {
				download.state = .failed
				download.errorMessage = error.localizedDescription
				download.isCompleted = false
				self.endDownloadBackgroundTask(download)
				self.processQueue()
				self.saveDownloads()
			}
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
            
            // Save progress periodically for large files
            if totalBytesWritten % (1024 * 1024) == 0 { // Every MB
                self.saveDownloads()
            }
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
		
		print("Download task completed with error: \(error.localizedDescription)")
		
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
					download.state = .failed
					download.errorMessage = "Download cancelled"
					self.endDownloadBackgroundTask(download)
					
					if let index = self.getDownloadIndex(by: download.id) {
						self.internalDownloads.remove(at: index)
					}
					// Process queue for next download
					self.processQueue()
					self.saveDownloads()
				}
			case .timedOut, .networkConnectionLost, .notConnectedToInternet:
				// Network errors - keep download and retry
				DispatchQueue.main.async {
					download.state = .waiting
					download.errorMessage = "Network error: \(urlError.localizedDescription)"
					self.endDownloadBackgroundTask(download)
					
					// Add back to queue for retry
					if !self.downloadQueue.contains(where: { $0.id == download.id }) {
						self.downloadQueue.append(download)
					}
					
					self.processQueue()
					self.saveDownloads()
				}
			default:
				// Other errors - mark as failed but keep in list
				DispatchQueue.main.async {
					download.state = .failed
					download.errorMessage = urlError.localizedDescription
					download.isCompleted = false
					self.endDownloadBackgroundTask(download)
					self.processQueue()
					self.saveDownloads()
				}
			}
		} else {
			// Non-URLError - mark as failed
			DispatchQueue.main.async {
				download.state = .failed
				download.errorMessage = error.localizedDescription
				download.isCompleted = false
				self.endDownloadBackgroundTask(download)
				self.processQueue()
				self.saveDownloads()
			}
		}
    }
    
    // MARK: - Background Session Handling
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.endBackgroundTask()
        }
    }
}
