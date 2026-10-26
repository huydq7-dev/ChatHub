import AppKit
import WebKit

/// A visible authentication window, using the originating account's WebKit configuration.
@MainActor
final class BrowserPopup: NSObject, WKUIDelegate, WKNavigationDelegate, NSWindowDelegate {
    let webView: WKWebView
    private let window: NSWindow
    private var urlObservation: NSKeyValueObservation?
    private(set) var isOpen = true

    init(configuration: WKWebViewConfiguration, initialURL: URL) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false
        )
        super.init()
        window.isReleasedWhenClosed = false
        window.title = initialURL.host ?? "ChatHub"
        window.contentView = webView
        window.delegate = self
        webView.uiDelegate = self
        webView.navigationDelegate = self
        urlObservation = webView.observe(\.url) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                window.title = (webView.url?.host ?? "ChatHub") + " — ChatHub"
            }
        }
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    func close() { window.close() }

    func windowWillClose(_ notification: Notification) {
        isOpen = false
        webView.stopLoading()
        webView.uiDelegate = nil
        webView.navigationDelegate = nil
        urlObservation = nil
    }

    func webViewDidClose(_ webView: WKWebView) { close() }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
            url.scheme == "https", url.user == nil, url.password == nil
        else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
