import SwiftUI

/// A custom floating tab-bar inspired by Apple Music / App Store design
/// Provides a glass-like translucent background, rounded corners and a shadow.
/// On iPad (regular width) it behaves like the default TabBar.
struct GlassTabbarView: View {
    @State private var selectedTab: TabEnum = .sources
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
                    TabEnum.view(for: tab)
                        .tag(tab)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never)) // hide default indicator

            // MARK: – Floating Bar (only compact width)
            if hSizeClass == .compact {
                HStack(spacing: 32) {
                    ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
                        _tabItem(for: tab)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.15))
                }
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func _tabItem(for tab: TabEnum) -> some View {
        Button {
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .symbolVariant(selectedTab == tab ? .fill : .none)
                Text(tab.title)
                    .font(.footnote.weight(selectedTab == tab ? .semibold : .regular))
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary.opacity(0.6))
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
        }
    }
} 