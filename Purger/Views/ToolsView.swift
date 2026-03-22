import SwiftUI
import CryptoKit

/// Tools view — Large Files, Duplicates, and Applications in a tabbed interface
struct ToolsView: View {
    @State private var selectedTool: ToolKind = .largeFiles

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                toolPicker

                switch selectedTool {
                case .largeFiles:
                    LargeFilesPanel()
                case .duplicates:
                    DuplicatesPanel()
                case .applications:
                    ApplicationsPanel()
                }
            }
            .padding(Spacing.xxl)
        }
        .pageBackground()
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Tools")
                    .font(AppFont.pageTitle)
                Text("Find large files, duplicates, and manage app data")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Tool Picker

    private var toolPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(ToolKind.allCases, id: \.self) { tool in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedTool = tool
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 12))
                        Text(tool.rawValue)
                            .font(.system(size: 12, weight: selectedTool == tool ? .semibold : .medium))
                    }
                    .foregroundStyle(selectedTool == tool ? .white : .primary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background {
                        if selectedTool == tool {
                            Capsule(style: .continuous).fill(tool.color)
                        } else {
                            Capsule(style: .continuous).fill(Color.surfaceElevated)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Tool Kind

enum ToolKind: String, CaseIterable {
    case largeFiles = "Large Files"
    case duplicates = "Duplicates"
    case applications = "Applications"

    var icon: String {
        switch self {
        case .largeFiles: return "doc.fill"
        case .duplicates: return "doc.on.doc.fill"
        case .applications: return "app.badge.checkmark"
        }
    }

    var color: Color {
        switch self {
        case .largeFiles: return .info
        case .duplicates: return .success
        case .applications: return .danger
        }
    }
}

// MARK: - Large Files Panel

struct LargeFilesPanel: View {
    @StateObject private var viewModel = LargeFilesViewModel()

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Controls
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Min size: \(Int(viewModel.minimumSizeMB)) MB")
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.minimumSizeMB, in: 10...1000, step: 10)
                        .frame(width: 160)
                }

                Spacer()

                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(LargeFilesViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Button {
                    viewModel.startScan()
                } label: {
                    Label(viewModel.largeFiles.isEmpty ? "Scan" : "Rescan", systemImage: "magnifyingglass")
                        .font(AppFont.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.info)
                .controlSize(.small)
                .disabled(viewModel.isScanning)
            }
            .padding(Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.surfaceCard)
            }

            if viewModel.isScanning {
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: viewModel.scanProgress)
                        .progressViewStyle(.linear)
                        .tint(.info)
                    Text(viewModel.scanStatusText)
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                }
                .cardStyle(padding: Spacing.md)
            } else if !viewModel.largeFiles.isEmpty {
                // Action bar
                HStack {
                    Text("\(viewModel.largeFiles.count) files found")
                        .font(AppFont.headline)

                    Spacer()

                    if viewModel.selectedCount > 0 {
                        Text("\(viewModel.selectedCount) selected · \(viewModel.totalSelectedSize.formattedSize)")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button("All") { viewModel.selectAll() }
                        .font(AppFont.footnote)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("None") { viewModel.deselectAll() }
                        .font(AppFont.footnote)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button {
                        Task { await viewModel.deleteSelected() }
                    } label: {
                        Label("Trash", systemImage: "trash")
                            .font(AppFont.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.danger)
                    .controlSize(.small)
                    .disabled(viewModel.selectedCount == 0)
                }
                .padding(.horizontal, Spacing.xs)

                // File list
                VStack(spacing: 0) {
                    ForEach(viewModel.sortedFiles) { file in
                        CompactLargeFileRow(file: file) {
                            viewModel.toggleSelection(for: file.id)
                        } onReveal: {
                            viewModel.revealInFinder(file.path)
                        }

                        if file.id != viewModel.sortedFiles.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
                .background {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.surfaceCard)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.surfaceBorder, lineWidth: 0.5)
                        }
                }
            } else {
                emptyState(
                    icon: "doc.text.magnifyingglass",
                    title: "Find Large Files",
                    subtitle: "Scan your home directory to find files larger than the minimum size.",
                    color: .info
                )
            }
        }
    }
}

