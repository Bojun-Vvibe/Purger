import SwiftUI

/// Sidebar navigation tabs — consolidated for deep cleaning focus
enum SidebarTab: String, CaseIterable, Identifiable {
    case deepScan = "Deep Scan"
    case quickClean = "Quick Clean"
    case tools = "Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .deepScan: return "magnifyingglass.circle.fill"
        case .quickClean: return "bolt.circle.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .deepScan: return .accent
        case .quickClean: return .warning
        case .tools: return .info
        }
    }

    var description: String {
        switch self {
        case .deepScan: return "Analyze all disk usage"
        case .quickClean: return "Clean caches & junk"
        case .tools: return "Files, duplicates, apps"
        }
    }
}
