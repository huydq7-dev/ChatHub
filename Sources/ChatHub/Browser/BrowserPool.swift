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
    @ObservationIgnored let containerView = WebHostContainerView()
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

    func preload(_ accounts: [ChatAccount]) {
        for account in accounts {
            if sessions[account.id] == nil {
                let session = BrowserSession(account: account, appearance: appearance)
                sessions[account.id] = session
                containerView.attach(session.webView)
                session.startIfNeeded()
            }
        }
        syncFocus()
    }

    func activate(_ account: ChatAccount?) {
        selectedID = account?.id
        guard let account else {
            syncFocus()
            return
        }
        if sessions[account.id] == nil {
            let session = BrowserSession(account: account, appearance: appearance)
            sessions[account.id] = session
            containerView.attach(session.webView)
        }
        guard let session = sessions[account.id] else { return }
        session.updateAppearance(appearance)
        session.startIfNeeded()
        containerView.show(session.webView)
        session.didActivate()
        syncFocus()
    }

    func syncFocus() {
        let isAppActive = NSApplication.shared.isActive
        let isWindowKey = NSApplication.shared.keyWindow != nil
        let hubHasFocus = isAppActive && isWindowKey

        for (id, session) in sessions {
            let isCurrentTab = (id == selectedID)
            session.setHubFocus(active: hubHasFocus && isCurrentTab)
        }
    }

    func updateAppearance(_ appearance: BrowserAppearance) {
        self.appearance = appearance
        for session in sessions.values { session.updateAppearance(appearance) }
    }

    func remove(_ account: ChatAccount) async {
        if selectedID == account.id { selectedID = nil }
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
