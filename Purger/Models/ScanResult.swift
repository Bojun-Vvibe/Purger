import Foundation

/// Represents the result of a disk scan
struct ScanResult: Identifiable {
    let id = UUID()
    let timestamp: Date
    var categories: [CategoryResult]
    let diskInfo: DiskInfo

    var totalReclaimableSize: Int64 {
        categories.reduce(0) { $0 + $1.totalSize }
    }

    var totalFileCount: Int {
        categories.reduce(0) { $0 + $1.items.count }
    }
}

/// Result for a specific category
struct CategoryResult: Identifiable {
    let id = UUID()
    let category: CleanCategory
    var items: [FileItem]

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var fileCount: Int {
        items.count
    }
}

/// Represents a single file or directory found during scan
struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let modificationDate: Date?
    let isDirectory: Bool
    var isSelected: Bool = true

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Disk usage information
struct DiskInfo {
    let totalSpace: Int64
    let usedSpace: Int64
    let freeSpace: Int64
    let purgableSpace: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    var freePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(freeSpace) / Double(totalSpace)
    }

    static var current: DiskInfo {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        do {
            let values = try home.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])

            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)

            return DiskInfo(
                totalSpace: total,
                usedSpace: total - available,
                freeSpace: available,
                purgableSpace: 0
            )
        } catch {
            return DiskInfo(totalSpace: 0, usedSpace: 0, freeSpace: 0, purgableSpace: 0)
        }
    }
}

/// Represents a large file found on disk
struct LargeFileItem: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let size: Int64
    let modificationDate: Date?
    let fileType: String
    var isSelected: Bool = false
}

/// Represents a group of duplicate files
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let hash: String
    let size: Int64
    var files: [FileItem]

    var wastedSpace: Int64 {
        size * Int64(files.count - 1)
    }
}
