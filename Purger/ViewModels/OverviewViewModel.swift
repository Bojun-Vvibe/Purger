import SwiftUI
import Combine

/// ViewModel for the overview/main dashboard
@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var diskInfo: DiskInfo = .current
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var scanResult: ScanResult?
    @Published var isCleaning = false
    @Published var cleanProgress: Double = 0.0
    @Published var cleanStatusText: String = ""
    @Published var showCleanConfirmation = false
    @Published var showCleanResult = false
    @Published var lastCleanResult: CleanerService.CleanResult?
    @Published var selectedCategories: Set<CleanCategory> = Set(CleanCategory.allCases)

    private let scanner = DiskScannerService.shared
    private let cleaner = CleanerService.shared

    var totalReclaimable: Int64 {
        scanResult?.totalReclaimableSize ?? 0
    }

    var selectedReclaimable: Int64 {
        guard let result = scanResult else { return 0 }
        return result.categories
            .filter { selectedCategories.contains($0.category) }
            .reduce(0) { $0 + $1.totalSize }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        scanStatusText = "Preparing scan..."
        scanResult = nil

        Task {
            let result = await scanner.scanAll { [weak self] progress, status in
                Task { @MainActor in
                    self?.scanProgress = progress
                    self?.scanStatusText = status
                }
            }

            self.scanResult = result
            self.isScanning = false
            self.diskInfo = .current
        }
    }

    func startClean() {
        guard !isCleaning, let result = scanResult else { return }
        isCleaning = true
        cleanProgress = 0
        cleanStatusText = "Preparing cleanup..."
        // Clear scanResult so the UI shows the cleaning progress view
        scanResult = nil

        Task {
            let cleanResult = await cleaner.clean(
                categories: result.categories,
                selectedCategories: selectedCategories
            ) { [weak self] progress, status in
                Task { @MainActor in
                    self?.cleanProgress = progress
                    self?.cleanStatusText = status
                }
            }

            self.lastCleanResult = cleanResult
            self.isCleaning = false
            self.diskInfo = .current
            // Show the result alert — rescan happens when user dismisses it
            self.showCleanResult = true
        }
    }

    /// Called when user dismisses the "Cleanup Complete" alert
    func rescanAfterClean() {
        startScan()
    }

    func cancelScan() {
        scanner.cancel()
        isScanning = false
    }

    func toggleCategory(_ category: CleanCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func refreshDiskInfo() {
        diskInfo = .current
    }
}
