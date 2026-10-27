import AppKit
import SwiftUI

/// Applying the workspace chrome must not force layout on every focus notification
/// or SwiftUI update. AppKit schedules layout when a property actually changes.
@MainActor
enum WorkspaceWindowStyle {
    static func apply(to window: NSWindow, alwaysOnTop: Bool = false) {
        if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
        if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
        if window.titlebarSeparatorStyle != .none { window.titlebarSeparatorStyle = .none }
        if !window.isMovableByWindowBackground { window.isMovableByWindowBackground = true }
        if window.toolbar != nil { window.toolbar = nil }
        let background = NSColor(Color(HubStyle.rail))
        if window.backgroundColor != background { window.backgroundColor = background }
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        let targetLevel: NSWindow.Level = alwaysOnTop ? .floating : .normal
        if window.level != targetLevel { window.level = targetLevel }
    }
}
