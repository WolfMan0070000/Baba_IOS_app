//
//  AuthManager.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import Foundation
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

    // MARK: - Public API
    func login(email: String, password: String, totp: String? = nil) async throws {
        let endpoint = apiBaseURL.appendingPathComponent("api/v1/auth/login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any?] = ["email": email, "password": password, "totp": totp]
        request.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 }, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AuthError.httpError(http.statusCode) }

        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)

        try KeychainHelper.shared.save(data: Data(decoded.access_token.utf8), service: tokenService)
        try KeychainHelper.shared.save(data: Data(decoded.user.email.utf8), service: emailService)

        await MainActor.run {
            self.isAuthenticated = true
            self.currentUserEmail = decoded.user.email
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

        // Install into app storage
        await withCheckedContinuation { continuation in
            FR.handleCertificateFiles(
                p12URL: p12TempURL,
                provisionURL: mpTempURL,
                p12Password: certInfo.p12_pass,
                certificateName: self.currentUserEmail ?? "Baba Cert"
            ) { _ in
                continuation.resume()
            }
        }
    }

    // MARK: - Helpers
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


