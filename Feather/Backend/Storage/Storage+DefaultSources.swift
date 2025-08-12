import Foundation
import AltSourceKit

extension Storage {
    func addDefaultSources() {
        let defaultSourceURL = "https://raw.githubusercontent.com/swaggyP36000/TrollStore-IPAs/main/apps_esign.json"
        
        guard let url = URL(string: defaultSourceURL) else { return }
        
        if !sourceExists(defaultSourceURL) {
            addSource(url, name: "TrollStore IPAs", identifier: defaultSourceURL) { _ in }
        }
    }
} 