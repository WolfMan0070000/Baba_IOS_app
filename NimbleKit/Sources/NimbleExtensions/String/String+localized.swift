//
//  String+localized.swift
//  NimbleKit
//
//  Created by samara on 20.03.2025.
//

import Foundation.NSString
import SwiftUICore

extension String {
	// from: https://github.com/NSAntoine/Antoine/blob/main/Antoine/Backend/Extensions/Foundation.swift#L43-L55
	// was given permission to use any code from antoine as I like - thank you Serena!~
	
	static public func localized(_ name: String) -> String {
		// Retrieve the language chosen inside the app (defaults to system language if not set)
		let languageCode = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? Locale.preferredLanguages.first ?? "en"
		if
			let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
			let bundle = Bundle(path: bundlePath)
		{
			return NSLocalizedString(name, tableName: nil, bundle: bundle, value: name, comment: "")
		}
		// Fallback to main bundle / base localisation
		return NSLocalizedString(name, comment: "")
	}
	
	static public func localized(_ name: String, arguments: CVarArg...) -> String {
		let languageCode = UserDefaults.standard.string(forKey: "Feather.appLanguage") ?? Locale.preferredLanguages.first ?? "en"
		let bundle: Bundle = {
			if
				let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
				let langBundle = Bundle(path: path)
			{
				return langBundle
			}
			return .main
		}()
		let format = NSLocalizedString(name, tableName: nil, bundle: bundle, value: name, comment: "")
		return String(format: format, arguments: arguments)
	}
	/// Localizes the current string using the main bundle.
	///
	/// - Returns: The localized string.
	public func localized() -> String {
		return String.localized(self)
	}
}

extension LocalizedStringKey {
	static public func localized(_ key: String) -> LocalizedStringKey {
		return LocalizedStringKey(key)
	}
}
