import SwiftUI

// MARK: - App Detail Sheet (used by ToolsView)

struct AppDetailSheet: View {
    let app: AppInfo
    let onCleanComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showCleanConfirm = false
    @State private var isCleaning = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: Spacing.lg) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accent)
                        .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(app.name)
                        .font(AppFont.pageTitle)
                    Text(app.path.replacingOccurrences(
                        of: FileManager.default.homeDirectoryForCurrentUser.path,
                        with: "~"
                    ))
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(Spacing.xxl)

            Divider()

            // Size breakdown
            VStack(spacing: Spacing.lg) {
                sizeRow(title: "Application", size: app.appSize, color: .accent, icon: "app")
                sizeRow(title: "App Data & Cache", size: app.dataSize, color: .warning, icon: "folder.fill")
                Divider()
                sizeRow(title: "Total", size: app.appSize + app.dataSize, color: .danger, icon: "sum")
            }
            .padding(Spacing.xxl)

            // Data paths
            if !app.dataPaths.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("DATA LOCATIONS")
                        .font(AppFont.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    ForEach(app.dataPaths, id: \.self) { path in
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "folder")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(path.replacingOccurrences(
                                of: FileManager.default.homeDirectoryForCurrentUser.path,
                                with: "~"
                            ))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, Spacing.xxl)
                .padding(.bottom, Spacing.lg)
            }

            Spacer()

            Divider()

            // Actions
            HStack(spacing: Spacing.md) {
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                        .font(AppFont.caption)
                }
                .buttonStyle(.bordered)

                if app.dataSize > 0 {
                    Button {
                        showCleanConfirm = true
                    } label: {
                        Label("Clean App Data (\(app.dataSize.formattedSize))", systemImage: "trash")
                            .font(AppFont.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.danger)
                    .disabled(isCleaning)
                }
            }
            .padding(Spacing.lg)
        }
        .frame(width: 520, height: 440)
        .alert("Clean App Data?", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                cleanAppData()
            }
        } message: {
            Text("This will remove \(app.dataSize.formattedSize) of cache and data for \(app.name). The app may need to recreate its data.")
        }
    }

    private func sizeRow(title: String, size: Int64, color: Color, icon: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(AppFont.body)

            Spacer()

            Text(size.formattedSize)
                .font(AppFont.mono)
                .foregroundStyle(color)
        }
    }

    private func cleanAppData() {
        isCleaning = true
        Task {
            let fm = FileManager.default
            for path in app.dataPaths {
                try? fm.removeItem(atPath: path)
            }
            await MainActor.run {
                isCleaning = false
                dismiss()
                onCleanComplete()
            }
        }
    }
}

// MARK: - App Info Model

struct AppInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let appSize: Int64
    let dataSize: Int64
    let icon: NSImage?
    let dataPaths: [String]
}

// MARK: - App Discovery Service

final class AppDiscoveryService {
    static let shared = AppDiscoveryService()
    private let fileManager = FileManager.default

    func discoverApplications() async -> [AppInfo] {
        var apps: [AppInfo] = []
        let appDirs = ["/Applications", "\(fileManager.homeDirectoryForCurrentUser.path)/Applications"]

        for appDir in appDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: appDir) else { continue }

            for item in contents where item.hasSuffix(".app") {
                let appPath = (appDir as NSString).appendingPathComponent(item)
                let appName = (item as NSString).deletingPathExtension

                let appSize = directorySize(at: appPath)
                let (dataSize, dataPaths) = getAppDataInfo(appName: appName, bundleId: bundleId(at: appPath))

                // Only icon fetch must be on main thread
                let icon = await MainActor.run {
                    NSWorkspace.shared.icon(forFile: appPath)
                }

                apps.append(AppInfo(
                    name: appName,
                    path: appPath,
                    appSize: appSize,
                    dataSize: dataSize,
                    icon: icon,
                    dataPaths: dataPaths
                ))
            }
        }

        return apps
    }

    func refreshAppData(for app: AppInfo) async -> AppInfo {
        let bid = bundleId(at: app.path)
        let (dataSize, dataPaths) = getAppDataInfo(appName: app.name, bundleId: bid)
        return AppInfo(
            name: app.name,
            path: app.path,
            appSize: app.appSize,
            dataSize: dataSize,
            icon: app.icon,
            dataPaths: dataPaths
        )
    }

    private func bundleId(at appPath: String) -> String? {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOfFile: plistPath) else { return nil }
        return dict["CFBundleIdentifier"] as? String
    }

    private func getAppDataInfo(appName: String, bundleId: String?) -> (Int64, [String]) {
        let home = fileManager.homeDirectoryForCurrentUser.path
        var totalSize: Int64 = 0
        var foundPaths: [String] = []

        // Build candidate paths from both app name and bundle ID
        var candidates: [String] = [
            "\(home)/Library/Application Support/\(appName)",
            "\(home)/Library/Caches/\(appName)",
        ]
        if let bid = bundleId {
            candidates.append(contentsOf: [
                "\(home)/Library/Application Support/\(bid)",
                "\(home)/Library/Caches/\(bid)",
                "\(home)/Library/Containers/\(bid)/Data",
                "\(home)/Library/Group Containers/\(bid)",
            ])
        }

        // Deduplicate
        let unique = Array(Set(candidates))

        for path in unique {
            if fileManager.fileExists(atPath: path) {
                let size = directorySize(at: path)
                if size > 0 {
                    totalSize += size
                    foundPaths.append(path)
                }
            }
        }

        return (totalSize, foundPaths.sorted())
    }

    private func directorySize(at path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { continue }
            totalSize += Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 0)
        }

        return totalSize
    }
}
