import Foundation

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Carry the user's previous appearance choice forward when it becomes cross-service.
enum ChatAppearancePreferences {
    static let themeKey = "chatAppearanceEnabled"
    static let toolsKey = "chatShowServiceTools"
    static let accentKey = "chatAccent"
    static let densityKey = "chatDensity"
    static let textScaleKey = "chatTextScale"
    static let keepConnectedKey = "chatKeepAccountsConnected"
    static let showMenuBarKey = "chatShowMenuBar"
    static let sleepIdleHoursKey = "chatSleepIdleHours"
    static let quietEnabledKey = "chatQuietHoursEnabled"
    static let quietStartKey = "chatQuietHoursStart"
    static let quietEndKey = "chatQuietHoursEnd"
    static let lockEnabledKey = "chatAppLockEnabled"
    static let lockTimeoutKey = "chatAppLockTimeoutMinutes"
    static let hidePreviewsKey = "chatHideNotificationPreviews"

    static func quietHours(defaults: UserDefaults = .standard) -> QuietHours {
        QuietHours(
            isEnabled: defaults.bool(forKey: quietEnabledKey),
            startMinute: defaults.object(forKey: quietStartKey) as? Int ?? QuietHours.defaultStartMinute,
            endMinute: defaults.object(forKey: quietEndKey) as? Int ?? QuietHours.defaultEndMinute
        )
    }

    static func migrate(defaults: UserDefaults = .standard) {
        for (old, new) in [("zaloNativeThemeEnabled", themeKey), ("zaloShowServiceTools", toolsKey)] {
            if defaults.object(forKey: new) == nil, let saved = defaults.object(forKey: old) as? Bool {
                defaults.set(saved, forKey: new)
            }
        }
    }
}
