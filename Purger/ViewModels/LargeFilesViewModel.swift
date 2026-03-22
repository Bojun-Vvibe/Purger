import SwiftUI
import Combine

/// ViewModel for the large files view
@MainActor
final class LargeFilesViewModel: ObservableObject {
    @Published var largeFiles: [LargeFileItem] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var minimumSizeMB: Double = 100
    @Published var sortOrder: SortOrder = .sizeDescending

    enum SortOrder: String, CaseIterable {
        case sizeDescending = "Largest First"
        case sizeAscending = "Smallest First"
        case dateNewest = "Newest First"
        case dateOldest = "Oldest First"
        case nameAscending = "Name A-Z"
    }

    private let scanner = DiskScannerService.shared
    private let cleaner = CleanerService.shared

    var totalSelectedSize: Int64 {
        largeFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        largeFiles.filter { $0.isSelected }.count
    }

    var sortedFiles: [LargeFileItem] {
        switch sortOrder {
        case .sizeDescending:
            return largeFiles.sorted { $0.size > $1.size }
        case .sizeAscending:
            return largeFiles.sorted { $0.size < $1.size }
        case .dateNewest:
            return largeFiles.sorted { ($0.modificationDate ?? .distantPast) > ($1.modificationDate ?? .distantPast) }
        case .dateOldest:
            return largeFiles.sorted { ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast) }
        case .nameAscending:
            return largeFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        scanStatusText = "Preparing..."
        largeFiles = []

        let minSize = Int64(minimumSizeMB * 1024 * 1024)

        Task {
            let files = await scanner.scanLargeFiles(
                minimumSize: minSize
            ) { [weak self] progress, status in
                Task { @MainActor in
                    self?.scanProgress = progress
                    self?.scanStatusText = status
                }
            }

            self.largeFiles = files
            self.isScanning = false
        }
    }

    func toggleSelection(for fileId: UUID) {
        if let index = largeFiles.firstIndex(where: { $0.id == fileId }) {
            largeFiles[index].isSelected.toggle()
        }
    }

    func selectAll() {
        for index in largeFiles.indices {
            largeFiles[index].isSelected = true
        }
    }

    func deselectAll() {
        for index in largeFiles.indices {
            largeFiles[index].isSelected = false
        }
    }

    func deleteSelected() async {
        let selectedItems = largeFiles.filter { $0.isSelected }
        let fileItems = selectedItems.map { item in
            FileItem(
                path: item.path,
                name: item.name,
                size: item.size,
                modificationDate: item.modificationDate,
                isDirectory: false
            )
        }

        _ = await cleaner.moveToTrash(items: fileItems)

        // Remove deleted items from the list
        largeFiles.removeAll { $0.isSelected }
    }

    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