// MARK: - Compact Large File Row

struct CompactLargeFileRow: View {
    let file: LargeFileItem
    let onToggle: () -> Void
    let onReveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: file.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(file.isSelected ? Color.info : Color.secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: fileIcon(for: file.name))
                .font(.system(size: 12))
                .foregroundStyle(Color.info)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(AppFont.label)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(shortenPath(file.path))
                    .font(AppFont.footnote)
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            if let date = file.modificationDate {
                Text(DateFormatHelper.shared.relativeString(from: date))
                    .font(AppFont.footnote)
                    .foregroundStyle(.tertiary)
            }

            Text(file.size.formattedSize)
                .font(AppFont.mono)
                .foregroundStyle(Color.info)

            Button(action: onReveal) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isHovered ? Color.surfaceHover : .clear)
        }
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) { isHovered = h }
        }
    }

    private func shortenPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "dmg", "iso", "img": return "opticaldiscdrive.fill"
        case "zip", "tar", "gz", "rar", "7z": return "doc.zipper"
        case "mp4", "mov", "avi", "mkv": return "film"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "app": return "app"
        case "pkg": return "shippingbox.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Duplicates Panel

struct DuplicatesPanel: View {
    @StateObject private var viewModel = DuplicatesViewModel()

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Controls
            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Min file size: \(Int(viewModel.minimumSizeKB)) KB")
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.minimumSizeKB, in: 1...10240, step: 100)
                        .frame(width: 160)
                }

                Spacer()

                if !viewModel.duplicateGroups.isEmpty {
                    Text("\(viewModel.duplicateGroups.count) groups · \(viewModel.totalWastedSpace.formattedSize) wasted")
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.startScan()
                } label: {
                    Label(viewModel.hasScanned ? "Rescan" : "Find Duplicates", systemImage: "magnifyingglass")
                        .font(AppFont.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.success)
                .controlSize(.small)
                .disabled(viewModel.isScanning)
            }
            .padding(Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.surfaceCard)
            }

            if viewModel.isScanning {
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: viewModel.scanProgress)
                        .progressViewStyle(.linear)
                        .tint(.success)
                    Text(viewModel.scanStatusText)
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                    Button("Cancel") { viewModel.cancelScan() }
                        .font(AppFont.footnote)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .cardStyle(padding: Spacing.md)
            } else if !viewModel.duplicateGroups.isEmpty {
                // Action bar
                HStack {
                    Text("\(viewModel.totalWastedSpace.formattedSize) can be freed")
                        .font(AppFont.headline)
                    Spacer()

                    Button {
                        viewModel.autoSelectDuplicates()
                    } label: {
                        Label("Auto-select", systemImage: "checkmark.circle")
                            .font(AppFont.footnote)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        Task { await viewModel.deleteSelected() }
                    } label: {
                        Label("Remove (\(viewModel.selectedCount))", systemImage: "trash")
                            .font(AppFont.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.danger)
                    .controlSize(.small)
                    .disabled(viewModel.selectedCount == 0)
                }
                .padding(.horizontal, Spacing.xs)

                // Groups
                ForEach(viewModel.duplicateGroups) { group in
                    DuplicateGroupCard(group: group) { fileId in
                        viewModel.toggleFileSelection(groupId: group.id, fileId: fileId)
                    } onReveal: { path in
                        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                    }
                }
            } else if viewModel.hasScanned {
                emptyState(
                    icon: "checkmark.circle",
                    title: "No Duplicates Found",
                    subtitle: "Your files look clean! Try lowering the minimum size filter.",
                    color: .success
                )
            } else {
                emptyState(
                    icon: "doc.on.doc",
                    title: "Duplicate File Finder",
                    subtitle: "Scans Downloads, Documents, Desktop, Pictures, Movies, and Music using SHA-256 content hashing.",
                    color: .success
                )
            }
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showCleanResult) {
            Button("OK") { }
        } message: {
            if let r = viewModel.lastCleanResult {
                Text("Removed \(r.filesRemoved) files and freed \(r.totalCleaned.formattedSize).\(r.errors.isEmpty ? "" : "\n\(r.errors.count) files could not be removed.")")
            }
        }
    }
}

// MARK: - Applications Panel

