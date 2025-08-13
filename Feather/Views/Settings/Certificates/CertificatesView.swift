//
//  CertificatesView.swift
//  Feather
//
//  Created by samara on 15.04.2025.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct CertificatesView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	
	@State private var _isAddingPresenting = false
	@State private var _isSelectedInfoPresenting: CertificatePair?
	@State private var _showPendingImport = false

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>
	
	//
	private var _bindingSelectedCert: Binding<Int>?
	private var _selectedCertBinding: Binding<Int> {
		_bindingSelectedCert ?? $_storedSelectedCert
	}
	
	init(selectedCert: Binding<Int>? = nil) {
		self._bindingSelectedCert = selectedCert
	}
	
	// MARK: Body
	var body: some View {
		NBGrid {
			ForEach(Array(_certificates.enumerated()), id: \.element.uuid) { index, cert in
				_cellButton(for: cert, at: index)
			}
		}
		.navigationTitle(.localized("Certificates"))
		.overlay {
			if _certificates.isEmpty {
				if #available(iOS 17, *) {
					ContentUnavailableView {
						Label(.localized("No Certificates"), systemImage: "questionmark.folder.fill")
					} description: {
						Text(.localized("Get started signing by importing your first certificate."))
					} actions: {
						Button {
							_isAddingPresenting = true
						} label: {
							NBButton(.localized("Import"), style: .text)
						}
					}
				}
			}
		}
		.toolbar {
			if _bindingSelectedCert == nil {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: { _checkForPendingImport() }) {
						Image(systemName: "arrow.down.circle")
					}
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: { _showDownloadedFiles() }) {
						Image(systemName: "folder")
					}
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: { _isAddingPresenting = true }) {
						Image(systemName: "plus")
					}
				}
			}
		}
		.sheet(item: $_isSelectedInfoPresenting) { cert in
			CertificatesInfoView(cert: cert)
		}
		.sheet(isPresented: $_isAddingPresenting) {
			CertificatesAddView()
				.presentationDetents([.medium])
		}
	}
}

