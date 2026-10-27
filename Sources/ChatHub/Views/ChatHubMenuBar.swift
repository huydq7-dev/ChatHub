import AppKit
import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct ChatHubMenuBarLabel: View {
    @Environment(BrowserPool.self) private var browsers

    private var totalUnread: Int {
        browsers.sessions.values.reduce(0) { $0 + $1.unreadCount }
    }

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
    @Binding var privacyShieldEnabled: Bool
    @Binding var alwaysOnTopEnabled: Bool

    private var totalUnread: Int {
        browsers.sessions.values.reduce(0) { $0 + $1.unreadCount }
    }

    var body: some View {
        VStack {
            if totalUnread > 0 {
                Text(String(format: tr("%d unread messages"), totalUnread))
            } else {
                Text(tr("All caught up"))
            }

            Divider()

            ForEach(store.accounts) { account in
                let count = browsers.sessions[account.id]?.unreadCount ?? 0
                Button {
                    openAccount(account)
                } label: {
                    HStack {
                        Image(systemName: account.service.symbol)
                        Text(account.name)
                        if count > 0 {
                            Spacer()
                            Text("(\(count))")
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
