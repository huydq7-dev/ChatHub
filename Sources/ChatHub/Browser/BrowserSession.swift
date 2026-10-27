import AppKit
import Observation
@preconcurrency import UserNotifications
import WebKit

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor
final class HubNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HubNotificationCenter()
    var onSelectAccount: ((UUID) -> Void)?
    var onNotificationClick: ((UUID, String) -> Void)?
    private var unreadByAccount: [UUID: Int] = [:]
    private var initializedAccounts: Set<UUID> = []
    private var lastNotificationTime: [UUID: Date] = [:]
    private var lastRichNotificationTime: [UUID: Date] = [:]
    private var recentNotificationFingerprints: [String: Date] = [:]
    private var pendingBadgeFallbackTasks: [UUID: Task<Void, Never>] = [:]
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
        let isFirstReport = !initializedAccounts.contains(account.id)
        if isFirstReport {
            initializedAccounts.insert(account.id)
        }
        let clamped = max(0, count)
        let previous = unreadByAccount[account.id] ?? 0
        guard clamped != previous || isFirstReport else { return }
        unreadByAccount[account.id] = clamped
        updateDockBadge()

        if clamped == 0 {
            clearDeliveredNotifications(for: account.id)
            pendingBadgeFallbackTasks[account.id]?.cancel()
            pendingBadgeFallbackTasks.removeValue(forKey: account.id)
            return
        }

        if !isFirstReport && clamped > previous {
            pendingBadgeFallbackTasks[account.id]?.cancel()
            pendingBadgeFallbackTasks[account.id] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled, let self else { return }
                let now = Date()
                if let lastRich = lastRichNotificationTime[account.id], now.timeIntervalSince(lastRich) < 2.5 {
                    return
                }
                if let lastFallback = lastNotificationTime[account.id], now.timeIntervalSince(lastFallback) < 3.0 {
                    return
                }
                let body =
                    clamped == 1
                    ? tr("You have 1 unread message.")
                    : String(format: tr("You have %d unread messages."), clamped)
                postNotification(account: account, title: account.name, body: body)
            }
        }
    }

    func removeAccount(_ accountID: UUID) {
        initializedAccounts.remove(accountID)
        unreadByAccount.removeValue(forKey: accountID)
        lastNotificationTime.removeValue(forKey: accountID)
        lastRichNotificationTime.removeValue(forKey: accountID)
        pendingBadgeFallbackTasks[accountID]?.cancel()
        pendingBadgeFallbackTasks.removeValue(forKey: accountID)
        clearDeliveredNotifications(for: accountID)
        updateDockBadge()
    }

    private func clearDeliveredNotifications(for accountID: UUID) {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications.filter {
                ($0.request.content.userInfo["accountID"] as? String) == accountID.uuidString
            }.map(\.request.identifier)
            if !ids.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    private func updateDockBadge() {
        let total = unreadByAccount.values.reduce(0, +)
        NSApplication.shared.dockTile.badgeLabel = total > 0 ? (total > 99 ? "99+" : "\(total)") : nil
    }

    func postNotification(
        account: ChatAccount, title: String, body: String, tag: String = "", callbackID: String = ""
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle =
            (cleanTitle.isEmpty || cleanTitle == account.name)
            ? account.name : "\(account.name) · \(cleanTitle)"
        let effectiveBody = cleanBody.isEmpty ? tr("New message received") : cleanBody

        let fingerprint = "\(account.id.uuidString):\(effectiveTitle):\(effectiveBody):\(tag)"
        let now = Date()
        if let lastSeen = recentNotificationFingerprints[fingerprint], now.timeIntervalSince(lastSeen) < 4.0 {
            return
        }
        recentNotificationFingerprints[fingerprint] = now
        if recentNotificationFingerprints.count > 50 {
            recentNotificationFingerprints = recentNotificationFingerprints.filter {
                now.timeIntervalSince($0.value) < 10.0
            }
        }

        lastNotificationTime[account.id] = now
        if !tag.isEmpty || cleanBody != tr("You have 1 unread message.") {
            lastRichNotificationTime[account.id] = now
            pendingBadgeFallbackTasks[account.id]?.cancel()
        }

        if !NSApplication.shared.isActive {
            NSApplication.shared.requestUserAttention(.informationalRequest)
        }
        guard canUseUserNotifications else { return }
        configure()
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = effectiveTitle
        content.body = effectiveBody
        content.sound = .default
        content.userInfo = ["accountID": account.id.uuidString, "tag": tag, "callbackID": callbackID]
        let identifier =
            tag.isEmpty
            ? "chathub.\(account.id.uuidString).\(UUID().uuidString)"
            : "chathub.\(account.id.uuidString).\(tag)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func sendTestNotification() {
        if !NSApplication.shared.isActive {
            NSApplication.shared.requestUserAttention(.informationalRequest)
        }
        guard canUseUserNotifications else { return }
        configure()
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "ChatHub"
        content.body = tr("Test notification: your system notifications are working properly.")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "chathub.test.\(UUID().uuidString)",
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
        let callbackID = response.notification.request.content.userInfo["callbackID"] as? String
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "workspace" })
                ?? NSApplication.shared.windows.first(where: { $0.canBecomeMain })
            {
                window.makeKeyAndOrderFront(nil)
            }
            if let accountIDString, let uuid = UUID(uuidString: accountIDString) {
                HubNotificationCenter.shared.onSelectAccount?(uuid)
                HubNotificationCenter.shared.onNotificationClick?(uuid, callbackID ?? "")
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

// The SwiftPM WebKit overlay and Xcode's explicit Clang importer expose
// different actor annotations for the void alert callback on this SDK.
// Match each imported protocol type; BrowserSession invokes both on the main actor.
#if SWIFT_PACKAGE
    typealias JavaScriptAlertCompletion = @MainActor @Sendable () -> Void
#else
    typealias JavaScriptAlertCompletion = @Sendable () -> Void
#endif

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

            window.__chatHubIsFocused = Boolean(window.__chatHubIsFocused);
            window.__chatHubSetFocused = function(val) {
                const active = Boolean(val);
                if (window.__chatHubIsFocused === active) return;
                window.__chatHubIsFocused = active;
                try {
                    if (active) {
                        window.dispatchEvent(new Event("focus"));
                        document.dispatchEvent(new Event("focus"));
                    } else {
                        window.dispatchEvent(new Event("blur"));
                        document.dispatchEvent(new Event("blur"));
                    }
                } catch (_) {}
            };

            try {
                const nativeHasFocus = Document.prototype.hasFocus;
                Document.prototype.hasFocus = function() {
                    if (!window.__chatHubIsFocused) return false;
                    try {
                        return nativeHasFocus.call(this);
                    } catch (_) {
                        return true;
                    }
                };
            } catch (_) {}

            const notiRegistry = new Map();
            const documentID = window.crypto?.randomUUID?.()
                || (Date.now().toString(36) + "_" + Math.random().toString(36).slice(2));
            let nextNotificationID = 0;
            window.__chatHubNotificationRegistry = notiRegistry;
            window.__chatHubTriggerNotificationClick = function(callbackID) {
                try {
                    const noti = notiRegistry.get(callbackID);
                    if (!noti) return;
                    const ev = new Event("click");
                    noti.dispatchEvent(ev);
                    if (typeof noti.onclick === "function") noti.onclick(ev);
                } catch (_) {}
            };

            class ChatHubNotification extends EventTarget {
                #callbackID;
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
                    this.icon = String(options?.icon ?? "");
                    this.onclick = null;
                    this.onclose = null;
                    this.onshow = null;
                    this.onerror = null;

                    this.#callbackID = documentID + "_" + (++nextNotificationID);
                    notiRegistry.set(this.#callbackID, this);
                    if (notiRegistry.size > 20) {
                        const firstKey = notiRegistry.keys().next().value;
                        notiRegistry.delete(firstKey);
                    }

                    post({
                        kind: "notify",
                        title: this.title.slice(0, 160),
                        body: this.body.slice(0, 300),
                        tag: this.tag.slice(0, 80),
                        callbackID: this.#callbackID
                    });

                    setTimeout(() => {
                        const ev = new Event("show");
                        this.dispatchEvent(ev);
                        if (typeof this.onshow === "function") this.onshow(ev);
                    }, 0);
                }
                close() {
                    notiRegistry.delete(this.#callbackID);
                    const ev = new Event("close");
                    this.dispatchEvent(ev);
                    if (typeof this.onclose === "function") this.onclose(ev);
                }
            }
            try {
                window.Notification = ChatHubNotification;
            } catch (_) {}

            try {
                delete window.PushManager;
                window.PushManager = undefined;
            } catch (_) {}

            if (typeof ServiceWorkerRegistration !== "undefined" && ServiceWorkerRegistration.prototype) {
                try {
                    const origShow = ServiceWorkerRegistration.prototype.showNotification;
                    ServiceWorkerRegistration.prototype.showNotification = function(title, options) {
                        post({
                            kind: "notify",
                            title: String(title || "").slice(0, 160),
                            body: String(options?.body || "").slice(0, 300),
                            tag: String(options?.tag || "").slice(0, 80)
                        });
                        return Promise.resolve();
                    };
                } catch (_) {}
            }

            if (typeof ServiceWorker !== "undefined" && ServiceWorker.prototype) {
                try {
                    const origPostMessage = ServiceWorker.prototype.postMessage;
                    ServiceWorker.prototype.postMessage = function(message, transfer) {
                        if (message && typeof message === "object") {
                            if (message.type === "showMessageNotification" || message.action === "showNotification") {
                                const t = message.title || message.payload?.title || "";
                                const b = message.options?.body || message.body || message.payload?.body || "";
                                const tag = message.options?.tag || message.tag || "";
                                post({
                                    kind: "notify",
                                    title: String(t).slice(0, 160),
                                    body: String(b).slice(0, 300),
                                    tag: String(tag).slice(0, 80)
                                });
                            }
                        }
                        return origPostMessage.apply(this, arguments);
                    };
                } catch (_) {}
            }

            if (location.hostname === "web.telegram.org" && typeof IDBObjectStore !== "undefined") {
                try {
                    const origGet = IDBObjectStore.prototype.get;
                    IDBObjectStore.prototype.get = function(key) {
                        const req = origGet.apply(this, arguments);
                        if (this.name === "tt-global-state") {
                            req.addEventListener("success", function() {
                                try {
                                    const res = req.result;
                                    if (res && res.settings && res.settings.byKey) {
                                        res.settings.byKey.hasWebNotifications = true;
                                        res.settings.byKey.hasPushNotifications = false;
                                    }
                                } catch (_) {}
                            });
                        }
                        return req;
                    };
                } catch (_) {}
            }

            if (location.hostname.includes("facebook.com") || location.hostname.includes("messenger.com")) {
                try {
                    const origMatchMedia = window.matchMedia;
                    if (typeof origMatchMedia === "function") {
                        window.matchMedia = function(query) {
                            const res = origMatchMedia.apply(this, arguments);
                            if (typeof query === "string" && query.includes("display-mode: standalone")) {
                                return {
                                    matches: true,
                                    media: query,
                                    onchange: null,
                                    addListener: function() {},
                                    removeListener: function() {},
                                    addEventListener: function() {},
                                    removeEventListener: function() {},
                                    dispatchEvent: function() { return false; }
                                };
                            }
                            return res;
                        };
                    }
                } catch (_) {}

                try {
                    let currentD = window.__d;
                    Object.defineProperty(window, "__d", {
                        configurable: true,
                        enumerable: true,
                        get: function() { return currentD; },
                        set: function(fn) {
                            currentD = function(name, deps, factory) {
                                if (typeof name === "string" && name.includes("MWNotificationRenderer")) {
                                    const origFactory = factory;
                                    factory = function(a, b, c, d, e, f) {
                                        const res = origFactory.apply(this, arguments);
                                        try {
                                            const exportsObj = (f && f.exports) || (e && e.exports);
                                            if (exportsObj && typeof exportsObj.renderDocumentTitle === "function") {
                                                const origRender = exportsObj.renderDocumentTitle;
                                                exportsObj.renderDocumentTitle = function(message, actorId, thread, contact, participant) {
                                                    try {
                                                        if (!window.__chatHubIsFocused) {
                                                            const sender = contact?.name || participant?.name || thread?.name || "Messenger";
                                                            const text = message?.text || message?.snippet || "Tin nhắn mới";
                                                            post({
                                                                kind: "notify",
                                                                title: String(sender).slice(0, 160),
                                                                body: String(text).slice(0, 300),
                                                                tag: String(thread?.thread_key || thread?.id || "")
                                                            });
                                                        }
                                                    } catch (_) {}
                                                    return origRender.apply(this, arguments);
                                                };
                                            }
                                        } catch (_) {}
                                        return res;
                                    };
                                }
                                return fn.apply(this, arguments);
                            };
                        }
                    });
                } catch (_) {}
            }

            if (location.hostname === "chat.zalo.me") {
                try {
                    if (typeof Storage !== "undefined") {
                        const origGetItem = Storage.prototype.getItem;
                        Storage.prototype.getItem = function(key) {
                            if (key === "askNoti" || key === "notification_permission") return "1";
                            return origGetItem.apply(this, arguments);
                        };
                    }
                } catch (_) {}
                window.$znoti = window.$znoti || {
                    show: function(title, options) {
                        new ChatHubNotification(title, options);
                    }
                };
            }

            function parseZaloBadge(el) {
                if (!el) return 0;
                const txt = (el.textContent || "").trim();
                if (txt) {
                    const n = parseInt(txt, 10);
                    if (!Number.isNaN(n)) return n;
                }
                const classStr = el.className + " " + Array.from(el.children).map(c => c.className).join(" ");
                const match = classStr.match(/fa-([0-9]+)_|fa-num([0-9]+)/);
                if (match) {
                    const num = parseInt(match[1] || match[2], 10);
                    if (!Number.isNaN(num)) return num;
                }
                if (classStr.includes("fa-5_Plus") || classStr.includes("5_Plus") || classStr.includes("plus")) {
                    return 5;
                }
                const label = el.getAttribute("aria-label") || el.getAttribute("title") || "";
                if (label) {
                    const n = parseInt(label.replace(/\\D/g, ""), 10);
                    if (!Number.isNaN(n)) return n;
                }
                return 1;
            }

            let lastBadgeCount = -1;
            let lastTitle = "";
            let badgeTimer = null;

            function checkTitleBlink() {
                const curTitle = document.title;
                if (curTitle === lastTitle) return;
                lastTitle = curTitle;
                if (window.__chatHubIsFocused) return;
                if (location.hostname.includes("facebook.com") || location.hostname.includes("messenger.com")) {
                    const titleMatch = curTitle.match(/^(?:\\(\\d+\\)\\s+)?(.+?):\\s+(.+)$/)
                        || curTitle.match(/^(?:\\(\\d+\\)\\s+)?(.+?)\\s+(đã gửi|sent\\b)(.*)$/i);
                    if (titleMatch) {
                        const sender = (titleMatch[1] || "Messenger").trim();
                        const body = (titleMatch[2] || titleMatch[3] || "Tin nhắn mới").trim();
                        if (sender !== "Messenger" && !curTitle.includes("Messenger |") && !curTitle.includes("Facebook")) {
                            post({
                                kind: "notify",
                                title: sender.slice(0, 160),
                                body: body.slice(0, 300),
                                tag: "title_blink"
                            });
                        }
                    }
                }
            }

            function computeBadgeCount() {
                badgeTimer = null;
                checkTitleBlink();
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
                    const navBadge = document.querySelector("#main-tab .z-noti-badge, #sidebarNav .z-noti-badge");
                    const navNum = parseZaloBadge(navBadge);
                    if (navNum > 0) {
                        count = navNum;
                    } else {
                        for (const el of document.querySelectorAll(".conv-action__unread .z-noti-badge, .conv-unread, .z-noti-badge")) {
                            if (el.closest("#main-tab") || el.closest("#sidebarNav")) continue;
                            count += parseZaloBadge(el);
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
    @ObservationIgnored private var hubIsFocused = false
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
            let tag = (payload["tag"] as? String) ?? ""
            let callbackID = (payload["callbackID"] as? String) ?? ""
            HubNotificationCenter.shared.postNotification(
                account: account, title: title, body: body, tag: tag, callbackID: callbackID
            )
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
                source: "window.__chatHubIsFocused = \(hubIsFocused ? "true" : "false");\n"
                    + Self.notificationBridgeScript,
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

    func setHubFocus(active: Bool) {
        if hubIsFocused != active {
            hubIsFocused = active
            // Future documents need the latest native state before provider scripts run.
            installUserScripts()
        }
        syncHubFocus()
    }

    private func syncHubFocus() {
        webView.evaluateJavaScript(
            "window.__chatHubSetFocused?.(\(hubIsFocused ? "true" : "false"));",
            completionHandler: nil
        )
    }

    func handleNotificationClick(callbackID: String) {
        guard !callbackID.isEmpty else { return }
        webView.callAsyncJavaScript(
            "window.__chatHubTriggerNotificationClick?.(callbackID); return true;",
            arguments: ["callbackID": callbackID], in: nil, in: .page,
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

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        syncHubFocus()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasLoadedPage = true
        state = .loaded
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        updateAppearance(appearance)
        syncHubFocus()
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
        initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping JavaScriptAlertCompletion
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
