import AppKit
import SwiftUI

struct LockScreenView: View {
    @Environment(AppLock.self) private var lock

    var body: some View {
        VStack(spacing: HubSpace.md) {
            HubMark(size: 56)
            Text(tr("ChatHub is locked"))
                .font(HubFont.modalTitle)
                .foregroundStyle(HubStyle.textPrimary)
            Text(tr("Use Touch ID or your password to see your conversations."))
                .font(HubFont.body)
                .foregroundStyle(HubStyle.textSecondary)
            if let message = lock.errorMessage {
                Text(message)
                    .font(HubFont.caption)
                    .foregroundStyle(.red)
            }
            Button {
                Task { await lock.unlock() }
            } label: {
                Label(tr("Unlock"), systemImage: "touchid")
            }
            .buttonStyle(HubButtonStyle(prominent: true))
            .keyboardShortcut(.defaultAction)
            .disabled(lock.isAuthenticating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HubStyle.canvas)
        .task { await lock.unlock() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await lock.unlock() }
        }
    }
}
