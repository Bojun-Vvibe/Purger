import SwiftUI

/// Settings/Preferences view
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = false
    @AppStorage("moveToTrashInsteadOfDelete") private var moveToTrash = true
    @AppStorage("minimumLargeFileSize") private var minimumLargeFileSize = 100.0
    @AppStorage("showHiddenFiles") private var showHiddenFiles = false
    @AppStorage("skipSystemProtectedFiles") private var skipSystemProtected = true

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            cleaningSettings
                .tabItem {
                    Label("Cleaning", systemImage: "trash")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 320)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Toggle("Auto-scan on launch", isOn: $autoScanOnLaunch)

            Toggle("Show hidden files in scan results", isOn: $showHiddenFiles)

            Toggle("Skip system-protected files", isOn: $skipSystemProtected)
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Cleaning Settings

    private var cleaningSettings: some View {
        Form {
            Toggle("Move to Trash instead of permanent delete", isOn: $moveToTrash)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Minimum large file size: \(Int(minimumLargeFileSize)) MB")
                    .font(AppFont.caption)
                Slider(value: $minimumLargeFileSize, in: 10...1000, step: 10)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "externaldrive.fill.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.accent)
                .symbolRenderingMode(.hierarchical)

            Text("Purger")
                .font(AppFont.pageTitle)

            Text("Version 1.0.0")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)

            Text("A lightweight macOS disk cleanup utility built with SwiftUI.")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(Spacing.xxl)
    }
}
