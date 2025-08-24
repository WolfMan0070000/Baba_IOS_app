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
	// MARK: Body
    var body: some View {
        NBList(.localized("About Baba Apps")) {
				Section {
					VStack {
                        Image(uiImage: AppIconView.altImage(UIApplication.shared.alternateIconName))
							.appIconStyle(size: 72)
                        Text(.localized("Baba Apps"))
							.font(.largeTitle)
							.bold()
                            .foregroundStyle(Color.accentColor)
						
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
			}
		}
	}

