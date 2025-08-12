//
//  VariedTabbarView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI

struct VariedTabbarView: View {
	@Environment(\.horizontalSizeClass) private var hSizeClass

	var body: some View {
		Group {
			if hSizeClass == .regular {
				// iPad & large-screen devices – sidebar oriented
				if #available(iOS 18, *) {
					ExtendedTabbarView()
				} else {
					// Fallback for iPad running iOS < 18
					TabbarView()
				}
			} else {
				// iPhone & compact – standard tab bar
				TabbarView()
			}
		}
	}
}
