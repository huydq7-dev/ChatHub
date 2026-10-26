import AppKit
import Observation
import UserNotifications
import WebKit

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
final class HubNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HubNotificationCenter()
    var onSelectAccount: ((UUID) -> Void)?
    private var unreadByAccount: [UUID: Int] = [:]
    private var lastNotificationTime: [UUID: Date] = [:]
    private var isConfigured = false

    private var canUseUserNotifications: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func configure() {
        guard canUseUserNotifications, !isConfigured else { return }
        isConfigured = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func updateUnreadCount(_ count: Int, for account: ChatAccount) {
        let clamped = max(0, count)
        let previous = unreadByAccount[account.id] ?? 0
        guard clamped != previous else { return }
        unreadByAccount[account.id] = clamped
        updateDockBadge()
        if clamped > previous {
            let now = Date()
            if let last = lastNotificationTime[account.id], now.timeIntervalSince(last) < 3.0 {
                return
            }
            let body =
                clamped == 1
                ? tr("You have 1 unread message.")
                : String(format: tr("You have %d unread messages."), clamped)
            postNotification(account: account, title: account.name, body: body)
        }
    }

    func removeAccount(_ accountID: UUID) {
        unreadByAccount.removeValue(forKey: accountID)
        lastNotificationTime.removeValue(forKey: accountID)
        updateDockBadge()
    }

    private func updateDockBadge() {
        let total = unreadByAccount.values.reduce(0, +)
        NSApplication.shared.dockTile.badgeLabel = total > 0 ? (total > 99 ? "99+" : "\(total)") : nil
    }

    func postNotification(account: ChatAccount, title: String, body: String) {
        lastNotificationTime[account.id] = Date()
        if !NSApplication.shared.isActive {
            NSApplication.shared.requestUserAttention(.informationalRequest)
        }
        guard canUseUserNotifications else { return }
        configure()
        let center = UNUserNotificationCenter.current()
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = UNMutableNotificationContent()
        if cleanTitle.isEmpty || cleanTitle == account.name {
            content.title = account.name
        } else {
            content.title = "\(account.name) · \(cleanTitle)"
        }
        content.body = cleanBody.isEmpty ? tr("New message received") : cleanBody
        content.sound = .default
        content.userInfo = ["accountID": account.id.uuidString]
        let request = UNNotificationRequest(
            identifier: "chathub.\(account.id.uuidString).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let accountIDString = response.notification.request.content.userInfo["accountID"] as? String
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "workspace" })
                ?? NSApplication.shared.windows.first(where: { $0.canBecomeMain })
            {
                window.makeKeyAndOrderFront(nil)
            }
            if let accountIDString, let uuid = UUID(uuidString: accountIDString) {
                HubNotificationCenter.shared.onSelectAccount?(uuid)
            }
        }
        completionHandler()
    }
}

@MainActor
private final class NotificationScriptHandler: NSObject, WKScriptMessageHandler {
    weak var session: BrowserSession?

    init(session: BrowserSession) {
        self.session = session
    }

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any],
            let kind = body["kind"] as? String
        else { return }
        session?.handleScriptNotification(kind: kind, payload: body)
    }
}

