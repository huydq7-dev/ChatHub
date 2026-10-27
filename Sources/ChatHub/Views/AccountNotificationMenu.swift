import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Mute and snooze actions for one account; shared by the sidebar, overview and toolbar menus.
struct AccountNotificationMenu: View {
    @Environment(WorkspaceStore.self) private var store
    let account: ChatAccount

    var body: some View {
        Button(tr(account.notificationsMuted ? "Unmute Notifications" : "Mute Notifications")) {
            store.setMuted(account, !account.notificationsMuted)
        }
        if account.isSnoozed() {
            Button(tr("Resume Notifications")) { store.setSnooze(account, until: nil) }
        } else if !account.notificationsMuted {
            Menu(tr("Snooze Notifications")) {
                ForEach(SnoozeOption.allCases, id: \.self) { option in
                    Button(label(for: option)) {
                        store.setSnooze(account, until: option.endDate(from: Date()))
                    }
                }
            }
        }
    }

    private func label(for option: SnoozeOption) -> String {
        switch option {
        case .oneHour: tr("For 1 Hour")
        case .untilMorning: tr("Until 8 AM")
        }
    }
}
