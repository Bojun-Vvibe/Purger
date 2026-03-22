import SwiftUI

/// Quick Clean — one-click cleanup of caches, logs, and temporary files
struct QuickCleanView: View {
    @StateObject private var viewModel = OverviewViewModel()
    @State private var expandedCategory: CleanCategory?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                diskOverviewBar

                if viewModel.isCleaning {
                    cleanProgressSection
                } else if viewModel.isScanning {
                    scanProgressSection
                } else if let result = viewModel.scanResult {
                    resultsSection(result)
                } else {
                    introSection
                }
            }
            .padding(Spacing.xxl)
        }
        .pageBackground()
        .alert("Confirm Cleanup", isPresented: $viewModel.showCleanConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                viewModel.startClean()
            }
        } message: {
            Text("This will remove \(viewModel.selectedReclaimable.formattedSize) of files. Items will be moved to Trash.")
        }
        .alert("Cleanup Complete", isPresented: $viewModel.showCleanResult) {
            Button("OK") {
                viewModel.rescanAfterClean()
            }
        } message: {
            if let result = viewModel.lastCleanResult {
                if result.errors.isEmpty {
                    Text("Removed \(result.filesRemoved) files and freed \(result.totalCleaned.formattedSize).")
                } else {
                    Text("Removed \(result.filesRemoved) files (\(result.totalCleaned.formattedSize)).\n\(result.errors.count) items could not be removed.")
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Quick Clean")
                    .font(AppFont.pageTitle)
                Text("One-click cleanup of caches, logs, and temporary files")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Disk Overview Bar

    private var diskOverviewBar: some View {
        let disk = viewModel.diskInfo
        return HStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                GeometryReader { geo in
                    let usedW = geo.size.width * CGFloat(disk.usedPercentage)
                    let reclaimW = viewModel.totalReclaimable > 0
                        ? geo.size.width * CGFloat(Double(viewModel.totalReclaimable) / Double(max(disk.totalSpace, 1)))
                        : 0

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(Color.diskFree)
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(Color.diskUsed)
                            .frame(width: max(usedW, 0))
                        if reclaimW > 0 {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(Color.diskReclaimable)
                                .frame(width: reclaimW)
                                .offset(x: usedW - reclaimW)
                        }
                    }
                }
                .frame(height: 10)

                HStack(spacing: Spacing.lg) {
                    legendDot(color: .diskUsed, text: "Used \(disk.usedSpace.formattedSize)")
                    legendDot(color: .diskFree, text: "Free \(disk.freeSpace.formattedSize)")
                    if viewModel.totalReclaimable > 0 {
                        legendDot(color: .diskReclaimable, text: "Reclaimable \(viewModel.totalReclaimable.formattedSize)")
                    }
                    Spacer()
                }
            }

            if viewModel.scanResult != nil {
                Button {
                    viewModel.showCleanConfirmation = true
                } label: {
                    Label("Clean (\(viewModel.selectedReclaimable.formattedSize))", systemImage: "trash")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.danger)
                .disabled(viewModel.selectedReclaimable == 0)
            }
        }
        .cardStyle()
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.warning)

            Text("Smart Junk Scanner")
                .font(.system(size: 24, weight: .bold))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureRow("Scans 10 categories of junk files automatically")
                featureRow("Safe items are pre-selected for cleanup")
                featureRow("Files are moved to Trash — nothing is permanently deleted")
            }

            Button {
                viewModel.startScan()
            } label: {
                Label("Start", systemImage: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.warning)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
        .padding(.horizontal, Spacing.xxl)
        .cardStyle(padding: 0)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.warning)
                .frame(width: 16)
            Text(text)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Scan Progress

    private var scanProgressSection: some View {
        VStack(spacing: Spacing.md) {
            ProgressView(value: viewModel.scanProgress)
                .progressViewStyle(.linear)
                .tint(.warning)

            HStack {
                Text(viewModel.scanStatusText)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(viewModel.scanProgress * 100))%")
                    .font(AppFont.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            Button("Cancel") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .cardStyle()
    }

    // MARK: - Clean Progress

    private var cleanProgressSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trash.circle")
                .font(.system(size: 24))
                .foregroundStyle(Color.danger)
                .symbolEffect(.pulse, isActive: true)

            ProgressView(value: viewModel.cleanProgress)
                .progressViewStyle(.linear)
                .tint(.danger)

            Text(viewModel.cleanStatusText)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Results

    private func resultsSection(_ result: ScanResult) -> some View {
        VStack(spacing: Spacing.sm) {
            // Summary
            HStack {
                Text("\(result.totalFileCount) items · \(result.totalReclaimableSize.formattedSize) reclaimable")
                    .font(AppFont.headline)
                Spacer()

                Button {
                    viewModel.startScan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .font(AppFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.bottom, Spacing.xs)

            // Category cards
            ForEach(result.categories.filter { $0.totalSize > 0 }) { categoryResult in
                CompactCategoryCard(
                    categoryResult: categoryResult,
                    isSelected: viewModel.selectedCategories.contains(categoryResult.category),
                    isExpanded: expandedCategory == categoryResult.category,
                    onToggleSelect: {
                        viewModel.toggleCategory(categoryResult.category)
                    },
                    onToggleExpand: {
                        withAnimation(.snappy(duration: 0.25)) {
                            if expandedCategory == categoryResult.category {
                                expandedCategory = nil
                            } else {
                                expandedCategory = categoryResult.category
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Compact Category Card

struct CompactCategoryCard: View {
    let categoryResult: CategoryResult
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleSelect: () -> Void
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: Spacing.sm) {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? categoryResult.category.color : Color.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: categoryResult.category.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(categoryResult.category.color)
                    .frame(width: 20)

                Text(categoryResult.category.rawValue)
                    .font(AppFont.label)

                Text("\(categoryResult.fileCount) items")
                    .font(AppFont.footnote)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(categoryResult.totalSize.formattedSize)
                    .font(AppFont.mono)
                    .foregroundStyle(categoryResult.category.color)

                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm + 2)

            // Expanded items
            if isExpanded {
                Divider().padding(.horizontal, Spacing.lg)

                VStack(spacing: 0) {
                    ForEach(Array(categoryResult.items.prefix(15).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                                .frame(width: 14)

                            Text(item.name)
                                .font(AppFont.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if let date = item.modificationDate {
                                Text(DateFormatHelper.shared.relativeString(from: date))
                                    .font(AppFont.footnote)
                                    .foregroundStyle(.quaternary)
                            }

                            Text(item.size.formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.xs)

                        if index < min(categoryResult.items.count, 15) - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }

                    if categoryResult.items.count > 15 {
                        Text("... and \(categoryResult.items.count - 15) more")
                            .font(AppFont.footnote)
                            .foregroundStyle(.quaternary)
                            .padding(.vertical, Spacing.sm)
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
                        .strokeBorder(
                            isSelected ? categoryResult.category.color : Color.surfaceBorder,
                            lineWidth: 0.5
                        )
                }
        }
    }
}
