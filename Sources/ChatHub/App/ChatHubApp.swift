import AppKit
import SwiftUI

@main
struct ChatHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = WorkspaceStore()
    @State private var browsers = BrowserPool()
    @State private var layout = WorkspaceLayout()
    @State private var lock = AppLock()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(ChatAppearancePreferences.showMenuBarKey) private var showMenuBar = true

    init() { ChatAppearancePreferences.migrate() }

    var body: some Scene {
        Window(tr("ChatHub"), id: "workspace") {
            WorkspaceView()
                .environment(store)
                .environment(browsers)
                .environment(layout)
                .environment(lock)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1280, height: 840)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(tr("Add Account…")) { store.add() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu(tr("Workspace")) {
                Button(tr("Switch Account…")) { store.isSwitchingAccount = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button(tr("Toggle Sidebar")) { layout.toggle() }
                    .keyboardShortcut("s", modifiers: [.command, .control])
                Button(tr("Next Unread Account")) {
                    if !store.selectNextUnread(unread: browsers.unreadCounts) { NSSound.beep() }
                }
                .keyboardShortcut("j", modifiers: .command)
                Button(tr("Lock ChatHub")) {
                    if !lock.lock() { NSSound.beep() }
                }
                .keyboardShortcut("l", modifiers: [.command, .control])
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

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarContent()
                .environment(store)
                .environment(browsers)
                .environment(lock)
        } label: {
            MenuBarLabel()
                .environment(store)
                .environment(browsers)
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(browsers)
                .environment(layout)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
    }
}

struct DockMenuEntry {
    let id: UUID
    let title: String
}

/// Feeds the Dock menu; the workspace view installs the closures once it appears.
@MainActor
enum DockMenuSource {
    static var entries: () -> [DockMenuEntry] = { [] }
    static var select: (UUID) -> Void = { _ in }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let entries = DockMenuSource.entries()
        guard !entries.isEmpty else { return nil }
        let menu = NSMenu()
        for entry in entries {
            let item = NSMenuItem(title: entry.title, action: #selector(openAccountFromDock(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = entry.id
            menu.addItem(item)
        }
        return menu
    }

    @objc private func openAccountFromDock(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        DockMenuSource.select(id)
        _ = applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        HubNotificationCenter.shared.configure()
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
