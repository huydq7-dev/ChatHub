import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct ConversationView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(AppLock.self) private var lock
    let account: ChatAccount
    @Bindable var session: BrowserSession

    var body: some View {
        VStack(spacing: 0) {
            if !browsers.isOnline {
                banner(
                    tr("You’re offline. Your conversations will reconnect when the network returns."),
                    symbol: "wifi.slash",
                    isWarning: true
                )
            }
            if let notice = session.notice {
                HStack(spacing: HubSpace.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(HubStyle.accentText)
                    Text(notice)
                        .font(HubFont.caption)
                        .foregroundStyle(HubStyle.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if let url = session.externalURL {
                        Button(tr("Continue in Browser")) { LinkOpener.open(url, for: account.id) }
                            .font(HubFont.captionMedium)
                            .buttonStyle(.link)
                            .help(url.host ?? "")
                    }
                    Button {
                        session.notice = nil
                        session.externalURL = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(HubStyle.textSecondary)
                    .help(tr("Dismiss"))
                }
                .padding(.horizontal, HubSpace.md)
                .padding(.vertical, 10)
                .background(HubStyle.selected)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(HubStyle.border).frame(height: 1)
                }
            }
            if session.isFinding { ServiceFindBar(session: session) }
            ZStack(alignment: .top) {
                ServiceWebView(session: session, isLocked: lock.isLocked)
                if case .loading = session.state {
                    ProgressView(value: session.progress)
                        .progressViewStyle(.linear)
                        .tint(HubStyle.accent)
                        .frame(height: 2)
                        .accessibilityLabel(tr("Loading service"))
                }
                if case .failed(let message) = session.state {
                    ContentUnavailableView {
                        Label(
                            tr("Let’s get you back to your chats."),
                            systemImage: "bubble.left.and.exclamationmark.bubble.right"
                        )
                        .font(HubFont.sectionTitle)
                    } description: {
                        Text(message).font(HubFont.body)
                    } actions: {
                        Button(tr("Open in Browser")) { session.openInBrowser() }
                            .buttonStyle(HubButtonStyle())
                        Button(tr("Try Again")) { session.reload() }
                            .buttonStyle(HubButtonStyle(prominent: true))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HubStyle.canvas)
                }
            }
        }
    }

    private func banner(_ text: String, symbol: String, isWarning: Bool = false) -> some View {
        HStack(spacing: HubSpace.sm) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isWarning ? .orange : HubStyle.textSecondary)
            Text(text)
                .font(HubFont.caption)
                .foregroundStyle(HubStyle.textPrimary)
            Spacer()
        }
        .padding(.horizontal, HubSpace.md)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.10))
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubStyle.border).frame(height: 1)
        }
    }
}

private struct ServiceFindBar: View {
    @Bindable var session: BrowserSession
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: HubSpace.sm) {
            HStack(spacing: HubSpace.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HubStyle.textSecondary)
                TextField(tr("Find on this page"), text: $session.findQuery)
                    .textFieldStyle(.plain)
                    .font(HubFont.body)
                    .foregroundStyle(HubStyle.textPrimary)
                    .focused($isFocused)
                    .onSubmit { session.find() }
                if !session.findQuery.isEmpty {
                    Button {
                        session.findQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(HubStyle.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .modifier(HubInputFieldSurface())
            .frame(maxWidth: 320)

            if session.findHasNoMatches {
                Text(tr("No matches"))
                    .font(HubFont.captionMedium)
                    .foregroundStyle(HubStyle.textSecondary)
            }
            Button {
                session.find(backwards: true)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(HubButtonStyle())
            .help(tr("Previous match"))
            Button {
                session.find()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(HubButtonStyle())
            .help(tr("Next match"))
            Spacer()
            Button(tr("Done")) { session.isFinding = false }
                .buttonStyle(HubButtonStyle())
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, HubSpace.md)
        .padding(.vertical, HubSpace.xs)
        .background(HubStyle.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(HubStyle.border).frame(height: 1)
        }
        .onAppear { isFocused = true }
        .onChange(of: session.findQuery) { _, _ in session.find() }
    }
}
