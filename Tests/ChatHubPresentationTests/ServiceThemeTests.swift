import Foundation
import Testing
import WebKit

@testable import ChatHub

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Render the bundled adapters in real WebKit, with synthetic markup only.
/// This verifies the CSS contract; live provider compatibility is checked separately.
@MainActor
struct ServiceThemeTests {
    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func allAdaptersRenderSharedLightAndDarkSurfaces(service: ChatService) async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 800), configuration: configuration)
        let navigation = ThemeNavigation()
        view.navigationDelegate = navigation
        try await navigation.load(view, html: fixture(service), baseURL: service.homeURL)
        let source = try #require(ServiceTheme.bootstrap(service: service, appearance: BrowserAppearance()))
        let light = try await evaluate(view, body: source + probe)
        #expect(light["theme"] == "light")
        #expect(light["canvas"] == "rgb(243, 243, 245)")
        #expect(light["text"] == "rgb(35, 35, 39)")
        #expect(light["outgoing"] == "rgb(234, 228, 252)")
        #expect(light["outline"] == "none")
        #expect(light["fontSize"] == "14.5px")
        #expect(light["fontWeight"] == "400")
        let dark = try await evaluate(
            view,
            body:
                "globalThis.__chatHubNativeAppearance.update({enabled:true,dark:true,reduceMotion:true,showServiceTools:false});"
                + probe
        )
        #expect(dark["theme"] == "dark")
        #expect(dark["canvas"] == "rgb(32, 32, 35)")
        #expect(dark["text"] == "rgb(238, 238, 242)")
        #expect(dark["outgoing"] == "rgb(66, 52, 95)")
        #expect(dark["outline"] == "none")
        #expect(dark["fontSize"] == "14.5px")
        #expect(dark["fontWeight"] == "400")
        let customized = try await evaluate(
            view,
            body:
                "globalThis.__chatHubNativeAppearance.update({enabled:true,dark:true,reduceMotion:false,showServiceTools:false,accent:'ocean',density:'comfortable',textScale:'large'});"
                + probe
        )
        #expect(customized["accent"] == "ocean")
        #expect(customized["density"] == "comfortable")
        #expect(customized["textScale"] == "large")
        #expect(customized["outgoing"] == "rgb(38, 59, 94)")
        #expect(customized["fontSize"] == "16px")
        let restored = try await evaluate(
            view,
            body:
                "globalThis.__chatHubNativeAppearance.update({enabled:false}); return {theme: document.documentElement.getAttribute('data-chathub-theme') || 'original'};"
        )
        #expect(restored["theme"] == "original")
    }

    @Test func parsesUnreadCountFromDocumentTitle() {
        #expect(BrowserSession.parseUnreadCount(from: "(3) Zalo") == 3)
        #expect(BrowserSession.parseUnreadCount(from: "Telegram (12)") == 12)
        #expect(BrowserSession.parseUnreadCount(from: "[99+] Messenger") == 99)
        #expect(BrowserSession.parseUnreadCount(from: "Zalo Web") == nil)
    }

    @Test(arguments: [ChatService.telegram, .zalo, .messenger])
    func privacyShieldAppliesBlurAcrossAllServices(service: ChatService) async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 800), configuration: configuration)
        let navigation = ThemeNavigation()
        view.navigationDelegate = navigation
        try await navigation.load(view, html: fixture(service), baseURL: service.homeURL)
        let source = try #require(
            ServiceTheme.bootstrap(
                service: service,
                appearance: BrowserAppearance(privacyShield: true)
            )
        )
        let privacy = try await evaluate(
            view,
            body: source + """
                return {
                    privacy: document.documentElement.getAttribute('data-chathub-privacy') || '',
                    filter: getComputedStyle(document.getElementById('outgoing')).filter || ''
                };
                """
        )
        #expect(privacy["privacy"] == "true")
        #expect(privacy["filter"]?.contains("blur") == true)

        let disabled = try await evaluate(
            view,
            body: """
                globalThis.__chatHubNativeAppearance.update({privacyShield: false});
                return {
                    privacy: document.documentElement.getAttribute('data-chathub-privacy') || '',
                    filter: getComputedStyle(document.getElementById('outgoing')).filter || ''
                };
                """
        )
        #expect(disabled["privacy"] == "false")
        #expect(disabled["filter"] == "none")
    }

    @Test func workspaceWindowStyleTogglesFloatingLevel() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        WorkspaceWindowStyle.apply(to: window, alwaysOnTop: false)
        #expect(window.level == .normal)
        WorkspaceWindowStyle.apply(to: window, alwaysOnTop: true)
        #expect(window.level == .floating)
        WorkspaceWindowStyle.apply(to: window, alwaysOnTop: false)
        #expect(window.level == .normal)
    }

    private var probe: String {
        """
        const editor = document.getElementById('editor'); editor.focus();
        const editorStyle = getComputedStyle(editor);
        return {
          theme: document.documentElement.getAttribute('data-chathub-theme'),
          accent: document.documentElement.getAttribute('data-chathub-accent'),
          density: document.documentElement.getAttribute('data-chathub-density'),
          textScale: document.documentElement.getAttribute('data-chathub-text-scale'),
          canvas: getComputedStyle(document.body).backgroundColor,
          text: editorStyle.color,
          outgoing: getComputedStyle(document.getElementById('outgoing')).backgroundColor,
          outline: editorStyle.outlineStyle,
          fontSize: editorStyle.fontSize,
          fontWeight: editorStyle.fontWeight
        };
        """
    }

    private func fixture(_ service: ChatService) -> String {
        let content: String
        switch service {
        case .zalo:
            content = """
                <div id="sidebarNav"><div id="main-tab"></div></div>
                <div class="chat-content"><div id="outgoing" class="card" style="background:var(--blue-message)">Sample</div></div>
                <div class="chat-box-input-container"><div id="editor" contenteditable="true">Draft</div></div>
                """
        case .telegram:
            content = """
                <div id="Main"><div id="LeftColumn"></div><div class="Message own"><div id="outgoing" class="message-content" style="background:var(--background-color)">Sample</div></div>
                <div class="Composer"><div id="editor" contenteditable="true">Draft</div></div></div>
                """
        default:
            content = """
                <div role="navigation"></div><div role="grid"></div><div role="main">
                <div id="outgoing" style="background:var(--chat-outgoing-message-bubble-background-color)">Sample</div>
                <div id="editor" contenteditable="true" role="textbox">Draft</div></div>
                """
        }
        return "<!doctype html><html><head></head><body>" + content + "</body></html>"
    }

    private func evaluate(_ view: WKWebView, body: String) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            view.callAsyncJavaScript(body, arguments: [:], in: nil, in: .defaultClient) { result in
                switch result {
                case .success(let value): continuation.resume(returning: value as? [String: String] ?? [:])
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}

@MainActor
private final class ThemeNavigation: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, any Error>?

    func load(_ view: WKWebView, html: String, baseURL: URL?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            view.loadHTMLString(html, baseURL: baseURL)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
