import SwiftUI
import WebKit

final class WebHostContainerView: NSView {
    private weak var activeWebView: WKWebView?

    func show(_ webView: WKWebView) {
        if webView.superview !== self {
            webView.frame = bounds
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
                subview.frame = bounds
                subview.needsDisplay = true
                subview.needsLayout = true
            }
        }
        window?.invalidateCursorRects(for: self)
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
    let session: BrowserSession

    func makeNSView(context: Context) -> WebHostContainerView {
        let container = WebHostContainerView()
        container.show(session.webView)
        return container
    }

    func updateNSView(_ nsView: WebHostContainerView, context: Context) {
        nsView.show(session.webView)
    }
}
