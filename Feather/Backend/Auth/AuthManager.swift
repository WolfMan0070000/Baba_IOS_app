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

    var apiBaseURL: URL {
        let stored = UserDefaults.standard.string(forKey: apiBaseURLKey)
        if let stored, let url = URL(string: stored) { return url }
        // Default to localhost; user can override in Settings → Server & SSL
        return URL(string: "http://localhost:4000")!
    }

    func setApiBaseURL(_ urlString: String) {
        UserDefaults.standard.set(urlString, forKey: apiBaseURLKey)
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
            try? await self.fetchCertificateAndInstall()
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
        guard let token = try KeychainHelper.shared.read(service: tokenService) else { throw AuthError.notAuthenticated }
        let tokenString = String(decoding: token, as: UTF8.self)

        let endpoint = apiBaseURL.appendingPathComponent("api/v1/certs/me")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(tokenString)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        if http.statusCode == 404 { throw AuthError.certificateNotFound }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.httpError(http.statusCode) }

        let certInfo = try JSONDecoder().decode(CertResponse.self, from: data)

        // Resolve absolute URLs if backend returns relative paths
        let p12URL = resolveURL(certInfo.p12_url)
        let mpURL  = resolveURL(certInfo.mobileprovision_url)

        // Download both files
        let (p12TempURL, mpTempURL) = try await (
            downloadFile(from: p12URL),
            downloadFile(from: mpURL)
        )

        // Persist downloads into app Documents before import
        let (p12LocalURL, mpLocalURL) = try persistDownloadedCertificateFiles(p12TempURL: p12TempURL, mpTempURL: mpTempURL)

        // Robust import with verification and fallbacks using locally persisted files
        try await robustImportCertificate(
            p12TempURL: p12LocalURL,
            mpTempURL: mpLocalURL,
            password: certInfo.p12_pass,
            certificateName: self.currentUserEmail ?? "Baba Cert"
        )
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
        if let absolute = URL(string: input), absolute.scheme != nil { return absolute }
        // Build origin from base URL
        var components = URLComponents()
        components.scheme = apiBaseURL.scheme
        components.host = apiBaseURL.host
        components.port = apiBaseURL.port
        var path = input
        if !path.hasPrefix("/") { path = "/" + path }
        components.path = path
        return components.url ?? apiBaseURL
    }
    private func downloadFile(from url: URL) async throws -> URL {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.downloadFailed
        }
        // Move to a unique temp file with original filename if available
        let fileName = url.lastPathComponent.isEmpty ? UUID().uuidString : url.lastPathComponent
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("feather_\(UUID().uuidString)_\(fileName)")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private func persistDownloadedCertificateFiles(p12TempURL: URL, mpTempURL: URL) throws -> (URL, URL) {
        let docs = URL.documentsDirectory
        let downloadsDir = docs.appendingPathComponent("Downloads/Certificates", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let p12Dest = downloadsDir.appendingPathComponent("p12_\(UUID().uuidString)_\(p12TempURL.lastPathComponent.isEmpty ? "cert.p12" : p12TempURL.lastPathComponent)")
        let mpDest  = downloadsDir.appendingPathComponent("prov_\(UUID().uuidString)_\(mpTempURL.lastPathComponent.isEmpty ? "profile.mobileprovision" : mpTempURL.lastPathComponent)")
        // Overwrite if exists
        try? FileManager.default.removeItem(at: p12Dest)
        try? FileManager.default.removeItem(at: mpDest)
        try FileManager.default.copyItem(at: p12TempURL, to: p12Dest)
        try FileManager.default.copyItem(at: mpTempURL, to: mpDest)
        return (p12Dest, mpDest)
    }

    // MARK: - Robust Certificate Import
    private func robustImportCertificate(p12TempURL: URL, mpTempURL: URL, password: String, certificateName: String) async throws {
        // 1) Validate password against files before import
        let isPasswordValid = FR.checkPasswordForCertificate(for: p12TempURL, with: password, using: mpTempURL)
        if !isPasswordValid {
            throw AuthError.downloadFailed
        }

        // 2) Try direct import with retries
        let maxAttempts = 2
        for attempt in 1...maxAttempts {
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
            if result == nil {
                // Verify import actually exists
                if Storage.shared.getAllCertificates().isEmpty == false {
                    return
                }
            }
            // Small delay before retry if failed
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        // 3) Fallback: internal URL scheme with base64 payload
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
                await MainActor.run { UIApplication.shared.open(url) }
            }

            // Poll for up to ~5s to see certificate appears
            for _ in 0..<10 {
                if Storage.shared.getAllCertificates().isEmpty == false { return }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        } catch {
            // Ignore and continue to final fallback
        }

        // 4) Final fallback: persist pending files for manual import
        do {
            let docs = URL.documentsDirectory
            let pendingDir = docs.appendingPathComponent("PendingCertificates", isDirectory: true)
            try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
            let destP12 = pendingDir.appendingPathComponent("cert_\(UUID().uuidString).p12")
            let destMP  = pendingDir.appendingPathComponent("provision_\(UUID().uuidString).mobileprovision")
            try? FileManager.default.removeItem(at: destP12)
            try? FileManager.default.removeItem(at: destMP)
            try FileManager.default.copyItem(at: p12TempURL, to: destP12)
            try FileManager.default.copyItem(at: mpTempURL, to: destMP)
            await MainActor.run {
                UIAlertController.showAlertWithOk(
                    title: .localized("Certificate Saved"),
                    message: .localized("We saved the certificate files locally. Please import from Settings → Certificates."))
            }
        } catch {
            await MainActor.run {
                UIAlertController.showAlertWithOk(
                    title: .localized("Import Failed"),
                    message: .localized("We couldn't import your certificate. Please try again."))
            }
        }
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


