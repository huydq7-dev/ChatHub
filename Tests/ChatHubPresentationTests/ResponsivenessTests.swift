import AppKit
import Foundation
import Testing
import WebKit

@testable import ChatHub

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
struct ResponsivenessTests {
    @Test func repeatedHostUpdatesDoNotTakeKeyboardFocus() {
        let window = CountingWindow()
        defer { window.close() }
        let host = WebHostContainerView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        window.contentView = host
        let view = WKWebView(frame: .zero, configuration: transientConfiguration())
        host.attach(view)
        host.show(view)
        window.responderRequests = 0
        for _ in 0..<100 { host.show(view) }
        print("PERF_METRIC repeatedHostFocusRequests=\(window.responderRequests)")
        #expect(window.responderRequests == 0)
    }

    @Test func resizingHostLeavesBackgroundViewportsUnchanged() {
        let host = WebHostContainerView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let active = WKWebView(frame: .zero, configuration: transientConfiguration())
        let background = WKWebView(frame: .zero, configuration: transientConfiguration())
        host.attach(active)
        host.attach(background)
        host.show(active)
        let backgroundFrame = background.frame
        var backgroundResizes = 0
        for step in 1...100 {
            host.setFrameSize(NSSize(width: 800 + step, height: 600))
            if background.frame != backgroundFrame { backgroundResizes += 1 }
        }
        print("PERF_METRIC backgroundViewportResizes=\(backgroundResizes)")
        #expect(backgroundResizes == 0)
        #expect(active.frame == host.bounds)
        host.show(background)
        #expect(background.frame == host.bounds)
        #expect(background.alphaValue == 1)
        #expect(active.alphaValue == 0)
    }

    @Test func repeatedWindowConfigurationDoesNotForceSynchronousLayout() {
        let window = CountingWindow()
        defer { window.close() }
        let delegate = AppDelegate()
        delegate.configureWindow(window)
        window.forcedLayouts = 0
        for _ in 0..<100 { delegate.configureWindow(window) }
        print("PERF_METRIC forcedWindowLayouts=\(window.forcedLayouts)")
        #expect(window.forcedLayouts == 0)
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.titleVisibility == .hidden)
        #expect(window.titlebarAppearsTransparent)
    }

    @Test func messengerActivationDoesNotSynthesizeScrollOrResize() async throws {
        let session = fixtureSession()
        defer { session.tearDown() }
        try await loadFixture(session)
        _ = try await session.webView.evaluateJavaScript("window.syntheticEvents = 0; true;")
        session.didActivate()
        let events = try await session.webView.evaluateJavaScript("window.syntheticEvents") as? Int
        print("PERF_METRIC messengerSyntheticEvents=\(events ?? -1)")
        #expect(events == 0)
    }

    @Test func duplicateFocusAndAppearanceUpdatesDoNotEnterJavaScript() async throws {
        let session = fixtureSession()
        defer { session.tearDown() }
        try await loadFixture(session)
        _ = try await session.webView.evaluateJavaScript(
            """
            window.focusCalls = 0;
            const nativeSetter = window.__chatHubSetFocused;
            window.__chatHubSetFocused = function(value) { window.focusCalls++; nativeSetter(value); };
            true;
            """
        )
        _ = try await evaluateIsolated(
            session.webView,
            """
            globalThis.appearanceCalls = 0;
            const original = globalThis.__chatHubNativeAppearance;
            globalThis.__chatHubNativeAppearance = {
                update(settings) { globalThis.appearanceCalls++; return original.update(settings); }
            };
            return 0;
            """
        )
        for _ in 0..<100 {
            session.setHubFocus(active: false)
            session.updateAppearance(BrowserAppearance())
        }
        let focusCalls = try await session.webView.evaluateJavaScript("window.focusCalls") as? Int
        let appearanceCalls = try await evaluateIsolated(session.webView, "return globalThis.appearanceCalls;")
        print("PERF_METRIC duplicateFocusCalls=\(focusCalls ?? -1)")
        print("PERF_METRIC duplicateAppearanceCalls=\(appearanceCalls)")
        #expect(focusCalls == 0)
        #expect(appearanceCalls == 0)
        session.setHubFocus(active: true)
        session.updateAppearance(BrowserAppearance(isDark: true))
        let focused = try await session.webView.evaluateJavaScript("window.__chatHubIsFocused") as? Bool
        let theme =
            try await session.webView.evaluateJavaScript(
                "document.documentElement.getAttribute('data-chathub-theme')") as? String
        #expect(focused == true)
        #expect(theme == "dark")
    }

    private func transientConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        return configuration
    }

    private func evaluateIsolated(_ view: WKWebView, _ body: String) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            view.callAsyncJavaScript(body, arguments: [:], in: nil, in: .defaultClient) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value as? Int ?? -1)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fixtureSession() -> BrowserSession {
        BrowserSession(account: ChatAccount(service: .messenger, name: "Performance fixture"))
    }

    private func loadFixture(_ session: BrowserSession) async throws {
        let rows = String(
            repeating:
                "<div role='grid' style='height:12px;overflow:auto'><div style='height:200px'>Fixture</div></div>",
            count: 100
        )
        session.webView.loadHTMLString(
            """
            <!doctype html><title>Fixture</title><main role="main">\(rows)</main>
            <script>
            window.syntheticEvents = 0;
            for (const name of ['scroll', 'resize']) {
                window.addEventListener(name, event => {
                    if (!event.isTrusted) window.syntheticEvents++;
                }, true);
            }
            </script>
            """, baseURL: session.account.url
        )
        for _ in 0..<500 {
            if session.state == .loaded { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw FixtureError.timeout
    }

    private enum FixtureError: Error { case timeout }
}

@MainActor
private final class CountingWindow: NSWindow {
    var responderRequests = 0
    var forcedLayouts = 0

    init() {
        _ = NSApplication.shared
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered,
            defer: true)
        isReleasedWhenClosed = false
    }

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        responderRequests += 1
        return super.makeFirstResponder(responder)
    }

    override func layoutIfNeeded() {
        forcedLayouts += 1
        super.layoutIfNeeded()
    }
}