struct ApplicationsPanel: View {
    @State private var applications: [AppInfo] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedApp: AppInfo?
    @State private var sortOrder: AppSortOrder = .dataSizeDesc

    enum AppSortOrder: String, CaseIterable {
        case dataSizeDesc = "Data Size"
        case totalSizeDesc = "Total Size"
        case nameAsc = "Name A-Z"
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Controls
            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(AppFont.caption)
                }
                .padding(Spacing.sm)
                .background {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color.surfaceElevated)
                }
                .frame(width: 180)

                Text("\(filteredApps.count) apps")
                    .font(AppFont.footnote)
                    .foregroundStyle(.tertiary)

                Spacer()

                Picker("Sort", selection: $sortOrder) {
                    ForEach(AppSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Button {
                    loadApplications()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(AppFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoading)
            }
            .cardStyle(padding: Spacing.md)

            if isLoading {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text("Scanning applications...")
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.xxl)
                .cardStyle(padding: 0)
            } else if filteredApps.isEmpty && !applications.isEmpty {
                emptyState(
                    icon: "magnifyingglass",
                    title: "No Matches",
                    subtitle: "No applications match your search.",
                    color: .secondary
                )
            } else if filteredApps.isEmpty {
                emptyState(
                    icon: "app.badge.checkmark",
                    title: "Application Manager",
                    subtitle: "Scan installed apps to find which ones use the most data. Click Refresh to start.",
                    color: .danger
                )
            } else {
                // App list
                VStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        CompactAppRow(app: app) {
                            selectedApp = app
                        }
                        if app.id != filteredApps.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
                .background {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Color.surfaceCard)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Color.surfaceBorder, lineWidth: 0.5)
                        }
                }
            }
        }
        .onAppear {
            if applications.isEmpty { loadApplications() }
        }
        .sheet(item: $selectedApp) { app in
            AppDetailSheet(app: app) {
                refreshSingleApp(app)
            }
        }
    }

    private var filteredApps: [AppInfo] {
        let filtered: [AppInfo]
        if searchText.isEmpty {
            filtered = applications
        } else {
            filtered = applications.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOrder {
        case .dataSizeDesc:
            return filtered.sorted { $0.dataSize > $1.dataSize }
        case .totalSizeDesc:
            return filtered.sorted { ($0.appSize + $0.dataSize) > ($1.appSize + $1.dataSize) }
        case .nameAsc:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func loadApplications() {
        isLoading = true
        Task {
            let apps = await AppDiscoveryService.shared.discoverApplications()
            await MainActor.run {
                self.applications = apps
                self.isLoading = false
            }
        }
    }

    private func refreshSingleApp(_ app: AppInfo) {
        Task {
            let updated = await AppDiscoveryService.shared.refreshAppData(for: app)
            await MainActor.run {
                if let index = applications.firstIndex(where: { $0.name == app.name && $0.path == app.path }) {
                    applications[index] = updated
                }
                selectedApp = nil
            }
        }
    }
}

// MARK: - Compact App Row

struct CompactAppRow: View {
    let app: AppInfo
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.accent)
                        .frame(width: 28, height: 28)
                }

                Text(app.name)
                    .font(AppFont.label)
                    .lineLimit(1)

                Spacer()

                if app.dataSize > 0 {
                    HStack(spacing: 3) {
                        Text(app.dataSize.formattedSize)
                            .font(AppFont.mono)
                            .foregroundStyle(Color.warning)
                        Text("data")
                            .font(AppFont.footnote)
                            .foregroundStyle(.quaternary)
                    }
                }

                Text((app.appSize + app.dataSize).formattedSize)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 65, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
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
            withAnimation(.easeOut(duration: 0.12)) { isHovered = h }
        }
    }
}

// MARK: - Shared Empty State

func emptyState(icon: String, title: String, subtitle: String, color: Color) -> some View {
    VStack(spacing: Spacing.lg) {
        Image(systemName: icon)
            .font(.system(size: 28))
            .foregroundStyle(color)

        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(AppFont.sectionTitle)

            Text(subtitle)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
    }
    .frame(maxWidth: .infinity)
    .padding(Spacing.xxl)
    .cardStyle(padding: 0)
}
