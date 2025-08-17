//
//  String+localized.swift
//  NimbleKit
//
//  Created by samara on 20.03.2025.
//

import Foundation.NSString
import SwiftUI

extension String {
	// from: https://github.com/NSAntoine/Antoine/blob/main/Antoine/Backend/Extensions/Foundation.swift#L43-L55
	// was given permission to use any code from antoine as I like - thank you Serena!~
	
    static public func localized(_ name: String) -> String {
        // Get the user's preferred language, with fallback to device language
        var languageCode = UserDefaults.standard.string(forKey: "Feather.appLanguage")
        
        // If no language is set, initialize with device language
        if languageCode == nil {
            let deviceLanguage = Locale.preferredLanguages.first ?? "en"
            // Only use device language if it's supported
            let supportedLanguages = ["en", "fa", "tr", "id", "vi", "cs", "de", "es", "fr", "ru"]
            languageCode = supportedLanguages.contains(deviceLanguage) ? deviceLanguage : "en"
            UserDefaults.standard.set(languageCode, forKey: "Feather.appLanguage")
        }
        
        if let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: bundlePath) {
            return NSLocalizedString(name, tableName: nil, bundle: bundle, value: name, comment: "")
        }
        return NSLocalizedString(name, comment: "")
    }
    
    static public func localized(_ name: String, arguments: CVarArg...) -> String {
        var languageCode = UserDefaults.standard.string(forKey: "Feather.appLanguage")
        
        // If no language is set, initialize with device language
        if languageCode == nil {
            let deviceLanguage = Locale.preferredLanguages.first ?? "en"
            let supportedLanguages = ["en", "fa", "tr", "id", "vi", "cs", "de", "es", "fr", "ru"]
            languageCode = supportedLanguages.contains(deviceLanguage) ? deviceLanguage : "en"
            UserDefaults.standard.set(languageCode, forKey: "Feather.appLanguage")
        }
        
        let bundle: Bundle = {
            if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
               let langBundle = Bundle(path: path) {
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
		String.localized(self)
	}
}

extension LocalizedStringKey {
	static public func localized(_ key: String) -> LocalizedStringKey {
		LocalizedStringKey(key)
	}
}
