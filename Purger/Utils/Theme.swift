import SwiftUI
import Foundation

// MARK: - Design System

/// Unified spacing scale (4pt grid)
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// Unified typography scale
enum AppFont {
    /// 24pt bold — page title
    static let pageTitle = Font.system(size: 24, weight: .bold)
    /// 16pt semibold — section header
    static let sectionTitle = Font.system(size: 16, weight: .semibold)
    /// 13pt semibold — card title / emphasis
    static let headline = Font.system(size: 13, weight: .semibold)
    /// 13pt regular — body text
    static let body = Font.system(size: 13, weight: .regular)
    /// 12pt medium — row label
    static let label = Font.system(size: 12, weight: .medium)
    /// 12pt monospaced semibold — size values
    static let mono = Font.system(size: 12, weight: .semibold, design: .monospaced)
    /// 11pt regular — subtitle / secondary info
    static let caption = Font.system(size: 11, weight: .regular)
    /// 10pt regular — tertiary / timestamp
    static let footnote = Font.system(size: 10, weight: .regular)
}

/// Unified corner radius
enum Radius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
}

/// App-wide dimensions
struct AppDimensions {
    static let sidebarWidth: CGFloat = 240
    static let cornerRadius: CGFloat = Radius.md
    static let cardPadding: CGFloat = Spacing.lg
    static let spacing: CGFloat = Spacing.md
    static let iconSize: CGFloat = 20
}

// MARK: - Color Palette

/// Streamlined palette: 1 primary accent + semantic colors only
extension Color {
    // -- Brand accent (single primary blue) --
    static let accent = Color(red: 0.30, green: 0.55, blue: 0.95)

    // -- Semantic colors --
    static let success = Color(red: 0.28, green: 0.72, blue: 0.52)
    static let warning = Color(red: 0.92, green: 0.62, blue: 0.20)
    static let danger = Color(red: 0.88, green: 0.32, blue: 0.34)
    static let info = Color(red: 0.48, green: 0.40, blue: 0.82)

    // -- Surface colors (solid, no transparency) --
    static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    static let surfaceElevated = Color(red: 0.16, green: 0.16, blue: 0.18)
    static let surfaceHover = Color(red: 0.20, green: 0.20, blue: 0.22)
    static let surfaceCard = Color(red: 0.14, green: 0.14, blue: 0.16)
    static let surfaceBorder = Color(red: 0.22, green: 0.22, blue: 0.24)
    static let surfaceDivider = Color(red: 0.25, green: 0.25, blue: 0.27)
    static let surfaceBarTrack = Color(red: 0.12, green: 0.12, blue: 0.14)

    // -- Disk visualization (intentionally limited) --
    static let diskUsed = Color(red: 0.40, green: 0.58, blue: 0.82)
    static let diskFree = Color(red: 0.30, green: 0.72, blue: 0.52)
    static let diskReclaimable = Color(red: 0.92, green: 0.62, blue: 0.20)

    // -- Legacy aliases (mapped to new semantic colors for backward compat) --
    static let accentBlue = Color.accent
    static let accentGreen = Color.success
    static let accentOrange = Color.warning
    static let accentRed = Color.danger
    static let accentPurple = Color.info

    static let mutedPurple = Color.info
    static let mutedGreen = Color.success
    static let mutedRed = Color.danger
    static let mutedOrange = Color.warning
    static let mutedBlue = Color.accent
    static let mutedCyan = Color(red: 0.26, green: 0.64, blue: 0.74)
    static let mutedTeal = Color.success
    static let mutedIndigo = Color.info
    static let mutedYellow = Color.warning
}

/// Category colors — use a restrained subset
extension CleanCategory {
    var color: Color {
        switch self {
        case .systemCache:       return .warning
        case .applicationCache:  return .accent
        case .browserCache:      return .info
        case .logFiles:          return Color.secondary
        case .temporaryFiles:    return .warning
        case .downloadedFiles:   return .success
        case .trashBin:          return .danger
        case .mailAttachments:   return .accent
        case .xcodeData:         return .info
        case .dockerData:        return .success
        }
    }
}

// MARK: - Reusable Card Modifier

/// Consistent card styling across the app
struct CardStyle: ViewModifier {
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
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

extension View {
    func cardStyle(padding: CGFloat = Spacing.lg) -> some View {
        modifier(CardStyle(padding: padding))
    }
}

// MARK: - Page Background Modifier

struct PageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.surfacePrimary)
    }
}

extension View {
    func pageBackground() -> some View {
        modifier(PageBackground())
    }
}

// MARK: - Disk Health Color

extension Color {
    /// Returns green → yellow → red based on disk usage percentage (0.0–1.0)
    static func diskHealth(usedPercentage: Double) -> Color {
        switch usedPercentage {
        case ..<0.60:
            return Color.success          // Green — healthy
        case 0.60..<0.75:
            return Color(red: 0.55, green: 0.78, blue: 0.35)  // Light green
        case 0.75..<0.85:
            return Color.warning          // Yellow/Orange — warning
        case 0.85..<0.92:
            return Color(red: 0.92, green: 0.45, blue: 0.25)  // Dark orange
        default:
            return Color.danger           // Red — critical
        }
    }
}

// MARK: - Gradient Card Modifier

/// Card with a subtle gradient accent on the left border
struct GradientAccentCard: ViewModifier {
    var gradientColors: [Color] = [.accent, .info]
    var padding: CGFloat = Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(Color.surfaceCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
    }
}

extension View {
    func gradientCard(colors: [Color] = [.accent, .info], padding: CGFloat = Spacing.lg) -> some View {
        modifier(GradientAccentCard(gradientColors: colors, padding: padding))
    }
}
