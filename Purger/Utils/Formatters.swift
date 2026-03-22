import Foundation

/// Utility for formatting file sizes
struct FileSizeFormatter {
    static let shared = FileSizeFormatter()

    private let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()

    func format(_ bytes: Int64) -> String {
        byteCountFormatter.string(fromByteCount: bytes)
    }

    /// Format with specific precision
    func format(_ bytes: Int64, units: ByteCountFormatter.Units) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = units
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// Returns a compact representation (e.g., "1.2 GB")
    func formatCompact(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}

/// Date formatting utility
struct DateFormatHelper {
    static let shared = DateFormatHelper()

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    func relativeString(from date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    func fullString(from date: Date) -> String {
        fullFormatter.string(from: date)
    }
}

/// Extensions for convenient size formatting
extension Int64 {
    var formattedSize: String {
        FileSizeFormatter.shared.format(self)
    }
}
