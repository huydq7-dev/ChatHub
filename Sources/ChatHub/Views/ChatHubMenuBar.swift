import AppKit
import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// "Name · 3" for accounts with unread messages, just the name otherwise.
func accountMenuTitle(_ account: ChatAccount, unread: Int) -> String {
    guard unread > 0, !account.notificationsMuted else { return account.name }
    return "\(account.name) · \(unread > 99 ? "99+" : "\(unread)")"
}

/// Unread messages in accounts that are allowed to interrupt; muted accounts stay out of the total.
@MainActor
private func unreadTotal(store: WorkspaceStore, browsers: BrowserPool) -> Int {
    let muted = Set(store.accounts.filter(\.notificationsMuted).map(\.id))
    return NotificationPolicy.dockTotal(unread: browsers.unreadCounts, muted: muted)
}

struct ChatHubMenuBarLabel: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers

    private var totalUnread: Int { unreadTotal(store: store, browsers: browsers) }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: totalUnread > 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
            if totalUnread > 0 {
                Text("\(totalUnread)")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
            }
        }
    }
}

struct ChatHubMenuBarMenu: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(AppLock.self) private var lock
    @Binding var privacyShieldEnabled: Bool
    @Binding var alwaysOnTopEnabled: Bool

    private var totalUnread: Int { unreadTotal(store: store, browsers: browsers) }

    var body: some View {
        VStack {
            if lock.isLocked {
                Text(tr("ChatHub is locked"))
            } else if totalUnread > 0 {
                Text(String(format: tr("%d unread messages"), totalUnread))
            } else {
                Text(tr("All caught up"))
            }

            Divider()

            if !lock.isLocked {
                let unread = browsers.unreadCounts
                ForEach(AccountNavigation.unreadFirst(store.accounts, unread: unread)) { account in
                    Button {
                        openAccount(account)
                    } label: {
                        HStack {
                            Image(systemName: account.service.symbol)
                            Text(accountMenuTitle(account, unread: unread[account.id] ?? 0))
                        }
                    }
                }
            }

            Divider()

            Button {
                privacyShieldEnabled.toggle()
            } label: {
                HStack {
                    Text(privacyShieldEnabled ? tr("Disable Privacy Shield") : tr("Enable Privacy Shield"))
                    if privacyShieldEnabled {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button {
                alwaysOnTopEnabled.toggle()
            } label: {
                HStack {
                    Text(alwaysOnTopEnabled ? tr("Disable Always on Top") : tr("Keep Window on Top"))
                    if alwaysOnTopEnabled {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button(tr("Command Palette…")) {
                store.isSwitchingAccount = true
                bringAppToFront()
            }
            .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button(tr("Open ChatHub")) {
                bringAppToFront()
            }
            .keyboardShortcut("0", modifiers: .command)

            SettingsLink {
                Text(tr("Settings…"))
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button(tr("Quit ChatHub")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func bringAppToFront() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows
        where window.identifier?.rawValue == "workspace" || window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    private func openAccount(_ account: ChatAccount) {
        store.select(account.id)
        bringAppToFront()
    }
}
