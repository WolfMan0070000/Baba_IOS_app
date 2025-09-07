//
//  SectionAppsView.swift
//  Feather
//
//  Created by Assistant on 12.08.2025.
//

import SwiftUI
import Feather

struct SectionAppsView: View {
    let title: String
    let apps: [IOSAppDTO]
    let onAppTap: (IOSAppDTO) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(apps, id: \.id) { app in
                    AppListCard(app: app) {
                        onAppTap(app)
                    }
                    
                    // Divider except for the last item
                    if app.id != apps.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}