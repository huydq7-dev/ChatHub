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
    /// Muted accounts whose session was released after sitting idle; they reopen when selected.
    private(set) var sleeping: Set<UUID> = []
    private static let preloadSpacing = 1.5
    @ObservationIgnored private var lastActive: [UUID: Date] = [:]
    @ObservationIgnored private var appearance = BrowserAppearance()
    @ObservationIgnored private let monitor = NWPathMonitor()

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
    }

    var selectedSession: BrowserSession? { selectedID.flatMap { sessions[$0] } }
    var unreadCounts: [UUID: Int] { sessions.mapValues(\.unreadCount) }

    func activate(_ account: ChatAccount?) {
        if let previous = selectedID { lastActive[previous] = Date() }
        selectedID = account?.id
        guard let account else { return }
        sleeping.remove(account.id)
        lastActive[account.id] = Date()
        if sessions[account.id] == nil {
            sessions[account.id] = BrowserSession(account: account, appearance: appearance)
        }
        sessions[account.id]?.updateAppearance(appearance)
        sessions[account.id]?.startIfNeeded()
        sessions[account.id]?.didActivate()
    }

    /// Starts each saved account's session one at a time, so unread counts and notifications work
    /// before the user opens every account. Spaced out to avoid a CPU and network spike at launch.
    func preload(_ accounts: [ChatAccount]) async {
        for account in accounts where sessions[account.id] == nil && !sleeping.contains(account.id) {
            guard !Task.isCancelled else { return }
            let session = BrowserSession(account: account, appearance: appearance)
            sessions[account.id] = session
            lastActive[account.id] = Date()
            session.startIfNeeded()
            try? await Task.sleep(for: .seconds(Self.preloadSpacing))
        }
    }

    /// Releases muted accounts that have been idle for `idleAfter` seconds. Their data store is kept, so
    /// the user stays signed in; the page simply reloads the next time the account is opened.
    func sleepIdle(accounts: [ChatAccount], after idleAfter: TimeInterval, now: Date = Date()) {
        for account in accounts {
            guard let session = sessions[account.id],
                HibernationPolicy.shouldSleep(
                    isMuted: account.notificationsMuted, isSelected: selectedID == account.id,
                    hasActiveDownload: session.hasActiveDownloads,
                    lastActive: lastActive[account.id] ?? now, now: now, idleAfter: idleAfter)
            else { continue }
            sessions.removeValue(forKey: account.id)
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
        sleeping.remove(account.id)
        lastActive.removeValue(forKey: account.id)
        let session = sessions.removeValue(forKey: account.id)
        let dataStore =
            session?.webView.configuration.websiteDataStore
            ?? WKWebsiteDataStore(forIdentifier: account.id)
        session?.tearDown()
        // SwiftUI may still retain the old view during its removal transition.
        // Clear the profile through the API that supports live data stores.
        await dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
}
