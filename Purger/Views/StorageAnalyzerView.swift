import SwiftUI

/// Deep storage analyzer — shows where ALL disk space is going
struct StorageAnalyzerView: View {
    @StateObject private var viewModel = StorageAnalyzerViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                diskOverviewCard

                if viewModel.isScanning {
                    scanProgressSection
                } else if !viewModel.storageItems.isEmpty {
                    resultsSection
                } else {
                    introSection
                }
            }
            .padding(Spacing.xxl)
        }
        .pageBackground()
        .sheet(item: $viewModel.selectedItem) { item in
            StorageItemDetailSheet(item: item) {
                viewModel.selectedItem = nil
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Deep Scan")
                    .font(AppFont.pageTitle)
                Text("Analyze what's really using your disk space")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Disk Overview

    private var diskOverviewCard: some View {
        let disk = DiskInfo.current
        return VStack(spacing: Spacing.md) {
            // Row 1: Disk Usage (Used vs Free)
            VStack(spacing: Spacing.sm) {
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
                .frame(height: 10)

                HStack(spacing: Spacing.lg) {
                    legendDot(color: .diskUsed, text: "Used \(disk.usedSpace.formattedSize)")
                    legendDot(color: .diskFree, text: "Free \(disk.freeSpace.formattedSize)")
                    Spacer()
                    Text("\(Int(disk.usedPercentage * 100))% used")
                        .font(AppFont.footnote)
                        .foregroundStyle(Color.diskHealth(usedPercentage: disk.usedPercentage))
                }
            }

            // Row 2: Scanned breakdown (only shown after scan)
            if !viewModel.storageItems.isEmpty {
                Divider()

                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Scanned Breakdown")
                            .font(AppFont.headline)
                        Spacer()
                        Text("\(viewModel.totalScannedSize.formattedSize) analyzed")
                            .font(AppFont.mono)
                            .foregroundStyle(Color.diskReclaimable)
                    }

                    GeometryReader { geo in
                        let totalDisk = max(Int64(1), disk.totalSpace)
                        let scannedFraction = CGFloat(Double(viewModel.totalScannedSize) / Double(totalDisk))
                        let scannedW = geo.size.width * scannedFraction

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Color.surfaceBarTrack)
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.diskReclaimable, Color.diskReclaimable],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(scannedW, 2))
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: Spacing.lg) {
                        legendDot(color: .diskReclaimable, text: "Scanned \(viewModel.totalScannedSize.formattedSize)")
                        Spacer()
                        Text("\(String(format: "%.1f", Double(viewModel.totalScannedSize) / Double(max(disk.totalSpace, 1)) * 100))% of disk")
                            .font(AppFont.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accent)

            Text("Deep Scan Analysis")
                .font(.system(size: 24, weight: .bold))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureRow("Reveals hidden space macOS labels as \"System Data\"")
                featureRow("CoreSimulator, Containers, Caches breakdown")
                featureRow("Click any item for details and Finder access")
            }

            Button {
                viewModel.startScan()
            } label: {
                Label("Start", systemImage: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .padding(.horizontal, Spacing.xxl)
        .cardStyle(padding: 0)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.accent)
                .frame(width: 16)
            Text(text)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Scan Progress

    private var scanProgressSection: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView(value: viewModel.scanProgress)
                .progressViewStyle(.linear)
                .tint(.accent)

            Text(viewModel.scanStatusText)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)

            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .cardStyle()
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(spacing: Spacing.lg) {
            // Summary bar
            HStack {
                Text("Scan Results")
                    .font(AppFont.sectionTitle)
                Spacer()
                Text("\(viewModel.storageItems.count) categories · \(viewModel.totalScannedSize.formattedSize)")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)

                Button {
                    viewModel.startScan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .font(AppFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Treemap bar
            storageBar

            // Grouped sections
            ForEach(StorageGroupKind.allCases, id: \.self) { groupKind in
                let items = viewModel.storageItems.filter { $0.group == groupKind }
                if !items.isEmpty {
                    storageGroupSection(groupKind: groupKind, items: items)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Storage Bar

    private var storageBar: some View {
        let totalSize = max(viewModel.totalScannedSize, 1)

        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(viewModel.storageItems.prefix(12)) { item in
                    let fraction = CGFloat(item.size) / CGFloat(totalSize)
                    let w = max(fraction * geo.size.width - 2, 2)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(item.color)
                        .frame(width: w)
                        .help("\(item.name): \(item.size.formattedSize)")
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(Color.surfaceBarTrack)
        }
    }

    // MARK: - Storage Group Section

    private func storageGroupSection(groupKind: StorageGroupKind, items: [StorageItem]) -> some View {
        let totalGroupSize = items.reduce(Int64(0)) { $0 + $1.size }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: groupKind.icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [groupKind.color, groupKind.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .font(.system(size: 13))
                Text(groupKind.title)
                    .font(AppFont.headline)
                Spacer()
                Text(totalGroupSize.formattedSize)
                    .font(AppFont.mono)
                    .foregroundStyle(groupKind.color)
            }
            .padding(.top, Spacing.sm)

            ForEach(items) { item in
                StorageItemRow(item: item) {
                    viewModel.selectedItem = item
                }
            }
        }
    }
}

// MARK: - Storage Item Row

struct StorageItemRow: View {
    let item: StorageItem
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.color)
                    .frame(width: 3, height: 28)

                // Icon
                Image(systemName: item.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(item.color)
                    .frame(width: 22)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppFont.label)
                        .foregroundStyle(.primary)
                    Text(item.detail)
                        .font(AppFont.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                // Size bar
                sizeBar(item: item)

                // Size text
                Text(item.size.formattedSize)
                    .font(AppFont.mono)
                    .foregroundStyle(
                        item.size > 10_000_000_000 ? Color.danger :
                        item.size > 1_000_000_000 ? Color.warning : .secondary
                    )
                    .frame(width: 75, alignment: .trailing)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(isHovered ? Color.surfaceHover : .clear)
            }
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = h }
        }
    }

    private func sizeBar(item: StorageItem) -> some View {
        let maxBarWidth: CGFloat = 80
        let maxSize = Int64(100) * 1024 * 1024 * 1024
        let fraction = min(CGFloat(item.size) / CGFloat(maxSize), 1.0)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.surfaceBarTrack)
                .frame(width: maxBarWidth, height: 5)
            RoundedRectangle(cornerRadius: 2)
                .fill(item.color)
                .frame(width: max(fraction * maxBarWidth, 2), height: 5)
        }
    }
}

