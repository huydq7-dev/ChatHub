import ServiceManagement

/// Thin wrapper over the login-item API so views never touch ServiceManagement directly.
enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// Enabled, or registered and waiting for the user's approval in System Settings.
    static var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
