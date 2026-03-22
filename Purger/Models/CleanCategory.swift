import Foundation

/// Categories of cleanable items
enum CleanCategory: String, CaseIterable, Identifiable, Codable {
    case systemCache = "System Cache"
    case applicationCache = "App Cache"
    case browserCache = "Browser Cache"
    case logFiles = "Log Files"
    case temporaryFiles = "Temporary Files"
    case downloadedFiles = "Downloads"
    case trashBin = "Trash"
    case mailAttachments = "Mail Attachments"
    case xcodeData = "Xcode Data"
    case dockerData = "Docker Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .systemCache: return "gearshape.fill"
        case .applicationCache: return "app.fill"
        case .browserCache: return "globe"
        case .logFiles: return "doc.text.fill"
        case .temporaryFiles: return "clock.arrow.circlepath"
        case .downloadedFiles: return "arrow.down.circle.fill"
        case .trashBin: return "trash.fill"
        case .mailAttachments: return "envelope.fill"
        case .xcodeData: return "hammer.fill"
        case .dockerData: return "shippingbox.fill"
        }
    }

    var description: String {
        switch self {
        case .systemCache: return "macOS system caches that can be safely rebuilt"
        case .applicationCache: return "Application caches and temporary data"
        case .browserCache: return "Browser cache, cookies, and history"
        case .logFiles: return "System and application log files"
        case .temporaryFiles: return "Temporary files and intermediate data"
        case .downloadedFiles: return "Downloaded files in ~/Downloads"
        case .trashBin: return "Files in the Trash"
        case .mailAttachments: return "Cached email attachments"
        case .xcodeData: return "Xcode derived data and archives"
        case .dockerData: return "Docker build cache and dangling images"
        }
    }

    /// Risk level: low = safe to clean, medium = review first, high = be careful
    var riskLevel: RiskLevel {
        switch self {
        case .systemCache, .temporaryFiles, .logFiles: return .low
        case .applicationCache, .browserCache, .trashBin, .mailAttachments: return .medium
        case .downloadedFiles, .xcodeData, .dockerData: return .high
        }
    }

    /// Paths to scan for this category
    /// IMPORTANT: paths must NOT overlap between categories to avoid double-counting
    var scanPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .systemCache:
            // Only system-level caches, NOT user caches (those go to applicationCache)
            return ["/Library/Caches"]
        case .applicationCache:
            // User-level app caches, excluding browser caches (handled separately)
            return ["\(home)/Library/Caches"]
        case .browserCache:
            // Browser caches are scanned as part of applicationCache's subdirectories
            // We return empty here to avoid double-counting; browser items are
            // identified by name inside applicationCache scan instead.
            // If you want a separate count, exclude these paths from applicationCache.
            return [
                "\(home)/Library/Caches/com.apple.Safari",
                "\(home)/Library/Caches/Google/Chrome",
                "\(home)/Library/Caches/Firefox",
                "\(home)/Library/Caches/com.microsoft.edgemac"
            ]
        case .logFiles:
            return ["\(home)/Library/Logs"]
        case .temporaryFiles:
            return [NSTemporaryDirectory()]
        case .downloadedFiles:
            return ["\(home)/Downloads"]
        case .trashBin:
            return ["\(home)/.Trash"]
        case .mailAttachments:
            return ["\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"]
        case .xcodeData:
            return [
                "\(home)/Library/Developer/Xcode/DerivedData",
                "\(home)/Library/Developer/Xcode/Archives",
                "\(home)/Library/Developer/Xcode/iOS DeviceSupport"
            ]
        case .dockerData:
            // Only scan Docker build cache and temp data — NOT the VM disk image
            return [
                "\(home)/Library/Containers/com.docker.docker/Data/docker/buildkit",
                "\(home)/Library/Containers/com.docker.docker/Data/docker/tmp",
                "\(home)/Library/Containers/com.docker.docker/Data/docker/overlay2"
            ]
        }
    }

    /// Paths that should be excluded from scanning within this category
    var excludedPaths: Set<String> {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .applicationCache:
            // Exclude browser caches — they are counted in browserCache category
            return Set([
                "\(home)/Library/Caches/com.apple.Safari",
                "\(home)/Library/Caches/Google",
                "\(home)/Library/Caches/Firefox",
                "\(home)/Library/Caches/com.microsoft.edgemac"
            ])
        default:
            return []
        }
    }

    /// File patterns that should NEVER be deleted (virtual disks, databases, etc.)
    static var globalExcludedFileNames: Set<String> {
        return [
            "Docker.raw", "Docker.qcow2",      // Docker VM disk image
            "vms",                               // Docker VM directory
            "com.apple.dock.launchpad",          // Launchpad DB
        ]
    }
}

enum RiskLevel: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}
