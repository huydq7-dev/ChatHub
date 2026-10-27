import AppKit
import LocalAuthentication
import Observation

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Hides the workspace behind Touch ID or the login password. ChatHub never sees or stores either.
@MainActor @Observable
final class AppLock {
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var leftAt: Date?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// False on a Mac with no password or biometrics; the lock is then never applied so nobody is locked out.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    var isEnabled: Bool { defaults.bool(forKey: ChatAppearancePreferences.lockEnabledKey) }

    private var timeoutMinutes: Int {
        defaults.object(forKey: ChatAppearancePreferences.lockTimeoutKey) as? Int ?? 0
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isLocked = defaults.bool(forKey: ChatAppearancePreferences.lockEnabledKey) && Self.isAvailable
        observeLifecycle()
    }

    /// Returns false when the lock is off or unavailable.
    @discardableResult
    func lock() -> Bool {
        guard isEnabled, Self.isAvailable else { return false }
        isLocked = true
        errorMessage = nil
        return true
    }

    /// Asks for Touch ID or the password. Does nothing while ChatHub is in the background; the lock
    /// screen asks again as soon as the app becomes active.
    func unlock() async {
        guard
            AppLockPolicy.shouldPromptForUnlock(
                isLocked: isLocked, isAppActive: NSApplication.shared.isActive, isAuthenticating: isAuthenticating)
        else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            let approved = try await LAContext().evaluatePolicy(
                .deviceOwnerAuthentication, localizedReason: tr("Unlock ChatHub to see your conversations."))
            if approved {
                isLocked = false
                leftAt = nil
                errorMessage = nil
            }
        } catch let error as LAError where error.code == .userCancel || error.code == .appCancel {
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appDidResign() {
        // The system authentication sheet also deactivates the app; that must not re-lock it.
        guard isEnabled, !isLocked, !isAuthenticating else { return }
        leftAt = Date()
        if timeoutMinutes == 0 { lock() }
    }

    private func appDidBecomeActive() {
        defer { leftAt = nil }
        guard isEnabled, !isLocked, !isAuthenticating else { return }
        if AppLockPolicy.shouldLockOnReturn(leftAt: leftAt, now: Date(), timeoutMinutes: timeoutMinutes) {
            lock()
        }
    }

    /// The lock lives as long as the app, so these observers are never removed.
    private func observeLifecycle() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.appDidResign() }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.appDidBecomeActive() }
            },
        ]
        for name in [
            NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ] {
            observers.append(
                workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { _ = self?.lock() }
                })
        }
    }
}
