import AppKit
import UserNotifications

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Page-side notification and unread-badge bridge, loaded from `NotificationBridge.js`.
enum NotificationBridge {
    static let name = "chatHubNotify"

    static let script: String? = {
        #if SWIFT_PACKAGE
            let bundle = Bundle.module
        #else
            let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "NotificationBridge", withExtension: "js") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }()
}

@MainActor
final class HubNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = HubNotificationCenter()
    var onSelectAccount: ((UUID) -> Void)?
    var isMuted: (UUID) -> Bool = { _ in false }
    var isViewing: (UUID) -> Bool = { _ in false }
    var isSnoozed: (UUID) -> Bool = { _ in false }
    private var unreadByAccount: [UUID: Int] = [:]
    private var lastServiceNotification: [UUID: Date] = [:]
    private var fallbackTasks: [UUID: Task<Void, Never>] = [:]
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
        refreshBadge()
        if clamped > previous { scheduleFallbackNotification(for: account) }
    }

    func removeAccount(_ accountID: UUID) {
        unreadByAccount.removeValue(forKey: accountID)
        lastServiceNotification.removeValue(forKey: accountID)
        fallbackTasks.removeValue(forKey: accountID)?.cancel()
        refreshBadge()
    }

    /// Recompute the Dock badge, e.g. after an account is muted or unmuted.
    func refreshBadge() {
        let muted = Set(unreadByAccount.keys.filter(isMuted))
        let total = NotificationPolicy.dockTotal(unread: unreadByAccount, muted: muted)
        NSApplication.shared.dockTile.badgeLabel = NotificationPolicy.badgeLabel(total: total)
    }

    /// A notification the service itself raised through the web Notification API.
    func postServiceNotification(account: ChatAccount, title: String, body: String) {
        lastServiceNotification[account.id] = Date()
        deliver(account: account, title: title, body: body)
    }

    /// Services that never call the Notification API still get one alert per unread increase.
    private func scheduleFallbackNotification(for account: ChatAccount) {
        let increasedAt = Date()
        fallbackTasks[account.id]?.cancel()
        fallbackTasks[account.id] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(NotificationPolicy.fallbackDelay))
            guard !Task.isCancelled, let self else { return }
            fallbackTasks[account.id] = nil
            let unread = unreadByAccount[account.id] ?? 0
            guard unread > 0,
                NotificationPolicy.needsFallback(
                    increasedAt: increasedAt, lastServiceNotification: lastServiceNotification[account.id])
            else { return }
            let body =
                unread == 1
                ? tr("You have 1 unread message.")
                : String(format: tr("You have %d unread messages."), unread)
            deliver(account: account, title: account.name, body: body)
        }
    }

    private func deliver(account: ChatAccount, title: String, body: String) {
        guard
            NotificationPolicy.shouldAlert(
                isMuted: isMuted(account.id),
                isViewing: NSApplication.shared.isActive && isViewing(account.id),
                isSnoozed: isSnoozed(account.id),
                isQuietHours: ChatAppearancePreferences.quietHours().contains(Date()))
        else { return }
        if !NSApplication.shared.isActive {
            NSApplication.shared.requestUserAttention(.informationalRequest)
        }
        guard canUseUserNotifications else { return }
        configure()
        let hidePreviews = UserDefaults.standard.bool(forKey: ChatAppearancePreferences.hidePreviewsKey)
        let cleanTitle = hidePreviews ? "" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = hidePreviews ? "" : body.trimmingCharacters(in: .whitespacesAndNewlines)
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
        UNUserNotificationCenter.current().add(request)
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
