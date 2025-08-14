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
					Button(action: { _showCertificateFiles() }) {
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
	
	private func _showCertificateFiles() {
		// Show certificate files in the app's Documents directory
		let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let certificatesDir = documentsURL.appendingPathComponent("Certificates", isDirectory: true)
		
		var message = "Certificate files location:\n\n"
		message += "Path: Files app → On My iPhone → Baba App → Certificates\n"
		message += "Directory: \(certificatesDir.path)\n\n"
		
		// Check if directory exists and list files
		if let files = try? FileManager.default.contentsOfDirectory(at: certificatesDir, includingPropertiesForKeys: [.fileSizeKey]) {
			if files.isEmpty {
				message += "No certificate files found.\n\n"
			} else {
				message += "Files found:\n"
				for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
					let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
					let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
					message += "• \(file.lastPathComponent) (\(sizeStr))\n"
				}
				message += "\n"
			}
		} else {
			message += "Directory not found. It will be created when needed.\n\n"
		}
		
		message += "Note: This folder is for manually imported certificate files only. Certificates downloaded from the server are imported directly without being saved here."
		
		UIAlertController.showAlertWithOk(
			title: "Certificate Files",
			message: message
		)
	}

}
