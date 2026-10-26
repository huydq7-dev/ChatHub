import SwiftUI
import WebKit

final class WebHostContainerView: NSView {
    private weak var activeWebView: WKWebView?

    func attach(_ webView: WKWebView) {
        guard webView.superview !== self else { return }
        let initialBounds = bounds.isEmpty ? NSRect(x: 0, y: 0, width: 800, height: 600) : bounds
        webView.frame = initialBounds
        webView.autoresizingMask = [.width, .height]
        webView.alphaValue = 0.0
        addSubview(webView, positioned: .below, relativeTo: nil)
    }

    func detach(_ webView: WKWebView) {
        if activeWebView === webView {
            activeWebView = nil
        }
        webView.removeFromSuperview()
    }

    func show(_ webView: WKWebView) {
        if webView.superview !== self {
            let initialBounds = bounds.isEmpty ? NSRect(x: 0, y: 0, width: 800, height: 600) : bounds
            webView.frame = initialBounds
            webView.autoresizingMask = [.width, .height]
            addSubview(webView, positioned: .above, relativeTo: nil)
        } else if subviews.last !== webView {
            addSubview(webView, positioned: .above, relativeTo: nil)
        }
        activeWebView = webView
        for subview in subviews {
            let isActive = (subview === webView)
            subview.alphaValue = isActive ? 1.0 : 0.0
            if isActive {
                if !bounds.isEmpty {
                    subview.frame = bounds
                }
                subview.needsDisplay = true
                subview.needsLayout = true
            }
        }
        window?.invalidateCursorRects(for: self)
        window?.makeFirstResponder(webView)
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
    }

    override func layout() {
        super.layout()
        syncSubviewFrames()
    }

    private func syncSubviewFrames() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        for subview in subviews where subview.frame != bounds {
            subview.frame = bounds
        }
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
