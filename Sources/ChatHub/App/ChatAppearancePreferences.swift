import Foundation

/// Carry the user's previous appearance choice forward when it becomes cross-service.
enum ChatAppearancePreferences {
    static let themeKey = "chatAppearanceEnabled"
    static let toolsKey = "chatShowServiceTools"
    static let accentKey = "chatAccent"
    static let densityKey = "chatDensity"
    static let textScaleKey = "chatTextScale"
    static let keepConnectedKey = "chatKeepAccountsConnected"

    static func migrate(defaults: UserDefaults = .standard) {
        for (old, new) in [("zaloNativeThemeEnabled", themeKey), ("zaloShowServiceTools", toolsKey)] {
            if defaults.object(forKey: new) == nil, let saved = defaults.object(forKey: old) as? Bool {
                defaults.set(saved, forKey: new)
            }
        }
    }
}
