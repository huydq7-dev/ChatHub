import SwiftUI
import WebKit

final class WebHostContainerView: NSView {
    private weak var activeWebView: WKWebView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    func attach(_ webView: WKWebView) {
        guard webView.superview !== self else { return }
        let initialBounds = bounds.isEmpty ? NSRect(x: 0, y: 0, width: 800, height: 600) : bounds
        webView.frame = initialBounds
        // Keep background sessions connected without relaying every live resize to them.
        webView.autoresizingMask = []
        webView.alphaValue = 0.0
        addSubview(webView, positioned: .below, relativeTo: nil)
    }

    func detach(_ webView: WKWebView) {
        if activeWebView === webView {
            activeWebView = nil
        }
        webView.removeFromSuperview()
    }

    @discardableResult
    func show(_ webView: WKWebView) -> Bool {
        // SwiftUI may update the representable while typing or changing a badge.
        // Only an actual account switch should move focus or invalidate the web view.
        guard activeWebView !== webView || webView.superview !== self else { return false }
        activeWebView?.alphaValue = 0
        attach(webView)
        if subviews.last !== webView {
            addSubview(webView, positioned: .above, relativeTo: nil)
        }
        activeWebView = webView
        syncSubviewFrames()
        webView.alphaValue = 1
        webView.needsDisplay = true
        webView.needsLayout = true
        window?.invalidateCursorRects(for: self)
        window?.makeFirstResponder(webView)
        return true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        syncSubviewFrames()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        syncSubviewFrames()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncSubviewFrames()
        // makeNSView/updateNSView can select a session before SwiftUI attaches
        // this host. Acquire keyboard focus once on attachment, not on every render.
        if let activeWebView, let window {
            window.makeFirstResponder(activeWebView)
        }
    }

    override func layout() {
        super.layout()
        syncSubviewFrames()
    }

    private func syncSubviewFrames() {
        guard bounds.width > 0, bounds.height > 0,
            let activeWebView, activeWebView.frame != bounds
        else { return }
        activeWebView.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let activeWebView, activeWebView.superview === self else { return nil }
        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return nil }
        return activeWebView.hitTest(point)
    }
}

struct ServiceWebView: NSViewRepresentable {
    let containerView: WebHostContainerView
    let session: BrowserSession?

    func makeNSView(context: Context) -> WebHostContainerView {
        if let session {
            containerView.show(session.webView)
        }
        return containerView
    }

    func updateNSView(_ nsView: WebHostContainerView, context: Context) {
        if let session {
            containerView.show(session.webView)
        }
    }
}
