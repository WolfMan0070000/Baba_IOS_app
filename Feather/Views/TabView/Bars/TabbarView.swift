//
//  TabbarView.swift
//  feather
//
//  Created by samara on 23.03.2025.
//

import SwiftUI

struct TabbarView: View {
	@AppStorage("Feather.appLanguage") private var _appLanguage: String = "en" // observe language changes
	@State private var selectedTab: TabEnum = .sources
	@ObservedObject private var downloadManager = DownloadManager.shared

	var body: some View {
		TabView(selection: $selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				TabEnum.view(for: tab)
					.tabItem {
						Label(tab.title, systemImage: tab.icon)
					}
					.tag(tab)
					.badge(tab == .downloads ? downloadManager.downloads.filter { !$0.isCompleted }.count : 0)
			}
		}
		.id(_appLanguage) // recreate TabView when language changes to refresh tab titles
	}
}
