import SwiftUI
import CryptoKit

// MARK: - Duplicate Group Card (used by ToolsView)

struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    let onToggle: (UUID) -> Void
    let onReveal: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.success)
                        .frame(width: 20)

                    Text("\(group.files.count) copies")
                        .font(AppFont.label)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text("\(group.size.formattedSize) each")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("Wasted: \(group.wastedSpace.formattedSize)")
                        .font(AppFont.headline)
                        .foregroundStyle(Color.warning)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm + 2)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(Array(group.files.enumerated()), id: \.element.id) { index, file in
                        HStack(spacing: Spacing.sm) {
                            // Select checkbox
                            Button {
                                onToggle(file.id)
                            } label: {
                                Image(systemName: file.isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(file.isSelected ? Color.danger : Color.secondary)
                            }
                            .buttonStyle(.plain)

                            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                                .frame(width: 14)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.name)
                                    .font(AppFont.label)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(file.path.replacingOccurrences(
                                    of: FileManager.default.homeDirectoryForCurrentUser.path,
                                    with: "~"
                                ))
                                    .font(AppFont.footnote)
                                    .foregroundStyle(.quaternary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }

                            Spacer()

                            Button {
                                onReveal(file.path)
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .help("Reveal in Finder")
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)

                        if index < group.files.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, Spacing.sm)
            }
        }
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

// MARK: - ViewModel

@MainActor
final class DuplicatesViewModel: ObservableObject {
    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0.0
    @Published var scanStatusText: String = ""
    @Published var hasScanned = false
    @Published var minimumSizeKB: Double = 100
    @Published var showCleanResult = false
    @Published var lastCleanResult: CleanerService.CleanResult?

    private let fileManager = FileManager.default
    private var isCancelled = false

    var totalWastedSpace: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.wastedSpace }
    }

    var selectedCount: Int {
        duplicateGroups.reduce(0) { sum, group in
            sum + group.files.filter { $0.isSelected }.count
        }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        isCancelled = false
        scanProgress = 0
        scanStatusText = "Collecting files..."
        duplicateGroups = []

        let minSize = Int64(minimumSizeKB * 1024)

        Task {
            let groups = await findDuplicates(minimumSize: minSize)
            self.duplicateGroups = groups
            self.isScanning = false
            self.hasScanned = true
        }
    }

    func cancelScan() {
        isCancelled = true
        isScanning = false
    }

    func toggleFileSelection(groupId: UUID, fileId: UUID) {
        guard let gi = duplicateGroups.firstIndex(where: { $0.id == groupId }),
              let fi = duplicateGroups[gi].files.firstIndex(where: { $0.id == fileId }) else { return }
        duplicateGroups[gi].files[fi].isSelected.toggle()
    }

    /// Auto-select all but the first file in each group
    func autoSelectDuplicates() {
        for gi in duplicateGroups.indices {
            for fi in duplicateGroups[gi].files.indices {
                duplicateGroups[gi].files[fi].isSelected = (fi > 0)
            }
        }
    }

    func deleteSelected() async {
        var selectedItems: [FileItem] = []
        for group in duplicateGroups {
            let selected = group.files.filter { $0.isSelected }
            // Safety: never delete ALL copies — keep at least one
            if selected.count < group.files.count {
                selectedItems.append(contentsOf: selected)
            }
        }

        guard !selectedItems.isEmpty else { return }

        let result = await CleanerService.shared.moveToTrash(items: selectedItems)
        self.lastCleanResult = result
        self.showCleanResult = true

        // Remove deleted files from groups
        let deletedPaths = Set(selectedItems.filter { item in
            !result.errors.contains { $0.path == item.path }
        }.map { $0.path })

        for gi in duplicateGroups.indices {
            duplicateGroups[gi].files.removeAll { deletedPaths.contains($0.path) }
        }
        // Remove groups that no longer have duplicates
        duplicateGroups.removeAll { $0.files.count <= 1 }
    }

    // MARK: - Duplicate Finding Engine

    private func findDuplicates(minimumSize: Int64) async -> [DuplicateGroup] {
        let home = fileManager.homeDirectoryForCurrentUser.path
        let searchDirs = [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music",
        ]

        // Step 1: Collect all files grouped by size
        await MainActor.run {
            scanStatusText = "Collecting files..."
            scanProgress = 0.1
        }

        var sizeMap: [Int64: [String]] = [:]

        for (i, dir) in searchDirs.enumerated() {
            guard !isCancelled else { return [] }

            await MainActor.run {
                scanStatusText = "Scanning \((dir as NSString).lastPathComponent)..."
                scanProgress = 0.1 + 0.3 * Double(i) / Double(searchDirs.count)
            }

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard !isCancelled else { return [] }
                guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                      vals.isRegularFile == true,
                      let size = vals.fileSize,
                      Int64(size) >= minimumSize else { continue }

                let s = Int64(size)
                sizeMap[s, default: []].append(fileURL.path)
            }
        }

        // Keep only sizes with more than one file (potential duplicates)
        let candidates = sizeMap.filter { $0.value.count > 1 }

        guard !candidates.isEmpty else { return [] }

        // Step 2: Hash files that share the same size
        await MainActor.run {
            scanStatusText = "Computing hashes..."
            scanProgress = 0.5
        }

        var hashMap: [String: (size: Int64, paths: [String])] = [:]
        let totalCandidateFiles = candidates.values.reduce(0) { $0 + $1.count }
        var processed = 0

        for (size, paths) in candidates {
            guard !isCancelled else { return [] }

            for path in paths {
                guard !isCancelled else { return [] }

                processed += 1
                if processed % 50 == 0 {
                    let prog = 0.5 + 0.45 * Double(processed) / Double(max(totalCandidateFiles, 1))
                    await MainActor.run {
                        scanStatusText = "Hashing files... (\(processed)/\(totalCandidateFiles))"
                        scanProgress = min(prog, 0.95)
                    }
                }

                guard let hash = hashFile(at: path) else { continue }
                hashMap[hash, default: (size: size, paths: [])].paths.append(path)
            }
        }

        // Step 3: Build DuplicateGroup results
        await MainActor.run {
            scanStatusText = "Building results..."
            scanProgress = 0.95
        }

        var groups: [DuplicateGroup] = []
        for (hash, info) in hashMap where info.paths.count > 1 {
            let files = info.paths.map { path -> FileItem in
                let attrs = try? fileManager.attributesOfItem(atPath: path)
                return FileItem(
                    path: path,
                    name: (path as NSString).lastPathComponent,
                    size: info.size,
                    modificationDate: attrs?[.modificationDate] as? Date,
                    isDirectory: false,
                    isSelected: false
                )
            }
            groups.append(DuplicateGroup(hash: hash, size: info.size, files: files))
        }

        // Sort by wasted space descending
        groups.sort { $0.wastedSpace > $1.wastedSpace }

        await MainActor.run {
            scanProgress = 1.0
            scanStatusText = "Done"
        }

        return groups
    }

    /// SHA-256 hash of a file. Reads in chunks to handle large files.
    private func hashFile(at path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1 MB chunks

        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) { }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