// MARK: - Detail Sheet with Drill-Down Navigation

struct BreadcrumbEntry: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String

    static func == (lhs: BreadcrumbEntry, rhs: BreadcrumbEntry) -> Bool {
        lhs.path == rhs.path
    }
}

struct StorageItemDetailSheet: View {
    let item: StorageItem
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var children: [StorageChildItem] = []
    @State private var isLoadingChildren = true
    @State private var navigationStack: [BreadcrumbEntry] = []

    private var currentPath: String {
        navigationStack.last?.path ?? item.path
    }

    private var isAtRoot: Bool {
        navigationStack.count <= 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Spacing.lg) {
                Image(systemName: item.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(item.color)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(item.color)
                    }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(item.name)
                        .font(.system(size: 18, weight: .bold))
                    Text(item.size.formattedSize)
                        .font(AppFont.mono)
                        .foregroundStyle(item.color)
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.xxl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.md)

            Divider()

            // Clean tip
            if isAtRoot && !item.cleanTip.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color.warning)
                        .font(.system(size: 12))
                    Text(item.cleanTip)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.vertical, Spacing.sm)
                .background(Color(red: 0.18, green: 0.15, blue: 0.10))
            }

            // Breadcrumb
            breadcrumbBar
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)

            Divider()

            // Children list
            if isLoadingChildren {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Scanning contents...")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if children.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No visible items")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(children) { child in
                            StorageChildRow(child: child) {
                                navigateInto(child)
                            } onRevealInFinder: {
                                NSWorkspace.shared.selectFile(child.path, inFileViewerRootedAtPath: "")
                            }

                            if child.id != children.last?.id {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }

            Divider()

            // Actions
            HStack(spacing: Spacing.md) {
                Button("Close") {
                    dismiss()
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    NSWorkspace.shared.selectFile(currentPath, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Open in Finder", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .tint(.accent)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .frame(width: 620, height: 560)
        .onAppear {
            navigationStack = [BreadcrumbEntry(name: item.name, path: item.path)]
            loadChildren(at: item.path)
        }
    }

    // MARK: - Breadcrumb Bar

    private var breadcrumbBar: some View {
        HStack(spacing: Spacing.xs) {
            if !isAtRoot {
                Button {
                    navigateBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
                .help("Go back")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                breadcrumbItems
            }

            Spacer()

            Text(shortenPath(currentPath))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.quaternary)
                .lineLimit(1)
                .truncationMode(.head)
        }
    }

    @ViewBuilder
    private var breadcrumbItems: some View {
        BreadcrumbRow(entries: navigationStack) { index in
            navigateTo(index: index)
        }
    }

    // MARK: - Navigation

    private func navigateInto(_ child: StorageChildItem) {
        guard child.isDirectory else { return }
        navigationStack.append(BreadcrumbEntry(name: child.name, path: child.path))
        loadChildren(at: child.path)
    }

    private func navigateBack() {
        guard navigationStack.count > 1 else { return }
        navigationStack.removeLast()
        loadChildren(at: currentPath)
    }

    private func navigateTo(index: Int) {
        guard index < navigationStack.count else { return }
        navigationStack = Array(navigationStack.prefix(index + 1))
        loadChildren(at: currentPath)
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    // MARK: - Loading

    private func loadChildren(at path: String) {
        isLoadingChildren = true
        children = []

        Task.detached {
            let fm = FileManager.default
            var items: [StorageChildItem] = []

            guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
                await MainActor.run {
                    self.children = []
                    self.isLoadingChildren = false
                }
                return
            }

            for name in contents {
                let fullPath = (path as NSString).appendingPathComponent(name)
                if name.hasPrefix(".") { continue }

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                let size: Int64
                if isDir.boolValue {
                    size = StorageAnalyzerService.shared.quickDirectorySize(at: fullPath)
                } else {
                    let url = URL(fileURLWithPath: fullPath)
                    let vals = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                    size = Int64(vals?.totalFileAllocatedSize ?? vals?.fileAllocatedSize ?? 0)
                }

                if size > 0 {
                    items.append(StorageChildItem(
                        name: name,
                        path: fullPath,
                        size: size,
                        isDirectory: isDir.boolValue
                    ))
                }
            }

            items.sort { $0.size > $1.size }

            let sortedItems = items
            await MainActor.run {
                self.children = sortedItems
                self.isLoadingChildren = false
            }
        }
    }
}

// MARK: - Breadcrumb Row

struct BreadcrumbRow: View {
    let entries: [BreadcrumbEntry]
    let onNavigate: (Int) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(entries) { entry in
                breadcrumbItem(for: entry)
            }
        }
    }

    private func breadcrumbItem(for entry: BreadcrumbEntry) -> some View {
        let index = entries.firstIndex(where: { $0.path == entry.path }) ?? 0
        let isLast = (index == entries.count - 1)

        return HStack(spacing: 2) {
            if index > 0 {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            Button {
                onNavigate(index)
            } label: {
                Text(entry.name)
                    .font(.system(size: 11, weight: isLast ? .semibold : .regular))
                    .foregroundStyle(isLast ? .primary : Color.accent)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Child Row

struct StorageChildRow: View {
    let child: StorageChildItem
    let onDrillDown: () -> Void
    let onRevealInFinder: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: child.isDirectory ? "folder.fill" : fileIcon(for: child.name))
                .font(.system(size: 13))
                .foregroundStyle(child.isDirectory ? Color.accent : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(child.name)
                    .font(AppFont.label)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if child.isDirectory {
                    Text("Folder")
                        .font(AppFont.footnote)
                        .foregroundStyle(.quaternary)
                }
            }

            Spacer()

            Text(child.size.formattedSize)
                .font(AppFont.mono)
                .foregroundStyle(
                    child.size > 1_073_741_824 ? Color.warning :
                    child.size > 104_857_600 ? Color.warning : .secondary
                )

            Button {
                onRevealInFinder()
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")

            if child.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
            } else {
                Color.clear.frame(width: 12)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isHovered && child.isDirectory ? Color.surfaceHover : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if child.isDirectory { onDrillDown() }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = hovering }
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "dmg", "iso", "img": return "opticaldiscdrive.fill"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo"
        case "pdf": return "doc.richtext"
        case "app": return "app"
        case "pkg": return "shippingbox.fill"
        case "plist", "json", "xml", "yaml", "yml": return "doc.text"
        case "log", "txt": return "doc.plaintext"
        case "db", "sqlite", "sqlite3": return "cylinder"
        default: return "doc.fill"
        }
    }
}

// MARK: - Models

struct StorageChildItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
}

enum StorageGroupKind: String, CaseIterable {
    case developerTools = "Developer Tools"
    case appData = "App Data & Containers"
    case caches = "Caches & Temporary"
    case userContent = "User Content"
    case system = "System & Other"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .developerTools: return "hammer.fill"
        case .appData: return "shippingbox.fill"
        case .caches: return "arrow.triangle.2.circlepath"
        case .userContent: return "person.fill"
        case .system: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .developerTools: return .info
        case .appData: return .accent
        case .caches: return .warning
        case .userContent: return .success
        case .system: return .secondary
        }
    }
}

