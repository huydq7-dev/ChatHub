import Foundation
import Testing
import WebKit

@testable import ChatHub

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
struct BrowserNotificationTests {
    @Test func nativeClickRoutesToTheMatchingJavaScriptNotification() async throws {
        let session = BrowserSession(
            account: ChatAccount(
                service: .custom, name: "Click fixture", customURL: URL(string: "https://fixture.invalid")
            ))
        defer { session.tearDown() }
        // Capture bridge messages instead of posting real macOS notifications.
        let messages = NotificationMessages()
        let controller = session.webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "chatHubNotify", contentWorld: .page)
        controller.add(messages, contentWorld: .page, name: "chatHubNotify")
        try await loadFixture(session, marker: "clicks")
        _ = try await session.webView.evaluateJavaScript(
            """
            window.clicked = [];
            const first = new Notification('First');
            const second = new Notification('Second');
            first.onclick = () => window.clicked.push('first');
            second.onclick = () => window.clicked.push('second');
            true;
            """
        )
        for _ in 0..<100 where messages.notifications.count < 2 {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(messages.notifications.count == 2)
        let callbackID = try #require(messages.notifications.last?["callbackID"] as? String)
        session.handleNotificationClick(callbackID: callbackID)
        for _ in 0..<100 {
            let clicked = try await session.webView.evaluateJavaScript("window.clicked") as? [String]
            if clicked == ["second"] { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        session.handleNotificationClick(callbackID: "unknown\"\ncallback")
        session.handleNotificationClick(callbackID: "")
        let clicked = try await session.webView.evaluateJavaScript("window.clicked") as? [String]
        #expect(clicked == ["second"])
        await session.webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
    }

    @Test func nativeFocusSurvivesNavigationAndAppearanceChanges() async throws {
        // A unique test profile and synthetic HTML; never load a real chat service.
        let session = BrowserSession(
            account: ChatAccount(
                service: .custom, name: "Notification fixture", customURL: URL(string: "https://fixture.invalid")
            ))
        defer { session.tearDown() }
        session.setHubFocus(active: true)
        try await loadFixture(session, marker: "first")
        try await expectFocus(session, active: true)
        try await loadFixture(session, marker: "second")
        try await expectFocus(session, active: true)
        session.updateAppearance(BrowserAppearance(isDark: true))
        try await loadFixture(session, marker: "dark")
        try await expectFocus(session, active: true)
        session.setHubFocus(active: false)
        try await loadFixture(session, marker: "background")
        try await expectFocus(session, active: false)
        await session.webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
    }

    private func loadFixture(_ session: BrowserSession, marker: String) async throws {
        session.webView.loadHTMLString(
            """
            <!doctype html><script>
            window.focusAtDocumentStart = window.__chatHubIsFocused;
            window.fixtureMarker = '\(marker)';
            </script><title>Fixture</title>
            """, baseURL: session.account.url
        )
        for _ in 0..<500 {
            if let loaded = try? await session.webView.evaluateJavaScript("window.fixtureMarker") as? String,
                loaded == marker, session.state == .loaded
            {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Synthetic document did not finish loading: \(marker)")
        throw FixtureError.timeout
    }

    private func expectFocus(_ session: BrowserSession, active: Bool) async throws {
        let initial = try await session.webView.evaluateJavaScript("window.focusAtDocumentStart") as? Bool
        let current = try await session.webView.evaluateJavaScript("window.__chatHubIsFocused") as? Bool
        #expect(initial == active)
        #expect(current == active)
    }

    private enum FixtureError: Error { case timeout }
}

@MainActor
private final class NotificationMessages: NSObject, WKScriptMessageHandler {
    var notifications: [[String: Any]] = []

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: Any], payload["kind"] as? String == "notify" else { return }
        notifications.append(payload)
    }
}
