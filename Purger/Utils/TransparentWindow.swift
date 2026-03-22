import SwiftUI
import AppKit

/// Makes the hosting NSWindow fully transparent so desktop shows through.
/// Also removes the opaque background from NavigationSplitView's internal NSVisualEffectViews.
struct TransparentWindowView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)

            // Make all NSVisualEffectViews in the window hierarchy transparent
            // so NavigationSplitView's built-in sidebar/detail backgrounds don't block through
            Self.makeVisualEffectViewsTransparent(in: window.contentView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Re-apply on updates in case views were recreated
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            Self.makeVisualEffectViewsTransparent(in: window.contentView)
        }
    }

    /// Recursively walk the view tree and set all NSVisualEffectView states to inactive
    /// so they don't render an opaque background
    private static func makeVisualEffectViewsTransparent(in view: NSView?) {
        guard let view = view else { return }
        if let effectView = view as? NSVisualEffectView {
            effectView.state = .inactive
            effectView.material = .underWindowBackground
        }
        for subview in view.subviews {
            makeVisualEffectViewsTransparent(in: subview)
        }
    }
}

/// A view modifier that applies the transparent window background
struct TransparentWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(TransparentWindowView())
    }
}

extension View {
    func transparentWindow() -> some View {
        modifier(TransparentWindowModifier())
    }
}
