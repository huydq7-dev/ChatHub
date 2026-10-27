import Foundation

/// Decides when ChatHub raises its own alert for an account. Pure so it can be tested without AppKit.
public enum NotificationPolicy {
    /// Wait this long after an unread increase for the service's own notification before synthesizing one.
    public static let fallbackDelay: TimeInterval = 2

    /// Muted accounts and the conversation the user is looking at never interrupt.
    public static func shouldAlert(isMuted: Bool, isViewing: Bool) -> Bool {
        !isMuted && !isViewing
    }

    /// The service usually sends its own notification; only fill in when none arrived after the increase.
    public static func needsFallback(increasedAt: Date, lastServiceNotification: Date?) -> Bool {
        guard let lastServiceNotification else { return true }
        return lastServiceNotification < increasedAt
    }

    /// Dock badge total; muted accounts stay out of it.
    public static func dockTotal(unread: [UUID: Int], muted: Set<UUID>) -> Int {
        unread.reduce(0) { muted.contains($1.key) ? $0 : $0 + $1.value }
    }

    public static func badgeLabel(total: Int) -> String? {
        guard total > 0 else { return nil }
        return total > 99 ? "99+" : "\(total)"
    }
}
