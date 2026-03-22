import SwiftUI

/// Main content view with sidebar navigation
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarTab = .deepScan

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(min: 200, ideal: AppDimensions.sidebarWidth, max: 320)
        } detail: {
            ZStack {
                StorageAnalyzerView()
                    .opacity(selectedTab == .deepScan ? 1 : 0)
                    .allowsHitTesting(selectedTab == .deepScan)

                QuickCleanView()
                    .opacity(selectedTab == .quickClean ? 1 : 0)
                    .allowsHitTesting(selectedTab == .quickClean)

                ToolsView()
                    .opacity(selectedTab == .tools ? 1 : 0)
                    .allowsHitTesting(selectedTab == .tools)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab

    var body: some View {
        VStack(spacing: 0) {
            // App logo
            Image("SidebarLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160)
                .padding(.top, 28)
                .padding(.bottom, 24)

            // Disk overview
            diskCard
                .padding(.horizontal, Spacing.lg)

            // Navigation
            VStack(spacing: Spacing.xs) {
                ForEach(SidebarTab.allCases) { tab in
                    SidebarItemView(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xl)

            Spacer()

            // Footer
            Text("v1.0.0")
                .font(AppFont.footnote)
                .foregroundStyle(.quaternary)
                .padding(.bottom, Spacing.lg)
        }
        .frame(minWidth: 200, idealWidth: AppDimensions.sidebarWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Disk Mini Card

    private var diskCard: some View {
        let disk = DiskInfo.current
        return VStack(spacing: Spacing.sm) {
            HStack {
                Text("Disk Usage")
                    .font(AppFont.headline)
                Spacer()
                Text("\(disk.totalSpace.formattedSize) total")
                    .font(AppFont.footnote)
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geo in
                let usedW = geo.size.width * CGFloat(disk.usedPercentage)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(Color.diskFree)
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(
                            LinearGradient(
                                colors: [Color.diskUsed, Color.diskUsed],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(usedW, 0))
                }
            }
            .frame(height: 8)

            HStack(spacing: Spacing.lg) {
                legendDot(color: .diskUsed, text: "Used \(disk.usedSpace.formattedSize)")
                legendDot(color: .diskFree, text: "Free \(disk.freeSpace.formattedSize)")
                Spacer()
            }

            HStack {
                Spacer()
                Text("\(Int(disk.usedPercentage * 100))% used")
                    .font(AppFont.footnote)
                    .foregroundStyle(Color.diskHealth(usedPercentage: disk.usedPercentage))
            }
        }
        .padding(Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(Color.surfaceCard)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Color.surfaceBorder, lineWidth: 0.5)
                }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sidebar Item

struct SidebarItemView: View {
    let tab: SidebarTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .white : tab.color)
                    .frame(width: 24)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm + 2)
            .background {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(tab.color)
                            : isHovered
                                ? AnyShapeStyle(Color.surfaceElevated)
                                : AnyShapeStyle(Color.clear)
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
