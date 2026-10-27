import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

/// Two accounts side by side. The left pane is the main account that the toolbar and shortcuts act on.
struct SplitConversationView: View {
    let primary: ChatAccount
    let primarySession: BrowserSession
    let secondary: ChatAccount
    let secondarySession: BrowserSession

    var body: some View {
        HSplitView {
            pane(primary, primarySession, isPrimary: true)
            pane(secondary, secondarySession, isPrimary: false)
        }
    }

    private func pane(_ account: ChatAccount, _ session: BrowserSession, isPrimary: Bool) -> some View {
        VStack(spacing: 0) {
            SplitPaneHeader(account: account, session: session, isPrimary: isPrimary)
            ConversationView(account: account, session: session)
                .id(account.id)
        }
        .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SplitPaneHeader: View {
    @Environment(WorkspaceStore.self) private var store
    let account: ChatAccount
    let session: BrowserSession
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: HubSpace.xs) {
            ServiceIcon(service: account.service, size: 18)
            Text(account.name)
                .font(isPrimary ? HubFont.rowTitle : HubFont.bodyMedium)
                .foregroundStyle(HubStyle.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                store.swapPanes()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .help(tr("Swap sides"))
            .accessibilityLabel(tr("Swap sides"))
            Button {
                session.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(tr("Reload Service"))
            .accessibilityLabel(tr("Reload Service"))
            if !isPrimary {
                Button {
                    store.closeSecondary()
                } label: {
                    Image(systemName: "xmark")
                }
                .help(tr("Close Split View"))
                .accessibilityLabel(tr("Close Split View"))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(HubStyle.textSecondary)
        .padding(.horizontal, HubSpace.sm)
        .frame(height: 30)
        .background(HubStyle.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubStyle.border).frame(height: 1)
        }
    }
}
