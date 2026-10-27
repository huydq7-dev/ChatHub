import AppKit
import SwiftUI

/// Restore the native divider on expansion without constraining live dragging.
struct SidebarPositionRestorer: NSViewRepresentable {
    let expanded: Bool
    let width: Double

    func makeNSView(context: Context) -> PositionView { PositionView() }

    func updateNSView(_ view: PositionView, context: Context) {
        guard view.lastExpanded != expanded else { return }
        view.lastExpanded = expanded
        view.requestedWidth = width
        view.restoreWhenAttached()
    }

    @MainActor
    final class PositionView: NSView {
        var lastExpanded: Bool?
        var requestedWidth: Double = 72

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { restoreWhenAttached() }
        }

        func restoreWhenAttached() {
            let position = requestedWidth
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let window = self.window {
                    window.isMovableByWindowBackground = true
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.styleMask.insert(.fullSizeContentView)
                }
                var ancestor = superview
                while let candidate = ancestor {
                    if let split = candidate as? NSSplitView, split.isVertical, split.subviews.count == 2 {
                        split.setPosition(position, ofDividerAt: 0)
                        return
                    }
                    ancestor = candidate.superview
                }
            }
        }
    }
}