struct StorageItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let icon: String
    let color: Color
    let group: StorageGroupKind
    let detail: String
    let cleanTip: String
}

// MARK: - ViewModel

@MainActor
final class StorageAnalyzerViewModel: ObservableObject {
    @Published var storageItems: [StorageItem] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var selectedItem: StorageItem?

    private var isCancelled = false

    var totalScannedSize: Int64 {
        storageItems.reduce(0) { $0 + $1.size }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        isCancelled = false
        scanProgress = 0
        scanStatusText = "Starting deep scan..."
        storageItems = []

        Task {
            let items = await StorageAnalyzerService.shared.analyzeStorage { [weak self] progress, status in
                Task { @MainActor in
                    self?.scanProgress = progress
                    self?.scanStatusText = status
                }
            }

            if !isCancelled {
                self.storageItems = items.sorted { $0.size > $1.size }
            }
            self.isScanning = false
        }
    }

    func cancelScan() {
        isCancelled = true
        StorageAnalyzerService.shared.cancel()
        isScanning = false
    }
}

// MARK: - Storage Analyzer Service

final class StorageAnalyzerService {
    static let shared = StorageAnalyzerService()
    private let fm = FileManager.default
    private var isCancelled = false

    func cancel() { isCancelled = true }

    func analyzeStorage(progressHandler: @escaping (Double, String) -> Void) async -> [StorageItem] {
        isCancelled = false
        var items: [StorageItem] = []
        let home = fm.homeDirectoryForCurrentUser.path

        struct Target {
            let name: String
            let path: String
            let icon: String
            let color: Color
            let group: StorageGroupKind
            let detail: String
            let cleanTip: String
        }

        let targets: [Target] = [
            // Developer Tools
            Target(name: "iOS Simulators", path: "\(home)/Library/Developer/CoreSimulator",
                   icon: "iphone", color: .info, group: .developerTools,
                   detail: "Xcode iOS/watchOS/tvOS simulator data",
                   cleanTip: "Run 'xcrun simctl delete unavailable' in Terminal to remove old simulators, or delete individual simulators in Xcode > Window > Devices and Simulators."),
            Target(name: "Xcode Derived Data", path: "\(home)/Library/Developer/Xcode/DerivedData",
                   icon: "hammer", color: .info, group: .developerTools,
                   detail: "Xcode build caches and indexes",
                   cleanTip: "Safe to delete — Xcode will rebuild as needed. Go to Xcode > Settings > Locations to manage."),
            Target(name: "Xcode Archives", path: "\(home)/Library/Developer/Xcode/Archives",
                   icon: "archivebox.fill", color: .info, group: .developerTools,
                   detail: "Archived builds for App Store submission",
                   cleanTip: "Delete old archives you no longer need via Xcode > Window > Organizer."),
            Target(name: "Xcode Device Support", path: "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
                   icon: "cable.connector", color: .info, group: .developerTools,
                   detail: "Debug symbols for connected iOS devices",
                   cleanTip: "Safe to delete — re-downloaded when you connect a device."),
            Target(name: "Android SDK", path: "\(home)/Library/Android/sdk",
                   icon: "cpu", color: .info, group: .developerTools,
                   detail: "Android Studio SDK, emulators, and platforms",
                   cleanTip: "Use Android Studio SDK Manager to remove unused SDK versions and emulator images."),

            // App Data & Containers
            Target(name: "Application Support", path: "\(home)/Library/Application Support",
                   icon: "app.badge.fill", color: .accent, group: .appData,
                   detail: "App data, settings, extensions",
                   cleanTip: "Contains app data. Check sub-folders — some like wallpaper aerials can be large."),
            Target(name: "App Containers", path: "\(home)/Library/Containers",
                   icon: "shippingbox", color: .accent, group: .appData,
                   detail: "Sandboxed app data (WeChat, Docker, Office, etc.)",
                   cleanTip: "Each app stores data here. Large containers may contain chat history or media."),
            Target(name: "Group Containers", path: "\(home)/Library/Group Containers",
                   icon: "square.stack.3d.up", color: .accent, group: .appData,
                   detail: "Shared data between related apps",
                   cleanTip: "Microsoft Office can use 10GB+ here. Check for old data."),

            // Caches & Temporary
            Target(name: "User Caches", path: "\(home)/Library/Caches",
                   icon: "arrow.triangle.2.circlepath", color: .warning, group: .caches,
                   detail: "Application caches — usually safe to clean",
                   cleanTip: "Generally safe to delete. Apps will recreate caches as needed."),
            Target(name: "Logs", path: "\(home)/Library/Logs",
                   icon: "doc.text", color: .warning, group: .caches,
                   detail: "Application and system log files",
                   cleanTip: "Old logs can be safely removed. Keep recent ones for debugging."),

            // User Content
            Target(name: "Desktop", path: "\(home)/Desktop",
                   icon: "menubar.dock.rectangle", color: .success, group: .userContent,
                   detail: "Desktop files and folders",
                   cleanTip: "macOS counts this as \"Documents\" in storage."),
            Target(name: "Documents", path: "\(home)/Documents",
                   icon: "doc.fill", color: .success, group: .userContent,
                   detail: "User documents",
                   cleanTip: "macOS counts this as \"Documents\" in storage."),
            Target(name: "Downloads", path: "\(home)/Downloads",
                   icon: "arrow.down.circle.fill", color: .success, group: .userContent,
                   detail: "Downloaded files",
                   cleanTip: "Check for old downloads you no longer need."),
            Target(name: "Movies", path: "\(home)/Movies",
                   icon: "film", color: .success, group: .userContent,
                   detail: "Video files and movie projects",
                   cleanTip: "Video files are large — archive or delete old ones."),
            Target(name: "Music", path: "\(home)/Music",
                   icon: "music.note", color: .success, group: .userContent,
                   detail: "Music files and libraries",
                   cleanTip: "Check for downloaded music you no longer need."),
            Target(name: "Pictures", path: "\(home)/Pictures",
                   icon: "photo", color: .success, group: .userContent,
                   detail: "Image files and photo libraries",
                   cleanTip: "Photo libraries can be large. Consider using iCloud Photo Library."),

            // System & Other
            Target(name: "Mail Data", path: "\(home)/Library/Mail",
                   icon: "envelope.fill", color: .secondary, group: .system,
                   detail: "Mail app data and attachments",
                   cleanTip: "Remove old email accounts or large attachments."),
            Target(name: "Metadata & Spotlight", path: "\(home)/Library/Metadata",
                   icon: "magnifyingglass", color: .secondary, group: .system,
                   detail: "Spotlight index and metadata caches",
                   cleanTip: "Managed by macOS. Rebuilds automatically if deleted."),
            Target(name: "Biome", path: "\(home)/Library/Biome",
                   icon: "brain", color: .secondary, group: .system,
                   detail: "macOS intelligence and suggestion data",
                   cleanTip: "System-managed. Generally don't delete."),
        ]

        let totalTargets = Double(targets.count)

        for (index, target) in targets.enumerated() {
            guard !isCancelled else { break }

            let progress = Double(index) / totalTargets
            progressHandler(progress, "Analyzing \(target.name)...")

            guard fm.fileExists(atPath: target.path) else { continue }

            let size = quickDirectorySize(at: target.path)
            if size > 1024 * 1024 {
                items.append(StorageItem(
                    name: target.name,
                    path: target.path,
                    size: size,
                    icon: target.icon,
                    color: target.color,
                    group: target.group,
                    detail: target.detail,
                    cleanTip: target.cleanTip
                ))
            }
        }

        progressHandler(0.9, "Looking for other large directories...")
        let knownPaths = Set(targets.map { $0.path })
        let otherItems = scanOtherLibraryDirs(home: home, knownPaths: knownPaths)
        items.append(contentsOf: otherItems)

        progressHandler(1.0, "Analysis complete")
        return items
    }

    func quickDirectorySize(at path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else { break }
            guard let vals = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]),
                  vals.isRegularFile == true else { continue }
            totalSize += Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 0)
        }

        return totalSize
    }

    private func scanOtherLibraryDirs(home: String, knownPaths: Set<String>) -> [StorageItem] {
        var results: [StorageItem] = []
        let libraryPath = "\(home)/Library"

        guard let contents = try? fm.contentsOfDirectory(atPath: libraryPath) else { return [] }

        for dirName in contents {
            guard !isCancelled else { break }
            let fullPath = (libraryPath as NSString).appendingPathComponent(dirName)

            if knownPaths.contains(fullPath) { continue }
            if dirName.hasPrefix(".") { continue }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let size = quickDirectorySize(at: fullPath)
            if size > 100 * 1024 * 1024 {
                results.append(StorageItem(
                    name: dirName,
                    path: fullPath,
                    size: size,
                    icon: "folder.fill",
                    color: .secondary,
                    group: .system,
                    detail: "~/Library/\(dirName)",
                    cleanTip: "Investigate contents before deleting."
                ))
            }
        }

        return results
    }
}
