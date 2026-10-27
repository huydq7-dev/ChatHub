import AppKit
import Network
import Observation
import WebKit

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor @Observable
final class BrowserPool {
    private(set) var sessions: [UUID: BrowserSession] = [:]
    private(set) var selectedID: UUID?
    private(set) var isOnline = true
    /// The primary pane, and every session's web view while it waits in the background.
    @ObservationIgnored let containerView = WebHostContainerView()
    /// The second pane of a split view.
    @ObservationIgnored let secondaryContainerView = WebHostContainerView()
    private(set) var secondaryID: UUID?
    /// Muted accounts whose session was released after sitting idle; they reopen when selected.
    private(set) var sleeping: Set<UUID> = []
    private static let preloadSpacing = 1.5
    /// Called when a service starts or stops asking its user to sign in.
    @ObservationIgnored var onSignInChange: ((UUID, Bool) -> Void)?
    @ObservationIgnored private var lastActive: [UUID: Date] = [:]
    @ObservationIgnored private var appearance = BrowserAppearance()
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var notificationObservers: [NSObjectProtocol] = []

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !isOnline
                isOnline = online
                if online && wasOffline {
                    for session in sessions.values where session.hasFailed { session.reload() }
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "app.chathub.reachability"))

        HubNotificationCenter.shared.onNotificationClick = { [weak self] accountID, callbackID in
            self?.sessions[accountID]?.handleNotificationClick(callbackID: callbackID)
        }

        let center = NotificationCenter.default
        let activeObs = center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFocus()
            }
        }
        let resignActiveObs = center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFocus()
            }
        }
        let keyObs = center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFocus()
            }
        }
        let resignKeyObs = center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncFocus()
            }
        }
        notificationObservers = [activeObs, resignActiveObs, keyObs, resignKeyObs]
    }

    var selectedSession: BrowserSession? { selectedID.flatMap { sessions[$0] } }
    var unreadCounts: [UUID: Int] { sessions.mapValues(\.unreadCount) }

    private func makeSession(for account: ChatAccount) -> BrowserSession {
        let session = BrowserSession(account: account, appearance: appearance)
        session.onSignInChange = { [weak self] id, required in self?.onSignInChange?(id, required) }
        return session
    }

    func activate(_ account: ChatAccount?) {
        if let previous = selectedID { lastActive[previous] = Date() }
        selectedID = account?.id
        guard let account else {
            syncFocus()
            return
        }
        guard let session = prepare(account) else { return }
        if containerView.show(session.webView) { session.didActivate() }
        syncFocus()
    }

    /// Shows an account beside the selected one, or closes the second pane when `account` is nil.
    func show(_ account: ChatAccount?) {
        let previousID = secondaryID
        secondaryID = account?.id
        // The pane's web view goes back to waiting in the background.
        if let previousID, previousID != secondaryID, let previous = sessions[previousID] {
            containerView.attach(previous.webView)
        }
        if let account, let session = prepare(account), secondaryContainerView.show(session.webView) {
            session.didActivate()
        }
        syncFocus()
    }

    @discardableResult
    private func prepare(_ account: ChatAccount) -> BrowserSession? {
        sleeping.remove(account.id)
        lastActive[account.id] = Date()
        if sessions[account.id] == nil {
            let session = makeSession(for: account)
            sessions[account.id] = session
            containerView.attach(session.webView)
        }
        guard let session = sessions[account.id] else { return nil }
        session.updateAppearance(appearance)
        session.startIfNeeded()
        return session
    }

    func syncFocus() {
        let isAppActive = NSApplication.shared.isActive
        let isWindowKey = NSApplication.shared.keyWindow != nil
        let hubHasFocus = isAppActive && isWindowKey

        for (id, session) in sessions {
            let isCurrentTab = (id == selectedID || id == secondaryID)
            session.setHubFocus(active: hubHasFocus && isCurrentTab)
        }
    }

    /// Starts each saved account's session one at a time, so unread counts and notifications work
    /// before the user opens every account. Spaced out to avoid a CPU and network spike at launch.
    func preload(_ accounts: [ChatAccount]) async {
        for account in accounts where sessions[account.id] == nil && !sleeping.contains(account.id) {
            guard !Task.isCancelled else { return }
            let session = makeSession(for: account)
            sessions[account.id] = session
            containerView.attach(session.webView)
            lastActive[account.id] = Date()
            session.startIfNeeded()
            syncFocus()
            try? await Task.sleep(for: .seconds(Self.preloadSpacing))
        }
    }

    /// Releases muted accounts that have been idle for `idleAfter` seconds. Their data store is kept, so
    /// the user stays signed in; the page simply reloads the next time the account is opened.
    func sleepIdle(
        accounts: [ChatAccount], after idleAfter: TimeInterval, keeping visible: Set<UUID> = [], now: Date = Date()
    ) {
        for account in accounts {
            guard let session = sessions[account.id],
                HibernationPolicy.shouldSleep(
                    isMuted: account.notificationsMuted,
                    isSelected: selectedID == account.id || visible.contains(account.id),
                    hasActiveDownload: session.hasActiveDownloads,
                    lastActive: lastActive[account.id] ?? now, now: now, idleAfter: idleAfter)
            else { continue }
            sessions.removeValue(forKey: account.id)
            containerView.detach(session.webView)
            session.tearDown()
            sleeping.insert(account.id)
        }
    }

    /// Lets a sleeping account load again, e.g. after it is unmuted and should deliver notifications.
    func wake(_ id: UUID) { sleeping.remove(id) }

    func updateAppearance(_ appearance: BrowserAppearance) {
        self.appearance = appearance
        for session in sessions.values { session.updateAppearance(appearance) }
    }

    func remove(_ account: ChatAccount) async {
        if selectedID == account.id { selectedID = nil }
        if secondaryID == account.id { secondaryID = nil }
        sleeping.remove(account.id)
        lastActive.removeValue(forKey: account.id)
        let session = sessions.removeValue(forKey: account.id)
        if let session {
            containerView.detach(session.webView)
        }
        let dataStore =
            session?.webView.configuration.websiteDataStore
            ?? WKWebsiteDataStore(forIdentifier: account.id)
        session?.tearDown()
        // SwiftUI may still retain the old view during its removal transition.
        // Clear the profile through the API that supports live data stores.
        await dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        syncFocus()
    }
}
