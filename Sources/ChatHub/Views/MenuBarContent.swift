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

struct MenuBarLabel: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers

    var body: some View {
        let muted = Set(store.accounts.filter(\.notificationsMuted).map(\.id))
        let total = NotificationPolicy.dockTotal(unread: browsers.unreadCounts, muted: muted)
        HStack(spacing: 3) {
            Image(systemName: total > 0 ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
            if let label = NotificationPolicy.badgeLabel(total: total) { Text(label) }
        }
    }
}

struct MenuBarContent: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(AppLock.self) private var lock
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let unread = browsers.unreadCounts
        if lock.isLocked {
            Text(tr("ChatHub is locked"))
        } else if store.accounts.isEmpty {
            Text(tr("No accounts yet"))
        }
        if !lock.isLocked {
            ForEach(AccountNavigation.unreadFirst(store.accounts, unread: unread)) { account in
                Button(accountMenuTitle(account, unread: unread[account.id] ?? 0)) {
                    store.select(account.id)
                    showWorkspace()
                }
            }
        }
        Divider()
        Button(tr("Open ChatHub")) { showWorkspace() }
        Button(tr("Quit ChatHub")) { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showWorkspace() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "workspace")
    }
}
