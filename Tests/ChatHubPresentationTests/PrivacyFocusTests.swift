import Foundation
import Testing
import WebKit

@testable import ChatHub

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
struct PrivacyFocusTests {
    @Test func nativeWorkspaceFocusReachesIsolatedPrivacyWorld() async throws {
        // A unique profile and inline HTML only; no provider account or network load.
        let session = BrowserSession(
            account: ChatAccount(service: .telegram, name: "Privacy focus fixture"),
            appearance: BrowserAppearance(themeEnabled: false, privacyShield: true)
        )
        defer { session.tearDown() }
        do {
            try await exerciseFocus(session)
        } catch {
            await clearProfile(session)
            throw error
        }
        await clearProfile(session)
    }

    private func exerciseFocus(_ session: BrowserSession) async throws {
        try await loadFixture(session, marker: "initial-background")
        let background = try await peek(session)
        #expect(background["initialFocus"] == "false")
        #expect(background["peek"] == "false")
        #expect(background["filter"] == "blur(6px)")

        session.setHubFocus(active: true)
        let active = try await peek(session)
        #expect(active["peek"] == "true")
        #expect(active["filter"] == "none")

        // DOM keyboard focus can leave the WebView for a native toolbar while the
        // workspace remains active. Hover must still work without clicking the chat.
        let toolbar = try await peek(session, prefix: "globalThis.dispatchEvent(new Event('blur'));")
        #expect(toolbar["peek"] == "true")
        #expect(toolbar["filter"] == "none")

        session.setHubFocus(active: false)
        let covered = try await peek(session)
        #expect(covered["peek"] == "false")
        #expect(covered["filter"] == "blur(6px)")

        session.setHubFocus(active: true)
        try await loadFixture(session, marker: "active-navigation")
        let navigated = try await peek(session)
        #expect(navigated["initialFocus"] == "true")
        #expect(navigated["peek"] == "true")

        session.setHubFocus(active: false)
        try await loadFixture(session, marker: "background-navigation")
        let navigatedBackground = try await peek(session)
        #expect(navigatedBackground["initialFocus"] == "false")
        #expect(navigatedBackground["peek"] == "false")
        #expect(navigatedBackground["filter"] == "blur(6px)")
    }

    private func loadFixture(_ session: BrowserSession, marker: String) async throws {
        session.webView.loadHTMLString(
            """
            <!doctype html><title>Privacy focus fixture</title>
            <div id="Main"><div class="Chat" id="row"><div class="title" id="name">Synthetic contact</div></div></div>
            <script>window.fixtureMarker = '\(marker)';</script>
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
        Issue.record("Synthetic privacy document did not finish loading: \(marker)")
        throw FixtureError.timeout
    }

    private func peek(_ session: BrowserSession, prefix: String = "") async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            session.webView.callAsyncJavaScript(
                prefix + """
                    // A detached fixture is hidden; simulate only workspace visibility.
                    Object.defineProperty(document, 'hidden', {configurable:true, value:false});
                    document.getElementById('name').dispatchEvent(new MouseEvent('pointermove', {bubbles:true}));
                    return {
                        initialFocus: String(globalThis.__chatHubPrivacyFocused),
                        peek: String(document.getElementById('row').getAttribute('data-chathub-peek') === 'true'),
                        filter: getComputedStyle(document.getElementById('name')).filter
                    };
                    """, arguments: [:], in: nil, in: .defaultClient
            ) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value as? [String: String] ?? [:])
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    private func clearProfile(_ session: BrowserSession) async {
        await session.webView.configuration.websiteDataStore.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast
        )
    }

    private enum FixtureError: Error { case timeout }
}
