//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
<<<<<<< HEAD
	private let _donationsUrl = "https://github.com/sponsors/khcrysalis"
	private let _githubUrl = "https://github.com/khcrysalis/Feather"
	@AppStorage("Feather.appLanguage") private var _appLanguage: String = "en"
	
	private let _availableLanguages: [(code: String, name: String)] = [
		("en", "English"),
		("fa", "فارسی"),
		("tr", "Türkçe"),
		("id", "Bahasa Indonesia"),
		("vi", "Tiếng Việt")
	]
	
	// MARK: Body
=======
    @State private var _currentIcon: String? = UIApplication.shared.alternateIconName
    
    private let _donationsUrl = "https://github.com/sponsors/khcrysalis"
    private let _githubUrl = "https://github.com/khcrysalis/Feather"
    
    // MARK: Body
>>>>>>> 1ee6940f8d94d8b3ad4ddf1658f995d4b77c7864
    var body: some View {
        NBNavigationView(.localized("Settings")) {
            Form {
				#if !NIGHTLY && !DEBUG
                SettingsDonationCellView(site: _donationsUrl)
				#endif
<<<<<<< HEAD
				
				_feedback()

				Section {
					Picker(.localized("App Language"), systemImage: "globe", selection: $_appLanguage) {
						ForEach(_availableLanguages, id: \.code) { language in
							Text(language.name).tag(language.code)
						}
					}
					.pickerStyle(.navigationLink)
				}
				
				Section {
					NavigationLink(.localized("Appearance"), destination: AppearanceView())
				}
				
				NBSection(.localized("Features")) {
					NavigationLink(.localized("Account"), destination: LoginView())
					NavigationLink(.localized("Certificates"), destination: CertificatesView())
					NavigationLink(.localized("Signing Options"), destination: ConfigurationView())
					NavigationLink(.localized("Archive & Compression"), destination: ArchiveView())
					NavigationLink(.localized("Installation"), destination: InstallationView())
				}
				
				_directories()
=======
                
                _feedback()
                
                Section {
                    NavigationLink(destination: AppearanceView()) {
                        Label(.localized("Appearance"), systemImage: "paintbrush")
                    }
					NavigationLink(destination: AppIconView(currentIcon: $_currentIcon)) {
						Label(.localized("App Icon"), systemImage: "app.badge")
					}
                }
                
                NBSection(.localized("Features")) {
                    NavigationLink(destination: CertificatesView()) {
                        Label(.localized("Certificates"), systemImage: "checkmark.seal")
                    }
                    NavigationLink(destination: ConfigurationView()) {
                        Label(.localized("Signing Options"), systemImage: "signature")
                    }
                    NavigationLink(destination: ArchiveView()) {
                        Label(.localized("Archive & Compression"), systemImage: "archivebox")
                    }
                    NavigationLink(destination: InstallationView()) {
                        Label(.localized("Installation"), systemImage: "arrow.down.circle")
                    }
                } footer: {
                    Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
                }
                
                _directories()
                
                Section {
                    NavigationLink(destination: ResetView()) {
                        Label(.localized("Reset"), systemImage: "trash")
                    }
                } footer: {
                    Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
                }
>>>>>>> 1ee6940f8d94d8b3ad4ddf1658f995d4b77c7864
            }
        }
    }
}

// MARK: - View extension
extension SettingsView {
<<<<<<< HEAD
	@ViewBuilder
	private func _feedback() -> some View {
		Section {
			NavigationLink(.localized("About"), destination: AboutView())
		}
	}
	
	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of Feathers files are contained in the documents directory, here are some quick links to these."))
		}
	}
=======
    @ViewBuilder
    private func _feedback() -> some View {
        Section {
            NavigationLink(destination: AboutView()) {
                Label {
                    Text(verbatim: .localized("About %@", arguments: Bundle.main.name))
                } icon: {
                    Image(uiImage: AppIconView.altImage(_currentIcon))
                        .appIconStyle(size: 23)
                }
            }
            
            Button(.localized("Submit Feedback"), systemImage: "safari") {
				let bugAction: UIAlertAction = .init(title: .localized("Bug Report"), style: .default) { _ in
					UIApplication.open(_makeGitHubIssueURL(url: _githubUrl))
				}
				
				let chooseAction: UIAlertAction = .init(title: .localized("Other"), style: .default) { _ in
					UIApplication.open(URL(string: "\(_githubUrl)/issues/new/choose")!)
				}
				
				UIAlertController.showAlertWithCancel(
					title: .localized("Submit Feedback"),
					message: nil,
					actions: [bugAction, chooseAction]
				)
            }
            Button(.localized("GitHub Repository"), systemImage: "safari") {
                UIApplication.open(_githubUrl)
            }
        } footer: {
            Text(.localized("If any issues occur within the app please report it via the GitHub repository. When submitting an issue, make sure to submit detailed information."))
        }
    }
    
    @ViewBuilder
    private func _directories() -> some View {
        NBSection(.localized("Misc")) {
            Button(.localized("Open Documents"), systemImage: "folder") {
                UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
            }
            Button(.localized("Open Archives"), systemImage: "folder") {
                UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
            }
            Button(.localized("Open Certificates"), systemImage: "folder") {
                UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
            }
        } footer: {
            Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
        }
    }
    
    private func _makeGitHubIssueURL(url: String) -> String {
        var configurationSection = "### App Configuration:\n"
		
        switch UserDefaults.standard.integer(forKey: "Feather.installationMethod") {
        case 0: // Server
            let serverMethod = UserDefaults.standard.integer(forKey: "Feather.serverMethod")
            let ipFix = UserDefaults.standard.bool(forKey: "Feather.ipFix")
            let serverType = (serverMethod == 0) ? "Fully Local" : "Semi Local"
            configurationSection += "- Install method: `Server`\n"
            configurationSection += "  - Server type: `\(serverType)`\n"
            configurationSection += "  - IP Fix: `\(ipFix)`\n"
        case 1: // idevice
            let pairingPath = HeartbeatManager.pairingFile()
            let pairingExists = FileManager.default.fileExists(atPath: pairingPath)
            let pairingStatus = pairingExists ? "`Present`" : "`Not Present`"
            configurationSection += "- Install method: `idevice`\n"
            configurationSection += "  - Pairing file: \(pairingStatus)\n"
        default:
            configurationSection += "- Install method: `Unknown`\n"
        }
        
        let body = """
		### Device Information
		- Device: `\(MobileGestalt().getStringForName("PhysicalHardwareNameString") ?? "Unknown")`
		- iOS Version: `\(UIDevice.current.systemVersion)`
		- App Version: `\(Bundle.main.version)`
		
		\(configurationSection)
		
		### Issue Description
		<!-- Describe your issue here -->
		
		### Steps to Reproduce
		1. 
		2. 
		3. 
		
		### Expected Behavior
		
		### Actual Behavior
		"""
        let encodedTitle = "[Bug] replace this with a descriptive title "
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "\(url)/issues/new?template=bug.yml&title=\(encodedTitle)&text=\(encodedBody)"
    }
>>>>>>> 1ee6940f8d94d8b3ad4ddf1658f995d4b77c7864
}
