//
//  AuthManager.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation
import UIKit
import Security
import Combine
import OSLog

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUserEmail: String? = nil

    // UserDefaults key for API base URL
    private let apiBaseURLKey = "Feather.apiBaseURL"
    private let logger = Logger(subsystem: "feather.auth", category: "auth")

    // Keychain keys
    private let tokenService = "feather.auth.token"
    private let emailService = "feather.auth.email"

    private init() {
        self.isAuthenticated = (try? KeychainHelper.shared.read(service: tokenService)) != nil
        self.currentUserEmail = try? KeychainHelper.shared.read(service: emailService).flatMap { String(data: $0, encoding: .utf8) }
    }

    @Published private(set) var apiBaseURL: URL = {
        let stored = UserDefaults.standard.string(forKey: "Feather.apiBaseURL")
        if let stored, let url = URL(string: stored) { return url }
        // Default to localhost; user can override in Settings → Server & SSL
        return URL(string: "http://localhost:4000")!
    }()

    func setApiBaseURL(_ urlString: String) {
        UserDefaults.standard.set(urlString, forKey: apiBaseURLKey)
        if let url = URL(string: urlString) {
            self.apiBaseURL = url
        }
    }

    // MARK: - Models
    struct LoginUser: Decodable { let id: Int; let email: String }
    struct LoginResponse: Decodable { let access_token: String; let user: LoginUser }
    struct CertResponse: Decodable { let p12_url: String; let p12_pass: String; let mobileprovision_url: String }
    struct PageBlocksResponse<T: Decodable>: Decodable { let blocks: [T] }
    struct DefaultSourceBlock: Decodable { let url: String; let name: String?; let id: String? }

    // MARK: - Public API
    func login(email: String, password: String, totp: String? = nil) async throws {
        let endpoint = apiBaseURL.appendingPathComponent("api/v1/auth/login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = ["email": email, "password": password, "totp": totp]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 }, options: [])

        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)

        try KeychainHelper.shared.save(data: Data(decoded.access_token.utf8), service: tokenService)
        try KeychainHelper.shared.save(data: Data(decoded.user.email.utf8), service: emailService)

        await MainActor.run {
            self.isAuthenticated = true
            self.currentUserEmail = decoded.user.email
            let alert = UIAlertController(
                title: .localized("ورود موفق"),
                message: .localized("شما وارد حساب خود شدید."),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: .localized("باشه"), style: .default))
            UIApplication.topViewController()?.present(alert, animated: true)
        }

        // Fire-and-forget post-login syncs
        Task {
            // 1) Sync default sources defined by admin
            try? await self.syncDefaultSourcesFromBackend()
            // 2) Try to fetch and install user's certificate pair
            logger.info("Starting certificate fetch after successful login...")
            do {
                try await self.fetchCertificateAndInstall()
                logger.info("Certificate import completed successfully!")
                await MainActor.run {
                    UIAlertController.showAlertWithOk(
                        title: .localized("Certificate Import"),
                        message: .localized("Certificate successfully imported and ready to use!"))
                }
            } catch AuthError.certificateNotFound {
                logger.info("No certificate assigned to user (this is normal)")
                // Silently ignore - user has no certificate assigned
            } catch {
                logger.error("Certificate import failed with error: \(error)")
                await MainActor.run {
                    UIAlertController.showAlertWithOk(
                        title: .localized("Certificate Import Failed"),
                        message: "Error: \(error.localizedDescription)\n\nCheck console logs for details.")
                }
            }
        }
    }

    func logout() {
        try? KeychainHelper.shared.delete(service: tokenService)
        try? KeychainHelper.shared.delete(service: emailService)
        DispatchQueue.main.async { [weak self] in
            self?.isAuthenticated = false
            self?.currentUserEmail = nil
        }
    }

    func fetchCertificateAndInstall() async throws {
        logger.info("Starting certificate fetch and install...")
        
        guard let token = try KeychainHelper.shared.read(service: tokenService) else { 
            logger.error("No auth token found")
            throw AuthError.notAuthenticated 
        }
        let tokenString = String(decoding: token, as: UTF8.self)

        let endpoint = apiBaseURL.appendingPathComponent("api/v1/certs/me")
        logger.info("Requesting certificate from: \(endpoint.absoluteString)")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(tokenString)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { 
            logger.error("Invalid response type")
            throw AuthError.invalidResponse 
        }
        
        logger.info("Certificate response status: \(http.statusCode)")
        
        if http.statusCode == 404 { 
            logger.info("No certificate found for user (404)")
            throw AuthError.certificateNotFound 
        }
        guard (200..<300).contains(http.statusCode) else { 
            logger.error("HTTP error: \(http.statusCode)")
            throw AuthError.httpError(http.statusCode) 
        }

        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.info("Raw certificate response: \(jsonString)")
        }
        
        let certInfo: CertResponse
        do {
            certInfo = try JSONDecoder().decode(CertResponse.self, from: data)
            logger.info("Certificate info decoded - P12: \(certInfo.p12_url), MP: \(certInfo.mobileprovision_url), Pass: ***")
        } catch {
            logger.error("Failed to decode certificate response: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.error("Response was: \(jsonString)")
            }
            throw AuthError.invalidResponse
        }

        // Resolve absolute URLs if backend returns relative paths
        let p12URL = resolveURL(certInfo.p12_url)
        let mpURL  = resolveURL(certInfo.mobileprovision_url)
        
        logger.info("Resolved URLs - P12: \(p12URL.absoluteString), MP: \(mpURL.absoluteString)")

        // Download both files
        logger.info("Starting file downloads...")
        
        // Download files sequentially to ensure proper error handling
        let p12TempURL = try await downloadFile(from: p12URL)
        logger.info("P12 file downloaded to: \(p12TempURL.path)")
        
        let mpTempURL = try await downloadFile(from: mpURL)
        logger.info("Mobileprovision file downloaded to: \(mpTempURL.path)")
        
        logger.info("Both files downloaded successfully")

        // Import certificates directly from temporary files (no persistent saving)
        logger.info("Starting certificate import process...")
        try await robustImportCertificate(
            p12TempURL: p12TempURL,
            mpTempURL: mpTempURL,
            password: certInfo.p12_pass,
            certificateName: self.currentUserEmail ?? "Baba Cert"
        )
        logger.info("Certificate import completed successfully!")
    }

    // MARK: - Helpers
    @MainActor
    private func addDefaultSource(urlString: String, name: String?, id: String?) {
        guard let url = URL(string: urlString) else { return }
        let identifier = id ?? urlString
        Storage.shared.addSource(url, name: name ?? "Unknown", identifier: identifier, iconURL: nil, deferSave: false) { _ in }
    }

    func syncDefaultSourcesFromBackend() async throws {
        // Fetch page blocks at /api/v1/pages/default-sources
        let endpoint = apiBaseURL.appendingPathComponent("api/v1/pages/default-sources")
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
        let page = try JSONDecoder().decode(PageBlocksResponse<DefaultSourceBlock>.self, from: data)
        await MainActor.run {
            for block in page.blocks { self.addDefaultSource(urlString: block.url, name: block.name, id: block.id) }
        }
    }
    private func resolveURL(_ input: String) -> URL {
        logger.info("Resolving URL: \(input)")
        
        // If it's already an absolute URL, normalize localhost -> api host
        if let absolute = URL(string: input), absolute.scheme != nil {
            if let host = absolute.host, ["localhost", "127.0.0.1", "::1"].contains(host) {
                var components = URLComponents(url: absolute, resolvingAgainstBaseURL: false)
                components?.scheme = apiBaseURL.scheme
                components?.host = apiBaseURL.host
                components?.port = apiBaseURL.port
                let rewritten = components?.url ?? absolute
                logger.info("Rewrote localhost URL to: \(rewritten.absoluteString)")
                return rewritten
            }
            logger.info("URL is already absolute: \(absolute.absoluteString)")
            return absolute
        }
        
        // Handle relative paths - combine with base URL
        let baseURLString = apiBaseURL.absoluteString
        
        // Remove /api/v1 from base URL if present to get server root
        let serverRoot = baseURLString.replacingOccurrences(of: "/api/v1", with: "")
                                      .replacingOccurrences(of: "/api", with: "")
        
        // Ensure path starts with /
        var path = input
        if !path.hasPrefix("/") { 
            path = "/" + path 
        }
        
        // Combine server root with path
        let fullURLString = serverRoot.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path
        
        if let url = URL(string: fullURLString) {
            logger.info("Resolved URL to: \(url.absoluteString)")
            return url
        }
        
        logger.error("Failed to resolve URL, falling back to base URL")
        return apiBaseURL
    }
    private func downloadFile(from url: URL) async throws -> URL {
        logger.info("Downloading file from: \(url.absoluteString)")
        
        // Try with authentication token if it's an API endpoint
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Add auth token if available
        if let token = try? KeychainHelper.shared.read(service: tokenService) {
            let tokenString = String(decoding: token, as: UTF8.self)
            request.setValue("Bearer \(tokenString)", forHTTPHeaderField: "Authorization")
            logger.info("Added auth token to download request")
        }
        
        do {
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                logger.error("Invalid response type for download")
                throw AuthError.downloadFailed
            }
            
            logger.info("Download response status: \(http.statusCode)")
            
            guard (200..<300).contains(http.statusCode) else {
                logger.error("Download failed with HTTP status: \(http.statusCode)")
                throw AuthError.downloadFailed
            }
            
            // Check file size
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            logger.info("Downloaded file size: \(fileSize) bytes")
            
            // Move to a unique temp file with original filename if available
            let fileName = url.lastPathComponent.isEmpty ? UUID().uuidString : url.lastPathComponent
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("feather_\(UUID().uuidString)_\(fileName)")
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: tempURL, to: destination)
            
            logger.info("File downloaded and moved to: \(destination.path)")
            return destination
        } catch {
            logger.error("Download failed with error: \(error)")
            throw error
        }
    }



    // MARK: - Robust Certificate Import
    private func robustImportCertificate(p12TempURL: URL, mpTempURL: URL, password: String, certificateName: String) async throws {
        logger.info("Starting robust certificate import...")
        logger.info("P12 file exists: \(FileManager.default.fileExists(atPath: p12TempURL.path))")
        logger.info("MP file exists: \(FileManager.default.fileExists(atPath: mpTempURL.path))")
        
        // 1) Validate password against files before import
        logger.info("Validating P12 password...")
        let isPasswordValid = FR.checkPasswordForCertificate(for: p12TempURL, with: password, using: mpTempURL)
        if !isPasswordValid {
            logger.error("P12 password validation failed!")
            logger.error("P12 path: \(p12TempURL.path)")
            logger.error("MP path: \(mpTempURL.path)")
            throw AuthError.downloadFailed
        }
        logger.info("P12 password validation passed ✓")

        // 2) Try direct import with retries
        logger.info("Attempting direct certificate import...")
        let maxAttempts = 2
        for attempt in 1...maxAttempts {
            logger.info("Import attempt \(attempt)/\(maxAttempts)")
            let result = await withCheckedContinuation { continuation in
                FR.handleCertificateFiles(
                    p12URL: p12TempURL,
                    provisionURL: mpTempURL,
                    p12Password: password,
                    certificateName: certificateName
                ) { error in
                    continuation.resume(returning: error)
                }
            }
            
            if let error = result {
                logger.error("Import attempt \(attempt) failed with error: \(error.localizedDescription)")
            } else {
                logger.info("Import attempt \(attempt) completed without error")
                // Verify import actually exists
                let certCount = Storage.shared.getAllCertificates().count
                logger.info("Certificate count after import: \(certCount)")
                if certCount > 0 {
                    logger.info("Certificate successfully imported via direct method!")
                    return
                }
            }
            // Small delay before retry if failed
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        logger.warning("Direct import failed, trying fallback methods...")

        // 3) Fallback: internal URL scheme with base64 payload
        logger.info("Trying URL scheme fallback...")
        do {
            let p12Data = try Data(contentsOf: p12TempURL)
            let mpData  = try Data(contentsOf: mpTempURL)
            let p12b64 = p12Data.base64EncodedString()
            let mpb64  = mpData.base64EncodedString()
            let passb64 = Data(password.utf8).base64EncodedString()

            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: ";/?:@&=+$, ")
            let enc = { (s: String) -> String in s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }

            let urlStr = "feather://import-certificate?p12=\(enc(p12b64))&mobileprovision=\(enc(mpb64))&password=\(enc(passb64))"
            if let url = URL(string: urlStr) {
                logger.info("Opening URL scheme: \(urlStr.prefix(100))...")
                await MainActor.run { UIApplication.shared.open(url) }
            }

            // Poll for up to ~5s to see certificate appears
            logger.info("Polling for certificate import via URL scheme...")
            for i in 0..<10 {
                let certCount = Storage.shared.getAllCertificates().count
                if certCount > 0 { 
                    logger.info("Certificate imported via URL scheme after \(i * 500)ms!")
                    return 
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            logger.warning("URL scheme fallback timed out")
        } catch {
            logger.error("URL scheme fallback failed: \(error.localizedDescription)")
        }

        // 4) Final fallback: if all methods fail, throw error
        logger.error("All certificate import methods failed")
        throw AuthError.downloadFailed
    }
}

// MARK: - Keychain
final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save(data: Data, service: String) throws {
        try delete(service: service)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func read(service: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
        return (item as? Data)
    }

    func delete(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors
enum AuthError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case notAuthenticated
    case downloadFailed
    case certificateNotFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response."
        case .httpError(let code): return "Server error (\(code))."
        case .notAuthenticated: return "You are not logged in."
        case .downloadFailed: return "Failed to download certificate files."
        case .certificateNotFound: return "No certificate assigned to this user."
        }
    }
}

enum KeychainError: Error { case unhandled(OSStatus) }