@MainActor @Observable
final class BrowserSession: NSObject {
    enum State: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    private static let notificationBridgeName = "chatHubNotify"
    private static let notificationBridgeScript = """
        (function() {
            if (window.__chatHubNotifyInstalled) return;
            window.__chatHubNotifyInstalled = true;
            const post = (payload) => {
                try { window.webkit?.messageHandlers?.chatHubNotify?.postMessage(payload); } catch (_) {}
            };
            class ChatHubNotification extends EventTarget {
                static get permission() { return "granted"; }
                static requestPermission(cb) {
                    if (typeof cb === "function") cb("granted");
                    return Promise.resolve("granted");
                }
                constructor(title, options = {}) {
                    super();
                    this.title = String(title ?? "");
                    this.body = String(options?.body ?? "");
                    this.tag = String(options?.tag ?? "");
                    this.onclick = null;
                    this.onclose = null;
                    post({
                        kind: "notify",
                        title: this.title.slice(0, 160),
                        body: this.body.slice(0, 300),
                        tag: this.tag.slice(0, 80)
                    });
                }
                close() {
                    const ev = new Event("close");
                    this.dispatchEvent(ev);
                    if (typeof this.onclose === "function") this.onclose(ev);
                }
            }
            try {
                window.Notification = ChatHubNotification;
            } catch (_) {}

            let lastBadgeCount = -1;
            let badgeTimer = null;
            function computeBadgeCount() {
                badgeTimer = null;
                const titleMatch = document.title.match(/\\((\\d+)\\+?\\)|\\[(\\d+)\\+?\\]/);
                if (titleMatch) {
                    const n = parseInt(titleMatch[1] || titleMatch[2], 10);
                    if (!Number.isNaN(n) && n !== lastBadgeCount) {
                        lastBadgeCount = n;
                        post({ kind: "badge", count: n });
                        return;
                    }
                }
                let count = 0;
                const host = location.hostname;
                if (host === "chat.zalo.me") {
                    const navBadge = document.querySelector("#main-tab .z-noti-badge");
                    const navNum = navBadge ? parseInt(navBadge.textContent || "", 10) : 0;
                    if (navNum > 0) {
                        count = navNum;
                    } else {
                        for (const el of document.querySelectorAll(".conv-action__unread .z-noti-badge, .conv-unread")) {
                            const v = parseInt(el.textContent || "", 10);
                            count += Number.isNaN(v) ? 1 : v;
                        }
                    }
                } else if (host === "web.telegram.org") {
                    for (const el of document.querySelectorAll(".ChatBadge.unread:not(.muted)")) {
                        const v = parseInt(el.textContent || "", 10);
                        count += Number.isNaN(v) ? 1 : v;
                    }
                } else if (host.includes("facebook.com") || host.includes("messenger.com")) {
                    count = document.querySelectorAll('[role="navigation"] [aria-label*="unread" i], [role="navigation"] [aria-label*="chưa đọc" i]').length;
                }
                if (count !== lastBadgeCount) {
                    lastBadgeCount = count;
                    post({ kind: "badge", count });
                }
            }
            function scheduleBadgeCheck() {
                if (badgeTimer !== null) return;
                badgeTimer = setTimeout(computeBadgeCount, 1200);
            }
            if (document.documentElement) {
                new MutationObserver(scheduleBadgeCheck).observe(document.documentElement, {
                    childList: true,
                    subtree: true,
                    characterData: true
                });
                setTimeout(computeBadgeCount, 1500);
            }
        })();
        """

    let account: ChatAccount
    private(set) var state: State = .idle
    private(set) var progress = 0.0
    private(set) var pageTitle = ""
    private(set) var unreadCount = 0
    private(set) var currentURL: URL?
    private(set) var canGoBack = false
    private(set) var canGoForward = false
    var notice: String?
    var externalURL: URL?
    var isFinding = false
    var findQuery = ""
    var findHasNoMatches = false
    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var popups: [BrowserPopup] = []
    @ObservationIgnored private var downloads: [ObjectIdentifier: DownloadHandler] = [:]
    @ObservationIgnored private var started = false
    @ObservationIgnored private var hasLoadedPage = false
    @ObservationIgnored private var hasInstalledScripts = false
    @ObservationIgnored private var appearance: BrowserAppearance

