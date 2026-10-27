import AppKit

struct InstalledBrowser: Identifiable, Equatable {
    let id: String
    let name: String
}

/// Opens web links in the browser chosen for an account, falling back to the system default.
@MainActor
enum LinkOpener {
    /// The browser bundle identifier saved for an account; installed by the workspace view.
    static var browserID: (UUID) -> String? = { _ in nil }

    static func open(_ url: URL, for accountID: UUID?) {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            let accountID, let bundleID = browserID(accountID),
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Apps that declare they can open web pages, other than ChatHub itself.
    static func installedBrowsers() -> [InstalledBrowser] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: probe).compactMap { appURL in
            guard let id = Bundle(url: appURL)?.bundleIdentifier, id != Bundle.main.bundleIdentifier,
                seen.insert(id).inserted
            else { return nil }
            return InstalledBrowser(id: id, name: FileManager.default.displayName(atPath: appURL.path))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
