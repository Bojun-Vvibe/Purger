import Foundation

/// Service responsible for scanning the disk for cleanable files
final class DiskScannerService: ObservableObject {
    static let shared = DiskScannerService()

    private let fileManager = FileManager.default
    private var isCancelled = false

    /// Tracks all scanned paths across categories to prevent double-counting
    private var scannedPaths = Set<String>()

    /// Scan all categories and return results
    func scanAll(
        categories: [CleanCategory] = CleanCategory.allCases,
        progressHandler: @escaping (Double, String) -> Void
    ) async -> ScanResult {
        isCancelled = false
        scannedPaths.removeAll()
        var categoryResults: [CategoryResult] = []

        let totalCategories = Double(categories.count)

        for (index, category) in categories.enumerated() {
            guard !isCancelled else { break }

            let progress = Double(index) / totalCategories
            progressHandler(progress, "Scanning \(category.rawValue)...")

            let items = await scanCategory(category)
            let result = CategoryResult(category: category, items: items)
            categoryResults.append(result)
        }

        progressHandler(1.0, "Scan complete")

        return ScanResult(
            timestamp: Date(),
            categories: categoryResults,
            diskInfo: DiskInfo.current
        )
    }

    /// Scan a specific category
    func scanCategory(_ category: CleanCategory) async -> [FileItem] {
        var items: [FileItem] = []
        let excludedPaths = category.excludedPaths

        for path in category.scanPaths {
            guard !isCancelled else { break }
            guard fileManager.fileExists(atPath: path) else { continue }

            let foundItems = scanDirectory(
                at: path,
                maxDepth: 2,
                excludedPaths: excludedPaths,
                excludedFileNames: CleanCategory.globalExcludedFileNames
            )
            items.append(contentsOf: foundItems)
        }

        // Sort by size descending
        items.sort { $0.size > $1.size }

        return items
    }

    /// Scan a directory for files — only lists DIRECT children, calculates dir sizes
    private func scanDirectory(
        at path: String,
        maxDepth: Int,
        excludedPaths: Set<String> = [],
        excludedFileNames: Set<String> = [],
        currentDepth: Int = 0
    ) -> [FileItem] {
        guard currentDepth < maxDepth else { return [] }
        guard fileManager.fileExists(atPath: path) else { return [] }

        // Skip if we already scanned this exact path in another category
        let resolvedPath = resolveSymlinks(path)
        guard !scannedPaths.contains(resolvedPath) else { return [] }
        scannedPaths.insert(resolvedPath)

        var items: [FileItem] = []

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)

            for item in contents {
                guard !isCancelled else { break }

                let fullPath = (path as NSString).appendingPathComponent(item)
                let resolvedFull = resolveSymlinks(fullPath)

                // Skip excluded paths
                if excludedPaths.contains(fullPath) || excludedPaths.contains(resolvedFull) { continue }

                // Skip globally excluded file names
                if excludedFileNames.contains(item) { continue }

                // Skip hidden system files at top level
                if item.hasPrefix(".") && currentDepth == 0 { continue }

                // Skip symlinks to avoid counting the same data twice
                let attrs = try? fileManager.attributesOfItem(atPath: fullPath)
                if attrs?[.type] as? FileAttributeType == .typeSymbolicLink { continue }

                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                let modDate = attrs?[.modificationDate] as? Date

                if isDir.boolValue {
                    // Calculate ACTUAL disk size of directory (not logical size)
                    let dirSize = calculateDirectorySize(at: fullPath)
                    if dirSize > 1024 { // only show > 1 KB
                        items.append(FileItem(
                            path: fullPath,
                            name: item,
                            size: dirSize,
                            modificationDate: modDate,
                            isDirectory: true
                        ))
                    }
                } else {
                    // Use totalFileAllocatedSize for actual disk usage
                    let fileSize = allocatedSize(at: fullPath) ?? (attrs?[.size] as? Int64) ?? 0
                    if fileSize > 0 {
                        items.append(FileItem(
                            path: fullPath,
                            name: item,
                            size: fileSize,
                            modificationDate: modDate,
                            isDirectory: false
                        ))
                    }
                }
            }
        } catch {
            // Permission denied or other error - skip silently
        }

        return items
    }

    /// Calculate ACTUAL allocated disk size of a directory (handles sparse files correctly)
    private func calculateDirectorySize(at path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else { break }

            // Skip globally excluded files
            if CleanCategory.globalExcludedFileNames.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey
            ]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            // Prefer totalFileAllocatedSize (actual disk usage including metadata)
            // Fall back to fileAllocatedSize, then 0
            let size = Int64(resourceValues.totalFileAllocatedSize
                ?? resourceValues.fileAllocatedSize
                ?? 0)
            totalSize += size
        }

        return totalSize
    }

    /// Get the actual allocated size of a single file on disk
    private func allocatedSize(at path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return nil
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    /// Resolve symlinks to get the real path
    private func resolveSymlinks(_ path: String) -> String {
        (try? fileManager.destinationOfSymbolicLink(atPath: path)) ?? path
    }

    /// Scan for large files across common directories
    func scanLargeFiles(
        minimumSize: Int64 = 100 * 1024 * 1024, // 100 MB
        progressHandler: @escaping (Double, String) -> Void
    ) async -> [LargeFileItem] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let searchPaths = [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Movies",
            "\(home)/Music",
        ]

        var largeFiles: [LargeFileItem] = []
        var seenPaths = Set<String>()
        let totalPaths = Double(searchPaths.count)

        for (index, searchPath) in searchPaths.enumerated() {
            guard !isCancelled else { break }

            let progress = Double(index) / totalPaths
            progressHandler(progress, "Scanning \((searchPath as NSString).lastPathComponent)...")

            let files = findLargeFiles(in: searchPath, minimumSize: minimumSize)

            // Deduplicate
            for file in files {
                if !seenPaths.contains(file.path) {
                    seenPaths.insert(file.path)
                    largeFiles.append(file)
                }
            }
        }

        progressHandler(1.0, "Complete")

        // Sort by size descending
        largeFiles.sort { $0.size > $1.size }

        return largeFiles
    }

    private func findLargeFiles(in path: String, minimumSize: Int64) -> [LargeFileItem] {
        var results: [LargeFileItem] = []

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [
                .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                .contentModificationDateKey, .typeIdentifierKey, .isRegularFileKey
            ],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return results
        }

        for case let fileURL as URL in enumerator {
            guard !isCancelled else { break }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [
                .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                .contentModificationDateKey, .typeIdentifierKey, .isRegularFileKey
            ]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile else {
                continue
            }

            let fileSize = Int64(resourceValues.totalFileAllocatedSize
                ?? resourceValues.fileAllocatedSize
                ?? 0)

            guard fileSize >= minimumSize else { continue }

            results.append(LargeFileItem(
                path: fileURL.path,
                name: fileURL.lastPathComponent,
                size: fileSize,
                modificationDate: resourceValues.contentModificationDate,
                fileType: resourceValues.typeIdentifier ?? "unknown"
            ))
        }

        return results
    }

    /// Cancel ongoing scan
    func cancel() {
        isCancelled = true
    }
}