    init(account: ChatAccount, appearance initialAppearance: BrowserAppearance = BrowserAppearance()) {
        self.account = account
        self.appearance = initialAppearance
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = "ChatHub/0.2.0"
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        let scriptHandler = NotificationScriptHandler(session: self)
        configuration.userContentController.add(
            scriptHandler, contentWorld: .page, name: Self.notificationBridgeName
        )
        installUserScripts()
        webView.appearance = NSAppearance(named: initialAppearance.isDark ? .darkAqua : .aqua)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.isInspectable = false
        webView.underPageBackgroundColor = .windowBackgroundColor
        observations = [
            webView.observe(\.estimatedProgress) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    progress = webView.estimatedProgress
                }
            },
            webView.observe(\.title) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let title = webView.title ?? ""
                    pageTitle = title
                    if let parsed = Self.parseUnreadCount(from: title) {
                        applyUnreadCount(parsed)
                    }
                }
            },
            webView.observe(\.url) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    currentURL = webView.url
                    canGoBack = webView.canGoBack
                    canGoForward = webView.canGoForward
                    syncPageAppearance()
                }
            },
        ]
    }

    var hasFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    static func parseUnreadCount(from title: String) -> Int? {
        guard let range = title.range(of: #"[\(\[](\d+)\+?[\)\]]"#, options: .regularExpression) else {
            return nil
        }
        let match = title[range]
        let digits = match.filter(\.isNumber)
        return Int(digits)
    }

    fileprivate func handleScriptNotification(kind: String, payload: [String: Any]) {
        switch kind {
        case "notify":
            let title = (payload["title"] as? String) ?? ""
            let body = (payload["body"] as? String) ?? ""
            HubNotificationCenter.shared.postNotification(account: account, title: title, body: body)
        case "badge":
            if let count = payload["count"] as? Int {
                applyUnreadCount(count)
            }
        default:
            break
        }
    }

    private func applyUnreadCount(_ count: Int) {
        let clamped = max(0, count)
        unreadCount = clamped
        HubNotificationCenter.shared.updateUnreadCount(clamped, for: account)
    }

    func updateAppearance(_ newAppearance: BrowserAppearance) {
        let changed = self.appearance != newAppearance || !hasInstalledScripts
        self.appearance = newAppearance
        let targetName: NSAppearance.Name = newAppearance.isDark ? .darkAqua : .aqua
        if webView.appearance?.name != targetName {
            webView.appearance = NSAppearance(named: targetName)
        }
        if changed {
            installUserScripts()
        }
        syncPageAppearance()
    }

    private func syncPageAppearance() {
        guard WebAppearancePolicy.supportsService(account.service) else { return }
        var currentAppearance = appearance
        currentAppearance.themeEnabled =
            appearance.themeEnabled
            && WebAppearancePolicy.supportsTheme(service: account.service, url: webView.url)
        webView.callAsyncJavaScript(
            "globalThis.__chatHubNativeAppearance?.update(settings); return true;",
            arguments: ["settings": ServiceTheme.settings(currentAppearance)], in: nil, in: .defaultClient,
            completionHandler: nil
        )
    }

    private func installUserScripts() {
        hasInstalledScripts = true
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(
            WKUserScript(
                source: Self.notificationBridgeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                in: .page
            ))
        if let source = ServiceTheme.bootstrap(service: account.service, appearance: appearance) {
            controller.addUserScript(
                WKUserScript(
                    source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient
                ))
        }
    }

    func startIfNeeded() {
        guard !started else { return }
        started = true
        loadHome()
    }

    func didActivate() {
        webView.needsDisplay = true
        webView.needsLayout = true
        guard hasLoadedPage, account.service == .messenger else { return }
        webView.evaluateJavaScript(
            """
            (function() {
                window.dispatchEvent(new Event("resize"));
                const main = document.querySelector('[role="main"]');
                if (!main) return;
                for (const scroller of main.querySelectorAll('.x1odjw0f, .x10wlt62, [role="grid"]')) {
                    if (scroller.scrollHeight > scroller.clientHeight) {
                        const top = scroller.scrollTop;
                        scroller.scrollTop = top > 0 ? top - 1 : top + 1;
                        scroller.scrollTop = top;
                        scroller.dispatchEvent(new Event("scroll", { bubbles: true }));
                    }
                }
            })();
            """,
            completionHandler: nil
        )
    }

    func loadHome() {
        guard let url = account.url else {
            state = .failed(tr("This account has an invalid website address."))
            return
        }
        state = .loading
        webView.load(URLRequest(url: url))
    }

    func reload() {
        notice = nil
        state = .loading
        if webView.url == nil { loadHome() } else { webView.reload() }
    }

    func openInBrowser() {
        guard let url = currentURL ?? account.url else { return }
        NSWorkspace.shared.open(url)
    }

    func showFind() {
        isFinding = true
    }

    func find(backwards: Bool = false) {
        guard !findQuery.isEmpty else {
            findHasNoMatches = false
            return
        }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        webView.find(findQuery, configuration: configuration) { [weak self] result in
            self?.findHasNoMatches = !result.matchFound
        }
    }

    func tearDown() {
        webView.stopLoading()
        webView.removeFromSuperview()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: Self.notificationBridgeName, contentWorld: .page
        )
        HubNotificationCenter.shared.removeAccount(account.id)
        observations.removeAll()
        let activeDownloads = Array(downloads.values)
        for download in activeDownloads { download.cancel() }
        downloads.removeAll()
        for popup in popups { popup.close() }
        popups.removeAll()
    }

    private func fail(_ error: Error) {
        let nsError = error as NSError
        if WebNavigationFailure.isCancellation(nsError) {
            if hasLoadedPage { state = .loaded }
            return
        }
        state = .failed(error.localizedDescription)
    }

    private func showDialog(
        _ alert: NSAlert, in view: WKWebView,
        completion: @escaping @MainActor @Sendable (NSApplication.ModalResponse) -> Void
    ) {
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(.cancel)
        }
    }
}

