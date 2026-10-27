import Foundation

/// When an idle account's web session may be released to save memory.
/// Only muted accounts sleep: an awake session is what delivers notifications for the others.
public enum HibernationPolicy {
    public static let allowedIdleHours = [0, 1, 4, 12]

    public static func shouldSleep(
        isMuted: Bool, isSelected: Bool, hasActiveDownload: Bool,
        lastActive: Date, now: Date, idleAfter: TimeInterval
    ) -> Bool {
        guard idleAfter > 0, isMuted, !isSelected, !hasActiveDownload else { return false }
        return now.timeIntervalSince(lastActive) >= idleAfter
    }
}