// MARK: - View extension
extension CertificatesView {
	@ViewBuilder
	private func _cellButton(for cert: CertificatePair, at index: Int) -> some View {
		Button {
			_selectedCertBinding.wrappedValue = index
		} label: {
			CertificatesCellView(
				cert: cert
			)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 10.5)
					.fill(Color(uiColor: .quaternarySystemFill))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 10.5)
					.strokeBorder(
						_selectedCertBinding.wrappedValue == index ? Color.accentColor : Color.clear,
						lineWidth: 2
					)
			)
			.contextMenu {
				_contextActions(for: cert)
				Divider()
				_actions(for: cert)
			}
			.transaction {
				$0.animation = nil
			}
		}
		.buttonStyle(.plain)
	}
	
	@ViewBuilder
	private func _actions(for cert: CertificatePair) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteCertificate(for: cert)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for cert: CertificatePair) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			_isSelectedInfoPresenting = cert
		}
		Divider()
		Button(.localized("Check Revokage"), systemImage: "person.text.rectangle") {
			Storage.shared.revokagedCertificate(for: cert)
		}
	}
	
	private func _checkForPendingImport() {
		// Check if there are pending certificate files to import
		guard let p12Path = UserDefaults.standard.string(forKey: "pendingCertP12Path"),
			  let mpPath = UserDefaults.standard.string(forKey: "pendingCertMPPath"),
			  let password = UserDefaults.standard.string(forKey: "pendingCertPassword"),
			  let name = UserDefaults.standard.string(forKey: "pendingCertName") else {
			
			UIAlertController.showAlertWithOk(
				title: "No Pending Certificate",
				message: "No certificate is waiting to be imported. Certificates will appear here automatically after login."
			)
			return
		}
		
		let p12URL = URL(fileURLWithPath: p12Path)
		let mpURL = URL(fileURLWithPath: mpPath)
		
		// Check if files still exist
		guard FileManager.default.fileExists(atPath: p12Path),
			  FileManager.default.fileExists(atPath: mpPath) else {
			// Clear invalid pending data
			UserDefaults.standard.removeObject(forKey: "pendingCertP12Path")
			UserDefaults.standard.removeObject(forKey: "pendingCertMPPath")
			UserDefaults.standard.removeObject(forKey: "pendingCertPassword")
			UserDefaults.standard.removeObject(forKey: "pendingCertName")
			
			UIAlertController.showAlertWithOk(
				title: "Files Not Found",
				message: "The certificate files are no longer available. Please login again to download them."
			)
			return
		}
		
		// Show import confirmation
		let alert = UIAlertController(
			title: "Import Certificate",
			message: "Found a certificate ready to import:\n\nName: \(name)\nP12: \(p12URL.lastPathComponent)\nProvision: \(mpURL.lastPathComponent)",
			preferredStyle: .alert
		)
		
		alert.addAction(UIAlertAction(title: "Import", style: .default) { _ in
			// Try to import
			FR.handleCertificateFiles(
				p12URL: p12URL,
				provisionURL: mpURL,
				p12Password: password,
				certificateName: name
			) { error in
				if let error = error {
					UIAlertController.showAlertWithOk(
						title: "Import Failed",
						message: "Error: \(error.localizedDescription)"
					)
				} else {
					// Clear pending data on success
					UserDefaults.standard.removeObject(forKey: "pendingCertP12Path")
					UserDefaults.standard.removeObject(forKey: "pendingCertMPPath")
					UserDefaults.standard.removeObject(forKey: "pendingCertPassword")
					UserDefaults.standard.removeObject(forKey: "pendingCertName")
					
					UIAlertController.showAlertWithOk(
						title: "Success",
						message: "Certificate imported successfully!"
					)
				}
			}
		})
		
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		
		if let topVC = UIApplication.shared.windows.first?.rootViewController {
			topVC.present(alert, animated: true)
		}
	}
	
	private func _showDownloadedFiles() {
		// Check shared Documents/Certificates directory (visible in Files app as "Baba App/Certificates")
		let sharedDocsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let certificatesDir = sharedDocsURL.appendingPathComponent("Certificates", isDirectory: true)
		
		var message = "Certificate files in Baba App folder:\n\n"
		message += "Location: Files app → On My iPhone → Baba App → Certificates\n"
		message += "Path: \(certificatesDir.path)\n\n"
		
		// Check shared certificates directory
		if let files = try? FileManager.default.contentsOfDirectory(at: certificatesDir, includingPropertiesForKeys: nil) {
			let downloadedFiles = files.filter { $0.lastPathComponent.hasPrefix("downloaded_") }
			let otherFiles = files.filter { !$0.lastPathComponent.hasPrefix("downloaded_") }
			
			if downloadedFiles.isEmpty && otherFiles.isEmpty {
				message += "No files found\n"
			} else {
				if !downloadedFiles.isEmpty {
					message += "Downloaded certificate files:\n"
					for file in downloadedFiles.prefix(5) {
						let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
						let sizeStr = size > 1024 ? "\(size/1024) KB" : "\(size) bytes"
						message += "• \(file.lastPathComponent) (\(sizeStr))\n"
					}
					if downloadedFiles.count > 5 {
						message += "• ... and \(downloadedFiles.count - 5) more\n"
					}
					message += "\n"
				}
				
				if !otherFiles.isEmpty {
					message += "Other files:\n"
					for file in otherFiles.prefix(3) {
						message += "• \(file.lastPathComponent)\n"
					}
					if otherFiles.count > 3 {
						message += "• ... and \(otherFiles.count - 3) more\n"
					}
				}
			}
		} else {
			message += "Directory not found - will be created when certificates are downloaded\n"
		}
		
		message += "\nTip: You can also access these files through the Files app on your device."
		
		UIAlertController.showAlertWithOk(
			title: "Certificate Files Location",
			message: message
		)
	}
}
