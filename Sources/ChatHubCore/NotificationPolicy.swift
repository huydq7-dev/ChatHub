import Foundation

/// Decides when ChatHub raises its own alert for an account. Pure so it can be tested without AppKit.
public enum NotificationPolicy {
    /// Muted or snoozed accounts, quiet hours and the conversation the user is looking at never interrupt.
    public static func shouldAlert(
        isMuted: Bool, isViewing: Bool, isSnoozed: Bool = false, isQuietHours: Bool = false
    ) -> Bool {
        !isMuted && !isViewing && !isSnoozed && !isQuietHours
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
