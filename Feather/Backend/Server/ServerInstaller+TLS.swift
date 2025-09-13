//
//  Server+TLS.swift
//  feather
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import NIOSSL
import NIOTLS
import Vapor
import UIKit
import SystemConfiguration.CaptiveNetwork

// MARK: - Class extension: TLS/Setup
extension ServerInstaller {
	// MARK: Setup
	static let env: Environment = {
		var env = try! Environment.detect()
		try! LoggingSystem.bootstrap(from: &env)
		return env
	}()
	
	func setupApp(port: Int) throws -> Application {
		let app = Application(Self.env)
		app.threadPool = .init(numberOfThreads: 1)
		
		// Configure TLS if not using fully local server
		if getServerMethod() != 1 {
			do {
				if let tls = try tls() {
					app.http.server.configuration.tlsConfiguration = tls
					print("✅ TLS configuration applied successfully")
				} else {
					print("⚠️ TLS configuration unavailable, falling back to non-TLS mode")
					// Fallback: Show user-friendly error message later
					DispatchQueue.main.async {
						UIAlertController.showAlertWithOk(
							title: "SSL Setup Issue",
							message: "SSL certificates could not be configured. You may need to update SSL certificates manually in Settings → Installation → Server & SSL."
						)
					}
				}
			} catch {
				print("❌ TLS configuration failed: \(error.localizedDescription)")
				// Still continue without TLS to allow basic functionality
				DispatchQueue.main.async {
					UIAlertController.showAlertWithOk(
						title: "SSL Configuration Failed",
						message: "SSL certificates are invalid or corrupted. Please update SSL certificates in Settings → Installation → Server & SSL."
					)
				}
			}
		} else {
			print("✅ Using fully local server mode (no TLS needed)")
		}
		
		app.http.server.configuration.hostname = sni()
		app.http.server.configuration.tcpNoDelay = true
		app.http.server.configuration.address = .hostname("0.0.0.0", port: port)
		app.http.server.configuration.port = port
		app.routes.defaultMaxBodySize = "128mb"
		app.routes.caseInsensitive = false
		
		return app
	}
	
	// MARK: Files/IP
	func sni() -> String {
		let localhost = "127.0.0.1"
		
		if getServerMethod() == 1 {
			return !self.getIPFix()
			? (Self.getLocalAddress() ?? localhost)
			: localhost
		} else {
			return readCommonName() ?? localhost
		}
	}
	
	func tls() throws -> TLSConfiguration? {
		// First, check if certificates exist
		if let crt = Self.getUrl("server", ext: "crt"),
		   let pem = Self.getUrl("server", ext: "pem") {
			// Certificates exist, try to create TLS configuration
			return try TLSConfiguration.makeServerConfiguration(
				certificateChain: NIOSSLCertificate.fromPEMFile(crt.path).map {
					NIOSSLCertificateSource.certificate($0)
				},
				privateKey: .privateKey(
					try NIOSSLPrivateKey(file: pem.path, format: .pem)
				)
			)
		}
		
		// Certificates don't exist, try to download them synchronously
		print("⚠️ SSL certificates not found, attempting to download...")
		
		// Create a synchronous download using a semaphore
		let semaphore = DispatchSemaphore(value: 0)
		var downloadSuccess = false
		
		FR.downloadSSLCertificates(from: "https://backloop.dev/pack.json") { success in
			downloadSuccess = success
			semaphore.signal()
		}
		
		// Wait for download to complete (with timeout)
		let result = semaphore.wait(timeout: .now() + 30) // 30 second timeout
		
		if result == .timedOut {
			print("❌ SSL certificate download timed out")
			return nil
		}
		
		if !downloadSuccess {
			print("❌ SSL certificate download failed")
			return nil
		}
		
		print("✅ SSL certificates downloaded successfully")
		
		// Try again after download
		guard
			let crt = Self.getUrl("server", ext: "crt"),
			let pem = Self.getUrl("server", ext: "pem")
		else {
			print("❌ SSL certificates still not available after download")
			return nil
		}
		
		return try TLSConfiguration.makeServerConfiguration(
			certificateChain: NIOSSLCertificate.fromPEMFile(crt.path).map {
				NIOSSLCertificateSource.certificate($0)
			},
			privateKey: .privateKey(
				try NIOSSLPrivateKey(file: pem.path, format: .pem)
			)
		)
	}
	
	func readCommonName() -> String? {
		guard let url = Self.getUrl("commonName", ext: "txt") else {
			return nil
		}
		
		return try? String(contentsOf: url, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}

extension ServerInstaller {
	static func getUrl(_ name: String, ext: String) -> URL? {
		let fileManager = FileManager.default
		
		let documentsURL = URL.documentsDirectory.appendingPathComponent("\(name).\(ext)")
		if fileManager.fileExists(atPath: documentsURL.path) {
			return documentsURL
		}
		
		return Bundle.main.url(forResource: name, withExtension: ext)
	}
	
	/// Check if SSL certificates are available and valid
	static func areSSLCertificatesAvailable() -> Bool {
		return getUrl("server", ext: "crt") != nil &&
			   getUrl("server", ext: "pem") != nil &&
			   getUrl("commonName", ext: "txt") != nil
	}
	
	/// Get SSL certificate status for diagnostics
	static func getSSLCertificateStatus() -> (crt: Bool, pem: Bool, commonName: Bool) {
		return (
			crt: getUrl("server", ext: "crt") != nil,
			pem: getUrl("server", ext: "pem") != nil,
			commonName: getUrl("commonName", ext: "txt") != nil
		)
	}
	
	static func getLocalAddress() -> String? {
		var address: String?
		var ifaddr: UnsafeMutablePointer<ifaddrs>?
		
		if getifaddrs(&ifaddr) == 0 {
			var ptr = ifaddr
			while ptr != nil {
				let interface = ptr!.pointee
				let addrFamily = interface.ifa_addr.pointee.sa_family
				
				if addrFamily == UInt8(AF_INET) {
					
					let name = String(cString: interface.ifa_name)
					if name == "en0" || name == "pdp_ip0" {
						
						var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
						if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
									   &hostname, socklen_t(hostname.count),
									   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
							address = String(cString: hostname)
						}
						
					}
				}
				ptr = ptr!.pointee.ifa_next
			}
			freeifaddrs(ifaddr)
		}
		
		return address
	}
}
