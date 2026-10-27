import Foundation

/// When ChatHub asks for Touch ID or the login password again.
public enum AppLockPolicy {
    /// 0 locks as soon as the user leaves the app.
    public static let allowedTimeoutMinutes = [0, 1, 5, 15]

    /// The system prompt appears only while the user is looking at ChatHub. A lock that engages while
    /// another app is in front waits silently and asks when the user comes back.
    public static func shouldPromptForUnlock(isLocked: Bool, isAppActive: Bool, isAuthenticating: Bool) -> Bool {
        isLocked && isAppActive && !isAuthenticating
    }

    /// Evaluated when the app becomes active again after the user left at `leftAt`.
    public static func shouldLockOnReturn(leftAt: Date?, now: Date, timeoutMinutes: Int) -> Bool {
        guard let leftAt else { return false }
        return now.timeIntervalSince(leftAt) >= Double(max(0, timeoutMinutes)) * 60
    }
}
