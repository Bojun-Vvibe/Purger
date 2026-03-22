import SwiftUI
import Combine

/// Global application state
final class AppState: ObservableObject {
    @Published var selectedTab: SidebarTab = .deepScan
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var scanResult: ScanResult?
    @Published var selectedCategories: Set<CleanCategory> = Set(CleanCategory.allCases)
    @Published var lastScanDate: Date?

    /// Total reclaimable space from selected categories
    var selectedReclaimableSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.categories
            .filter { selectedCategories.contains($0.category) }
            .reduce(0) { $0 + $1.totalSize }
    }

    /// Total reclaimable space from all categories
    var totalReclaimableSize: Int64 {
        guard let result = scanResult else { return 0 }
        return result.categories.reduce(0) { $0 + $1.totalSize }
    }
}
