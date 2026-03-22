import Foundation

/// Service responsible for cleaning/deleting selected files
final class CleanerService: ObservableObject {
    static let shared = CleanerService()

    private let fileManager = FileManager.default

    struct CleanResult {
        let totalCleaned: Int64
        let filesRemoved: Int
        let errors: [CleanError]
    }

    struct CleanError: Identifiable {
        let id = UUID()
        let path: String
        let message: String
    }

    /// Clean selected files from category results
    func clean(
        categories: [CategoryResult],
        selectedCategories: Set<CleanCategory>,
        progressHandler: @escaping (Double, String) -> Void
    ) async -> CleanResult {
        var totalCleaned: Int64 = 0
        var filesRemoved: Int = 0
        var errors: [CleanError] = []

        let filteredCategories = categories.filter { selectedCategories.contains($0.category) }
        let allItems = filteredCategories.flatMap { $0.items.filter { $0.isSelected } }
        let totalItems = Double(allItems.count)

        for (index, item) in allItems.enumerated() {
            let progress = Double(index) / max(totalItems, 1)
            progressHandler(progress, "Cleaning \(item.name)...")

            do {
                try fileManager.removeItem(atPath: item.path)
                totalCleaned += item.size
                filesRemoved += 1
            } catch {
                errors.append(CleanError(
                    path: item.path,
                    message: error.localizedDescription
                ))
            }
        }

        progressHandler(1.0, "Cleaning complete")

        return CleanResult(
            totalCleaned: totalCleaned,
            filesRemoved: filesRemoved,
            errors: errors
        )
    }

    /// Move files to trash instead of permanently deleting
    func moveToTrash(items: [FileItem]) async -> CleanResult {
        var totalCleaned: Int64 = 0
        var filesRemoved: Int = 0
        var errors: [CleanError] = []

        for item in items {
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(
                    at: URL(fileURLWithPath: item.path),
                    resultingItemURL: &resultingURL
                )
                totalCleaned += item.size
                filesRemoved += 1
            } catch {
                errors.append(CleanError(
                    path: item.path,
                    message: error.localizedDescription
                ))
            }
        }

        return CleanResult(
            totalCleaned: totalCleaned,
            filesRemoved: filesRemoved,
            errors: errors
        )
    }

    /// Check if we have permission to delete a file
    func canDelete(at path: String) -> Bool {
        fileManager.isDeletableFile(atPath: path)
    }

    /// Empty the system Trash
    func emptyTrash() async throws {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let trashPath = "\(home)/.Trash"

        let contents = try fileManager.contentsOfDirectory(atPath: trashPath)
        for item in contents {
            let fullPath = (trashPath as NSString).appendingPathComponent(item)
            try fileManager.removeItem(atPath: fullPath)
        }
    }
}
