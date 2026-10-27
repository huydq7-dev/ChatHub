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
                    filter: privacyFilter(document.getElementById('outgoing'))
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
                    filter: privacyFilter(document.getElementById('outgoing'))
                };
                """
        )
        #expect(disabled["privacy"] == "false")
        #expect(disabled["filter"] == "none")
    }

    @Test func zaloPrivacyShieldBlursChatAvatarsAndSenderNames() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 800), configuration: configuration)
        let navigation = ThemeNavigation()
        view.navigationDelegate = navigation
        let html = """
            <style>.zl-avatar, .avatar {border-radius:50%;overflow:hidden}</style>
            <div id="sidebarNav">
                <div id="main-tab"></div>
                <div class="conv-item"><div class="avatar"><img id="sidebarAvatarImg" src="data:image/png;base64,iVBORw0KGgo="></div></div>
            </div>
            <div id="header">
                <div class="header-info">
                    <img id="headerAvatarImg" src="data:image/png;base64,iVBORw0KGgo=">
                    <span id="headerTitle" class="header-title">Group Name</span>
                </div>
            </div>
            <div class="chat-message">
                <div id="msgAvatar" class="zl-avatar"><img id="msgAvatarImg" src="data:image/png;base64,iVBORw0KGgo="></div>
                <div class="chat-content">
                    <div class="card-sender-name" id="senderName">User Name</div>
                    <div id="outgoing" class="card" style="background:var(--blue-message)">Sample</div>
                </div>
            </div>
            <div class="chat-box-input-container"><div id="editor" contenteditable="true">Draft</div></div>
            """
        try await navigation.load(view, html: html, baseURL: ChatService.zalo.homeURL)
        let source = try #require(
            ServiceTheme.bootstrap(
                service: .zalo,
                appearance: BrowserAppearance(privacyShield: true)
            )
        )
        let privacy = try await evaluate(
            view,
            body: source + """
                return {
                    privacy: document.documentElement.getAttribute('data-chathub-privacy') || '',
                    msgAvatarFilter: privacyFilter(document.getElementById('msgAvatarImg')),
                    msgAvatarRadius: getComputedStyle(document.getElementById('msgAvatar')).borderRadius || '',
                    senderNameFilter: privacyFilter(document.getElementById('senderName')),
                    headerAvatarFilter: privacyFilter(document.getElementById('headerAvatarImg')),
                    headerTitleFilter: privacyFilter(document.getElementById('headerTitle')),
                    sidebarAvatarFilter: privacyFilter(document.getElementById('sidebarAvatarImg')),
                    outgoingFilter: privacyFilter(document.getElementById('outgoing'))
                };
                """
        )
        #expect(privacy["privacy"] == "true")
        #expect(privacy["msgAvatarFilter"]?.contains("blur") == true)
        #expect(privacy["msgAvatarRadius"] == "50%")
        #expect(privacy["senderNameFilter"]?.contains("blur") == true)
        #expect(privacy["headerAvatarFilter"]?.contains("blur") == true)
        #expect(privacy["headerTitleFilter"]?.contains("blur") == true)
        #expect(privacy["sidebarAvatarFilter"]?.contains("blur") == true)
        #expect(privacy["outgoingFilter"]?.contains("blur") == true)

        let disabled = try await evaluate(
            view,
            body: """
                globalThis.__chatHubNativeAppearance.update({privacyShield: false});
                return {
                    privacy: document.documentElement.getAttribute('data-chathub-privacy') || '',
                    msgAvatarFilter: privacyFilter(document.getElementById('msgAvatarImg')),
                    senderNameFilter: privacyFilter(document.getElementById('senderName')),
                    headerAvatarFilter: privacyFilter(document.getElementById('headerAvatarImg')),
                    outgoingFilter: privacyFilter(document.getElementById('outgoing'))
                };
                """
        )
        #expect(disabled["privacy"] == "false")
        #expect(disabled["msgAvatarFilter"] == "none")
        #expect(disabled["senderNameFilter"] == "none")
        #expect(disabled["headerAvatarFilter"] == "none")
        #expect(disabled["outgoingFilter"] == "none")
    }

    @Test func telegramPrivacyShieldBlursAndRevealsSidebarRow() async throws {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 800), configuration: configuration)
        let navigation = ThemeNavigation()
        view.navigationDelegate = navigation
        let html = """
            <div id="Main">
                <div id="LeftColumn">
                    <div class="chat-list">
                        <div id="chatRow" class="ListItem Chat chat-item-clickable">
                            <a id="chatBtn" class="ListItem-button" role="button">
                                <div class="Avatar" id="avatarWrap"><img id="avatarImg" src="data:image/png;base64,iVBORw0KGgo="></div>
                                <div class="info">
                                    <div class="title" id="chatTitle"><h3 id="chatH3"><span id="chatName">Friend Name</span></h3></div>
                                    <div class="subtitle" id="chatSub"><p class="last-message"><span id="chatMsg">Recent message snippet</span></p></div>
                                </div>
                            </a>
                        </div>
                    </div>
                </div>
                <div class="Message own"><div id="outgoing" class="message-content">Sample</div></div>
            </div>
            """
        try await navigation.load(view, html: html, baseURL: ChatService.telegram.homeURL)
        let source = try #require(
            ServiceTheme.bootstrap(
                service: .telegram,
                appearance: BrowserAppearance(privacyShield: true)
            )
        )
        let privacy = try await evaluate(
            view,
            body: source + """
                return {
                    privacy: document.documentElement.getAttribute('data-chathub-privacy') || '',
                    nameFilter: privacyFilter(document.getElementById('chatName')),
                    msgFilter: privacyFilter(document.getElementById('chatMsg')),
                    titleFilter: privacyFilter(document.getElementById('chatTitle')),
                    subFilter: privacyFilter(document.getElementById('chatSub')),
                    avatarFilter: privacyFilter(document.getElementById('avatarImg'))
                };
                """
        )
        #expect(privacy["privacy"] == "true")
        #expect(privacy["nameFilter"]?.contains("blur") == true)
        #expect(privacy["msgFilter"]?.contains("blur") == true)
        #expect(privacy["titleFilter"]?.contains("blur") == true)
        #expect(privacy["subFilter"]?.contains("blur") == true)
        #expect(privacy["avatarFilter"]?.contains("blur") == true)

        let peeked = try await evaluate(
            view,
            body: """
                document.getElementById('chatRow').setAttribute('data-chathub-peek', 'true');
                return {
                    nameFilter: privacyFilter(document.getElementById('chatName')),
                    msgFilter: privacyFilter(document.getElementById('chatMsg')),
                    titleFilter: privacyFilter(document.getElementById('chatTitle')),
                    subFilter: privacyFilter(document.getElementById('chatSub')),
                    avatarFilter: privacyFilter(document.getElementById('avatarImg'))
                };
                """
        )
        #expect(peeked["nameFilter"] == "none")
        #expect(peeked["msgFilter"] == "none")
        #expect(peeked["titleFilter"] == "none")
        #expect(peeked["subFilter"] == "none")
        #expect(peeked["avatarFilter"] == "none")
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
                <div id="outgoing" dir="auto" style="background:var(--chat-outgoing-message-bubble-background-color)">Sample</div>
                <div id="editor" contenteditable="true" role="textbox">Draft</div></div>
                """
        }
        return "<!doctype html><html><head></head><body>" + content + "</body></html>"
    }

    private func evaluate(_ view: WKWebView, body: String) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            let filterProbe = """
                // Blur applies to the rendered subtree, even when a leaf has filter:none.
                function privacyFilter(node) {
                    while (node) {
                        const filter = getComputedStyle(node).filter;
                        if (filter.includes('blur')) return filter;
                        node = node.parentElement;
                    }
                    return 'none';
                }
                """
            view.callAsyncJavaScript(filterProbe + body, arguments: [:], in: nil, in: .defaultClient) { result in
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
