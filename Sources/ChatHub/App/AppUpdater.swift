import AppKit
import Foundation
import Observation

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor @Observable
final class AppUpdater {
    private(set) var availableUpdate: ReleaseUpdate?
    private(set) var isChecking = false
    private(set) var lastChecked: Date?
    let installedVersion: String
    var automaticChecksEnabled: Bool {
        didSet {
            defaults.set(automaticChecksEnabled, forKey: "updates.automaticChecks")
        }
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let client: any ReleaseChecking
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var dismissedVersion: ReleaseVersion?

    init(
        defaults: UserDefaults = .standard,
        client: any ReleaseChecking = GitHubReleaseClient(),
        installedVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    ) {
        self.defaults = defaults
        self.client = client
        self.installedVersion = installedVersion
        automaticChecksEnabled = defaults.object(forKey: "updates.automaticChecks") as? Bool ?? true
        lastChecked = defaults.object(forKey: "updates.lastSuccess") as? Date
    }

    deinit { pollTask?.cancel() }

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            // Let the workspace and signed-in services settle before the first request.
            try? await Task.sleep(for: .seconds(8))
            while !Task.isCancelled {
                await self?.check(manual: false)
                try? await Task.sleep(for: .seconds(UpdateCheckPolicy.retryInterval))
            }
        }
    }

    func checkManually() { Task { await check(manual: true) } }

    func check(manual: Bool, now: Date = Date()) async {
        guard !isChecking, let installed = ReleaseVersion(installedVersion) else { return }
        if !manual {
            guard
                UpdateCheckPolicy.isDue(
                    enabled: automaticChecksEnabled,
                    lastAttempt: defaults.object(forKey: "updates.lastAttempt") as? Date,
                    now: now, retrying: defaults.bool(forKey: "updates.lastFailed")
                )
            else { return }
        }
        isChecking = true
        defaults.set(now, forKey: "updates.lastAttempt")
        defer { isChecking = false }
        do {
            let update = try await client.latestUpdate(after: installed)
            guard !Task.isCancelled else { return }
            lastChecked = now
            defaults.set(now, forKey: "updates.lastSuccess")
            defaults.set(false, forKey: "updates.lastFailed")
            let skipped = defaults.string(forKey: "updates.skippedVersion")
            if let update,
                manual
                    || (automaticChecksEnabled && update.version.description != skipped
                        && update.version != dismissedVersion)
            {
                availableUpdate = update
            } else if update == nil {
                availableUpdate = nil
            }
            if manual { showResult(update: update, error: nil) }
        } catch {
            defaults.set(true, forKey: "updates.lastFailed")
            if manual, !Task.isCancelled { showResult(update: nil, error: error) }
            // Background failures stay quiet; retry with backoff, keep the last known update.
        }
    }

    func remindLater() {
        dismissedVersion = availableUpdate?.version
        availableUpdate = nil
    }

    func skipVersion() {
        guard let version = availableUpdate?.version else { return }
        defaults.set(version.description, forKey: "updates.skippedVersion")
        availableUpdate = nil
    }

    func downloadUpdate() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.downloadURL)
    }

    func openReleaseNotes() {
        guard let update = availableUpdate else { return }
        NSWorkspace.shared.open(update.releaseURL)
    }

    private func showResult(update: ReleaseUpdate?, error: Error?) {
        let alert = NSAlert()
        if error != nil {
            alert.messageText = tr("Couldn’t check for updates")
            alert.informativeText = tr(
                "Check your connection and try again later. You can also visit the releases page.")
            alert.addButton(withTitle: tr("OK"))
            alert.addButton(withTitle: tr("Open Releases"))
        } else if let update {
            alert.messageText = String(format: tr("ChatHub %@ is available."), update.version.description)
            alert.informativeText = tr(
                "Download the new installer, quit ChatHub, then replace it in Applications. Your local workspace is kept."
            )
            alert.addButton(withTitle: tr("Download Update"))
            alert.addButton(withTitle: tr("Later"))
            alert.addButton(withTitle: tr("Release Notes"))
        } else {
            alert.messageText = tr("You’re up to date")
            alert.informativeText = String(format: tr("You’re using ChatHub %@."), installedVersion)
            alert.addButton(withTitle: tr("OK"))
        }
        let handle: @MainActor @Sendable (NSApplication.ModalResponse) -> Void = { response in
            if let update, response == .alertFirstButtonReturn { NSWorkspace.shared.open(update.downloadURL) }
            if let update, response == .alertThirdButtonReturn { NSWorkspace.shared.open(update.releaseURL) }
            if error != nil, response == .alertSecondButtonReturn {
                NSWorkspace.shared.open(GitHubReleaseClient.releasesURL)
            }
        }
        if let window = NSApp.keyWindow, window.attachedSheet == nil {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }
}
