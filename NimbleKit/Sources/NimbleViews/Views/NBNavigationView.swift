//
//  NavigationViewWrapper.swift
//  Stars
//
//  Created by samara on 7.04.2025.
//

import SwiftUI

public struct NBNavigationView<Content>: View where Content: View {
	private var _title: String
	private var _mode: NavigationBarItem.TitleDisplayMode
	private var _content: Content
	@AppStorage("Feather.appLanguage") private var _appLanguage: String = "en" // Triggers view updates when the language changes
	
	public init(
		_ title: String,
		displayMode: NavigationBarItem.TitleDisplayMode = .automatic,
		@ViewBuilder content: () -> Content
	) {
		self._title = title
		self._mode = displayMode
		self._content = content()
	}
	
	public var body: some View {
		// Whenever the app language stored in AppStorage changes, SwiftUI will re-evaluate this body
		let localizedTitle = String.localized(_title)
		NavigationStack {
			_content
				.navigationTitle(localizedTitle)
				.navigationBarTitleDisplayMode(_mode)
		}
	}
}
