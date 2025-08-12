//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - View
struct AboutView: View {
	typealias CreditsDataHandler = Result<[CreditsModel], Error>
	private let _dataService = NBFetchService()
	
	@State private var _credits: [CreditsModel] = []
	@State private var _donators: [CreditsModel] = []
	@State var isLoading = true
	
	private let _creditsUrl = "https://raw.githubusercontent.com/khcrysalis/project-credits/refs/heads/main/feather/creditsv2.json"
	private let _donatorsUrl = "https://raw.githubusercontent.com/khcrysalis/project-credits/refs/heads/main/sponsors/credits.json"
	
	// MARK: Body
	var body: some View {
		NBList(.localized("About Baba App")) {
            Section {
                VStack {
                    Image(uiImage: (UIImage(named: Bundle.main.iconFileName ?? ""))! )
                        .appIconStyle(size: 72)
                    
                    Text("Baba App")
                        .font(.largeTitle)
                        .bold()
                        .foregroundStyle(.accent)
                    
                    HStack(spacing: 4) {
						Text(.localized("Version"))
                        Text(Bundle.main.version)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(EmptyView())
            
            Section {
                Text("Hello, test")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
	}
	
	private func _fetchAllData() async {
		await withTaskGroup(of: (String, CreditsDataHandler).self) { group in
			group.addTask { return await _fetchCredits(self._creditsUrl, using: _dataService) }
			group.addTask { return await _fetchCredits(self._donatorsUrl, using: _dataService) }
			
			for await (type, result) in group {
				await MainActor.run {
					switch result {
					case .success(let data):
						if type == "credits" {
							self._credits = data
						} else {
							self._donators = data
						}
					case .failure(_): break
					}
				}
			}
		}
		
		await MainActor.run {
			isLoading = false
		}
	}
	
	private func _fetchCredits(_ urlString: String, using service: NBFetchService) async -> (String, CreditsDataHandler) {
		let type = urlString == _creditsUrl 
		? "credits"
		: "donators"
		
		return await withCheckedContinuation { continuation in
			service.fetch(from: urlString) { (result: CreditsDataHandler) in
				continuation.resume(returning: (type, result))
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		Button {
			UIApplication.open("https://github.com/\(github)")
		} label: {
			NBTitleWithSubtitleView(
				title: name ?? github,
				subtitle: desc ?? "",
				linelimit: 0
			)
		}
	}
}