extension BrowserSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        state = .loading
        notice = nil
        externalURL = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasLoadedPage = true
        state = .loaded
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        updateAppearance(appearance)
        didActivate()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        state = .failed(tr("This service stopped responding. Reload to restore your session."))
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        // Subframes are governed by WebKit's origin rules. Top-level navigation is constrained below.
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        switch NavigationPolicy(account: account).disposition(for: url) {
        case .inApp: decisionHandler(.allow)
        case .externalBrowser:
            decisionHandler(.cancel)
            state = hasLoadedPage ? .loaded : .idle
            if navigationAction.navigationType == .linkActivated {
                NSWorkspace.shared.open(url)
            } else if navigationAction.targetFrame != nil {
                externalURL = url
                notice = tr("This service needs to open another website to continue.")
            }
        case .blocked:
            decisionHandler(.cancel)
            state = hasLoadedPage ? .loaded : .idle
            notice = tr("An unsupported link was blocked. Open the service in your browser if needed.")
        }
    }

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        retainDownload(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        retainDownload(download)
    }

    private func retainDownload(_ download: WKDownload) {
        let id = ObjectIdentifier(download)
        let handler = DownloadHandler(download: download, window: webView.window) { [weak self] error in
            self?.downloads.removeValue(forKey: id)
            if let error { self?.notice = error.localizedDescription }
        }
        downloads[id] = handler
        download.delegate = handler
    }
}

extension BrowserSession: WKUIDelegate {
    func webView(
        _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        guard NavigationPolicy(account: account).disposition(for: url) == .inApp else {
            if ["https", "http"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
            return nil
        }
        let popup = BrowserPopup(configuration: configuration, initialURL: url)
        popups.removeAll { !$0.isOpen }
        popups.append(popup)
        popup.show()
        return popup.webView
    }

    func webView(
        _ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        guard let window = webView.window else {
            completionHandler(nil)
            return
        }
        panel.beginSheetModal(for: window) { response in completionHandler(response == .OK ? panel.urls : nil) }
    }

    func webView(
        _ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = String(message.prefix(4000))
        alert.addButton(withTitle: tr("OK"))
        showDialog(alert, in: webView) { _ in completionHandler() }
    }

    func webView(
        _ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = String(message.prefix(4000))
        alert.addButton(withTitle: tr("OK"))
        alert.addButton(withTitle: tr("Cancel"))
        showDialog(alert, in: webView) { completionHandler($0 == .alertFirstButtonReturn) }
    }

    func webView(
        _ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?, initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = String(prompt.prefix(4000))
        let input = NSTextField(string: defaultText ?? "")
        input.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: tr("OK"))
        alert.addButton(withTitle: tr("Cancel"))
        showDialog(alert, in: webView) { completionHandler($0 == .alertFirstButtonReturn ? input.stringValue : nil) }
    }

    func webView(
        _ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.prompt)
    }
}
