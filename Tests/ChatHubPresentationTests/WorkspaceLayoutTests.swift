import Foundation
import Testing

@testable import ChatHub

@MainActor
struct WorkspaceLayoutTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "ChatHubLayoutTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test func railAndExpandedWidthSurviveRelaunch() throws {
        try withDefaults { defaults in
            let layout = WorkspaceLayout(defaults: defaults)
            #expect(!layout.isExpanded)
            layout.toggle()
            layout.rememberWidth(286)
            let restored = WorkspaceLayout(defaults: defaults)
            #expect(restored.isExpanded)
            #expect(restored.expandedWidth == 286)
            restored.toggle()
            restored.rememberWidth(72)
            #expect(WorkspaceLayout(defaults: defaults).expandedWidth == 286)
        }
    }

    @Test func invalidOrExtremeSavedWidthsCannotBreakTheWindow() throws {
        try withDefaults { defaults in
            defaults.set(10000.0, forKey: "sidebarWidth")
            #expect(WorkspaceLayout(defaults: defaults).expandedWidth == WorkspaceLayout.maximumWidth)
            defaults.set(-50.0, forKey: "sidebarWidth")
            #expect(WorkspaceLayout(defaults: defaults).expandedWidth == 248)
            let layout = WorkspaceLayout(defaults: defaults)
            layout.toggle()
            layout.rememberWidth(.infinity)
            #expect(layout.expandedWidth == 248)
        }
    }
}

@MainActor
struct ChatAppearancePreferencesTests {
    @Test func migrationPreservesExplicitChoicesAndDoesNotOverrideNewPreferences() throws {
        let name = "ChatHubAppearanceTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(false, forKey: "zaloNativeThemeEnabled")
        defaults.set(true, forKey: "zaloShowServiceTools")
        ChatAppearancePreferences.migrate(defaults: defaults)
        #expect(!defaults.bool(forKey: ChatAppearancePreferences.themeKey))
        #expect(defaults.bool(forKey: ChatAppearancePreferences.toolsKey))
        defaults.set(true, forKey: ChatAppearancePreferences.themeKey)
        ChatAppearancePreferences.migrate(defaults: defaults)
        #expect(defaults.bool(forKey: ChatAppearancePreferences.themeKey))
    }
}
