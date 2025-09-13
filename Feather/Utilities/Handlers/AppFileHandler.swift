//
//  IPAHandler.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation
import Zip
import SwiftUI
import OSLog

final class AppFileHandler: NSObject, @unchecked Sendable {
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private let _uniqueWorkDir: URL
	var uniqueWorkDirPayload: URL?

	private var _ipa: URL
	private let _install: Bool
	private let _download: Download?
	
	init(
		file ipa: URL,
		install: Bool = false,
		download: Download? = nil
	) {
		self._ipa = ipa
		self._install = install
		self._download = download
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherImport_\(_uuid)", isDirectory: true)
		
		super.init()
		Logger.misc.debug("Import initiated for: \(self._ipa.lastPathComponent) with ID: \(self._uuid)")
	}
	
	func copy() async throws {
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
		
		let destinationURL = _uniqueWorkDir.appendingPathComponent(_ipa.lastPathComponent)

		try _fileManager.removeFileIfNeeded(at: destinationURL)
		
		try _fileManager.copyItem(at: _ipa, to: destinationURL)
		_ipa = destinationURL
		Logger.misc.info("[\(self._uuid)] File copied to: \(self._ipa.path)")
	}
	
	func extract() async throws {
		if _ipa.pathExtension == "ipa" {
			Zip.addCustomFileExtension("ipa")
		}
		if _ipa.pathExtension == "tipa" {
			Zip.addCustomFileExtension("tipa")
		}
		
		let download = self._download
		
		// Validate file integrity before extraction
		try await validateFileIntegrity()
		
		// Ensure sufficient disk space
		try await ensureSufficientDiskSpace()
		
		// Attempt extraction with retry mechanism
		try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				self.performExtractionWithRetry(download: download) { result in
					switch result {
					case .success:
						self.uniqueWorkDirPayload = self._uniqueWorkDir.appendingPathComponent("Payload")
						continuation.resume()
					case .failure(let error):
						continuation.resume(throwing: error)
					}
				}
			}
		}
	}
	
	private func validateFileIntegrity() async throws {
		let fileManager = FileManager.default
		
		// Check if file exists and is readable
		guard fileManager.fileExists(atPath: _ipa.path) && fileManager.isReadableFile(atPath: _ipa.path) else {
			throw ImportedFileHandlerError.corruptedFile
		}
		
		// Get file size for validation
		let attributes = try fileManager.attributesOfItem(atPath: _ipa.path)
		let fileSize = attributes[.size] as? Int64 ?? 0
		
		// Only reject truly empty files (0 bytes) - allow small files as they might be valid
		if fileSize == 0 {
			throw ImportedFileHandlerError.corruptedFile
		}
		
		// For very small files (< 1KB), perform basic ZIP header validation if it's an IPA/TIPA
		if fileSize < 1024 && (_ipa.pathExtension.lowercased() == "ipa" || _ipa.pathExtension.lowercased() == "tipa") {
			// Only validate ZIP header if file is supposed to be a ZIP but is suspiciously small
			do {
				try validateZipHeader()
			} catch {
				// If ZIP validation fails on a small file, it's likely corrupted
				throw ImportedFileHandlerError.corruptedFile
			}
		} else if fileSize >= 1024 {
			// For larger files, do a lenient ZIP header check for IPA/TIPA files only
			if _ipa.pathExtension.lowercased() == "ipa" || _ipa.pathExtension.lowercased() == "tipa" {
				do {
					try validateZipHeaderLenient()
				} catch {
					// Log the error but don't fail the entire process for large files
					Logger.misc.warning("[\(self._uuid)] ZIP header validation failed, but proceeding with large file: \(error.localizedDescription)")
				}
			}
		}
		
		Logger.misc.info("[\(self._uuid)] File integrity validation passed for: \(self._ipa.lastPathComponent) (\(fileSize) bytes)")
	}
	
	private func validateZipHeader() throws {
		let fileHandle = try FileHandle(forReadingFrom: _ipa)
		defer { 
			try? fileHandle.close()
		}
		
		let headerData = fileHandle.readData(ofLength: 4)
		
		// ZIP files should start with "PK" (0x504B)
		if headerData.count < 2 {
			throw ImportedFileHandlerError.corruptedFile
		}
		
		let zipHeader = Data([0x50, 0x4B]) // "PK" signature
		if !headerData.starts(with: zipHeader) {
			throw ImportedFileHandlerError.corruptedFile
		}
	}
	
	private func validateZipHeaderLenient() throws {
		// Lenient validation that doesn't fail on edge cases
		guard let fileHandle = try? FileHandle(forReadingFrom: _ipa) else {
			// If we can't open the file for reading, that's a problem
			throw ImportedFileHandlerError.corruptedFile
		}
		
		defer { 
			try? fileHandle.close()
		}
		
		// Try to read ZIP header, but be more forgiving
		let headerData = fileHandle.readData(ofLength: 8)
		
		if headerData.count >= 2 {
			let zipHeader = Data([0x50, 0x4B]) // "PK" signature
			if !headerData.starts(with: zipHeader) {
				// Check if it might be a different but valid archive format
				// Don't throw error for large files - let the extraction process handle it
				Logger.misc.info("[\(self._uuid)] File doesn't have standard ZIP header, but proceeding with extraction")
			}
		}
		// If we can't read enough data, still proceed - the extraction will catch real corruption
	}
	
	private func ensureSufficientDiskSpace() async throws {
		let fileManager = FileManager.default
		
		// Get file size
		let attributes = try fileManager.attributesOfItem(atPath: _ipa.path)
		let fileSize = attributes[.size] as? Int64 ?? 0
		
		// Get available disk space
		let tempDir = fileManager.temporaryDirectory
		let resourceValues = try tempDir.resourceValues(forKeys: [.volumeAvailableCapacityKey])
		let availableSpace = resourceValues.volumeAvailableCapacity ?? 0
		
		// Require at least 3x file size for extraction (original + extracted + working space)
		let requiredSpace = fileSize * 3
		
		if Int64(availableSpace) < requiredSpace {
			Logger.misc.error("[\(self._uuid)] Insufficient disk space. Required: \(requiredSpace), Available: \(availableSpace)")
			throw ImportedFileHandlerError.insufficientDiskSpace
		}
		
		Logger.misc.info("[\(self._uuid)] Disk space check passed. Available: \(availableSpace), Required: \(requiredSpace)")
	}
	
	private func performExtractionWithRetry(download: Download?, completion: @escaping (Result<Void, Error>) -> Void) {
		let maxRetries = 3
		var attemptCount = 0
		
		func attemptExtraction() {
			attemptCount += 1
			
			do {
				// Clear any previous extraction attempts
				if attemptCount > 1 {
					try? self._fileManager.removeItem(at: self._uniqueWorkDir.appendingPathComponent("Payload"))
					Logger.misc.info("[\(self._uuid)] Retry attempt \(attemptCount) for extraction")
				}
				
				try Zip.unzipFile(
					self._ipa,
					destination: self._uniqueWorkDir,
					overwrite: true,
					password: nil,
					progress: { progress in
						if let download = download {
							DispatchQueue.main.async {
								download.unpackageProgress = progress
							}
						}
					}
				)
				
				// Validate extraction was successful
				let payloadPath = self._uniqueWorkDir.appendingPathComponent("Payload")
				if self._fileManager.fileExists(atPath: payloadPath.path) {
					Logger.misc.info("[\(self._uuid)] Extraction successful on attempt \(attemptCount)")
					completion(.success(()))
				} else {
					throw ImportedFileHandlerError.extractionFailed
				}
				
			} catch {
				Logger.misc.error("[\(self._uuid)] Extraction failed on attempt \(attemptCount): \(error.localizedDescription)")
				
				if attemptCount < maxRetries {
					// Wait before retry with exponential backoff
					let delay = pow(2.0, Double(attemptCount - 1))
					DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
						attemptExtraction()
					}
				} else {
					// All retries exhausted
					completion(.failure(ImportedFileHandlerError.extractionFailed))
				}
			}
		}
		
		attemptExtraction()
	}
	
	func move() async throws {
		guard let payloadURL = uniqueWorkDirPayload else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		let destinationURL = try await _directory()
		
		guard _fileManager.fileExists(atPath: payloadURL.path) else {
			throw ImportedFileHandlerError.payloadNotFound
		}
		
		try _fileManager.moveItem(at: payloadURL, to: destinationURL)
		Logger.misc.info("[\(self._uuid)] Moved Payload to: \(destinationURL.path)")
		
		try? _fileManager.removeItem(at: _uniqueWorkDir)
	}
	
	func addToDatabase() async throws {
		let app = try await _directory()
		
		guard let appUrl = _fileManager.getPath(in: app, for: "app") else {
			return
		}
		
		let bundle = Bundle(url: appUrl)
		
		Storage.shared.addImported(
			uuid: _uuid,
			appName: bundle?.name,
			appIdentifier: bundle?.bundleIdentifier,
			appVersion: bundle?.version,
			appIcon: bundle?.iconFileName
		) { _ in
			Logger.misc.info("[\(self._uuid)] Added to database")
		}
	}
	
	private func _directory() async throws -> URL {
		// Documents/Feather/Unsigned/\(UUID)
		_fileManager.unsigned(_uuid)
	}
	
	func clean() async throws {
		// Clean up temporary files and directories
		try _fileManager.removeFileIfNeeded(at: _uniqueWorkDir)
		
		// Additional cleanup for large file handling
		cleanupTempFilesInBackground()
	}
	
	private func cleanupTempFilesInBackground() {
		Task.detached(priority: .background) {
			let tempDir = FileManager.default.temporaryDirectory
			let featherTempDirs = ["FeatherImport_", "FeatherDownloads", "FeatherInstall_"]
			
			do {
				let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
				
				for url in contents {
					let name = url.lastPathComponent
					if featherTempDirs.contains(where: { name.hasPrefix($0) }) {
						// Check if directory is older than 1 hour
						if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
						   Date().timeIntervalSince(creationDate) > 3600 {
							try? FileManager.default.removeItem(at: url)
							print("Cleaned up old temp directory: \(name)")
						}
					}
				}
			} catch {
				print("Error during temp cleanup: \(error.localizedDescription)")
			}
		}
	}
}

private enum ImportedFileHandlerError: Error, LocalizedError {
	case payloadNotFound
	case corruptedFile
	case insufficientDiskSpace
	case extractionFailed
	
	var errorDescription: String? {
		switch self {
		case .payloadNotFound:
			return "Payload directory not found after extraction"
		case .corruptedFile:
			return "Downloaded file appears to be corrupted"
		case .insufficientDiskSpace:
			return "Insufficient disk space for extraction"
		case .extractionFailed:
			return "Failed to extract archive after multiple attempts"
		}
	}
}
