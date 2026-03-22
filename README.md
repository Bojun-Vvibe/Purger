<p align="center">
  <img src="Purger/Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="Purger icon">
</p>

<h1 align="center">Purger</h1>

<p align="center">
  A native macOS disk cleanup utility built with SwiftUI.
  <br>
  Scan, analyze, and reclaim wasted disk space — fast.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

## Features

### Deep Scan
Full disk analysis that shows exactly where your storage is going. Scans developer tools (Xcode, Android SDK, Homebrew, Docker), application support, caches, and more — only showing what actually exists on your machine.

### Quick Clean
One-click cleanup of system caches, logs, and temporary files. Scans common junk locations, lets you review what will be removed, then moves everything to Trash so nothing is permanently lost.

### Tools
- **Large Files** — Find the biggest space hogs across your disk
- **Duplicates** — Detect duplicate files using content hashing (CryptoKit)
- **Applications** — Browse installed apps and their associated data

## Screenshots

### Deep Scan
Analyze what's really using your disk space — developer tools, app data, caches, user content, and more, broken down by category with interactive size bars.

<p align="center">
  <img src="screenshots/deep-scan.jpg" width="800" alt="Deep Scan">
</p>

### Quick Clean
One-click cleanup with full visibility. Expands each category (system cache, app cache, browser cache, logs, temp files, downloads, Xcode data) to show every item and its age before you clean.

<p align="center">
  <img src="screenshots/quick-clean.jpg" width="800" alt="Quick Clean">
</p>

### Tools — Applications
Browse all installed apps sorted by data size. Inspect any app to see its bundle size, cache & data footprint, and exact disk locations — then clean with one click.

<p align="center">
  <img src="screenshots/tools.jpg" width="800" alt="Tools — Applications">
</p>

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 16+ (to build from source)

## Build

```bash
# Clone
git clone https://github.com/Bojun-Vvibe/Purger.git
cd Purger

# Build release
xcodebuild -project Purger.xcodeproj -scheme Purger -configuration Release build

# The built app is in DerivedData — or just open Purger.xcodeproj in Xcode and hit ⌘R
```

## Project Structure

```
Purger/
├── PurgerApp.swift          # App entry point
├── Models/
│   ├── AppState.swift       # Global app state
│   ├── CleanCategory.swift  # Cleanup category definitions
│   ├── ScanResult.swift     # Scan result data models
│   └── SidebarTab.swift     # Navigation tabs
├── Views/
│   ├── ContentView.swift    # Main layout with NavigationSplitView
│   ├── StorageAnalyzerView.swift  # Deep Scan UI
│   ├── QuickCleanView.swift       # Quick Clean UI
│   ├── ToolsView.swift            # Tools (Large Files / Duplicates / Apps)
│   ├── LargeFilesView.swift
│   ├── DuplicatesView.swift
│   ├── ApplicationsView.swift
│   ├── SystemJunkView.swift
│   ├── OverviewView.swift
│   └── SettingsView.swift
├── ViewModels/
│   ├── OverviewViewModel.swift
│   └── LargeFilesViewModel.swift
├── Services/
│   ├── DiskScannerService.swift   # File system scanning engine
│   └── CleanerService.swift       # File removal (move to Trash)
├── Utils/
│   ├── Formatters.swift     # Size formatting helpers
│   └── Theme.swift          # Colors, fonts, spacing, dimensions
└── Resources/
    ├── Assets.xcassets/     # App icon & colors
    └── Purger.entitlements  # Sandbox & file access permissions
```

## License

MIT License. See [LICENSE](LICENSE) for details.
