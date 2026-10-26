import AppKit
import SwiftUI

@main
struct ChatHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = WorkspaceStore()
    @State private var browsers = BrowserPool()
    @State private var layout = WorkspaceLayout()
    @State private var updater = AppUpdater()
    @AppStorage("appearance") private var appearance = "system"

    init() { ChatAppearancePreferences.migrate() }

    var body: some Scene {
        Window(tr("ChatHub"), id: "workspace") {
            WorkspaceView()
                .ignoresSafeArea()
                .environment(store)
                .environment(browsers)
                .environment(layout)
                .environment(updater)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 840)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(tr("Check for Updates…")) { updater.checkManually() }
                    .disabled(updater.isChecking)
            }
            CommandGroup(replacing: .newItem) {
                Button(tr("Add Account…")) { store.add() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu(tr("Workspace")) {
                Button(tr("Switch Account…")) { store.isSwitchingAccount = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button(tr("Toggle Sidebar")) { layout.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                Divider()
                Button(tr("Overview")) { store.select(nil) }
                    .keyboardShortcut("0", modifiers: .command)
                ForEach(Array(store.accounts.prefix(9).enumerated()), id: \.element.id) { index, account in
                    Button(account.name) { store.select(account.id) }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Divider()
                Button(tr("Reload Service")) { browsers.selectedSession?.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.selectedID == nil)
                Button(tr("Open in Browser")) { browsers.selectedSession?.openInBrowser() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                    .disabled(store.selectedID == nil)
            }
            CommandGroup(after: .textEditing) {
                Button(tr("Find in Conversation…")) { browsers.selectedSession?.showFind() }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(store.selectedID == nil)
            }
            CommandGroup(replacing: .help) {
                Button(tr("ChatHub Help")) { delegate.showHelp() }
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(browsers)
                .environment(layout)
                .environment(updater)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        HubNotificationCenter.shared.configure()

        for window in NSApplication.shared.windows {
            configureWindow(window)
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                for window in NSApplication.shared.windows {
                    self?.configureWindow(window)
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                for window in NSApplication.shared.windows {
                    self?.configureWindow(window)
                }
            }
        }
    }

    func configureWindow(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.toolbar = nil
        window.backgroundColor = NSColor(Color(HubStyle.rail))
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.contentView?.needsLayout = true
        window.layoutIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let window = sender.windows.first(where: { $0.identifier?.rawValue == "workspace" })
                ?? sender.windows.first(where: { $0.canBecomeMain })
            {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func showHelp() {
        let alert = NSAlert()
        alert.messageText = tr("A calmer place for your chats.")
        alert.informativeText = tr(
            "Add a service, then sign in on its official website. Each account has its own local session. ⌘0 opens Overview, ⌘1–9 switches accounts, and ⌘R reloads a service. Closing the window keeps ChatHub running; use ⌘Q to quit. Calls and background notifications depend on each service and are not guaranteed."
        )
        alert.addButton(withTitle: tr("Got it"))
        alert.runModal()
    }
}
