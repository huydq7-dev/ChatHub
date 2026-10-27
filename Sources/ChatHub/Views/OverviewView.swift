import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct OverviewView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 440), spacing: HubSpace.md)]

    private var currentAccent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubSpace.xl) {
                if store.accounts.isEmpty {
                    welcome
                    servicesSection
                } else {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: HubSpace.xxs) {
                            Text(tr("Your workspace"))
                                .font(HubFont.pageTitle)
                                .tracking(-0.5)
                                .foregroundStyle(HubStyle.textPrimary)
                            Text(tr("Less switching. More conversation."))
                                .font(HubFont.body)
                                .foregroundStyle(HubStyle.textSecondary)
                        }
                        Spacer()
                        Button {
                            store.add()
                        } label: {
                            Label(tr("Add account"), systemImage: "plus")
                        }
                        .buttonStyle(HubButtonStyle(prominent: true))
                    }
                    accountsSection
                    DisclosureGroup(tr("Explore more services")) {
                        servicesSection.padding(.top, HubSpace.md)
                    }
                    .font(HubFont.bodyMedium)
                    .foregroundStyle(HubStyle.textPrimary)
                    .padding(HubSpace.lg)
                    .modifier(CardSurface())
                }
                footer
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(HubSpace.xxl)
            .frame(maxWidth: .infinity)
        }
        .background(HubStyle.canvas)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: HubSpace.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HubSpace.sm) {
                    HStack(spacing: HubSpace.xs) {
                        Image(systemName: "sparkle")
                        Text(tr("MAKE ROOM FOR CONVERSATION")).tracking(1.2)
                    }
                    .font(HubFont.overline)
                    .foregroundStyle(HubStyle.accentTextColor(for: currentAccent))
                    Text(tr("All your chats.\nA little more calm."))
                        .font(HubFont.hero)
                        .tracking(-0.8)
                        .foregroundStyle(HubStyle.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("Bring your everyday conversations into one thoughtful workspace."))
                        .font(HubFont.body)
                        .foregroundStyle(HubStyle.textSecondary)
                        .lineSpacing(4)
                        .frame(maxWidth: 380, alignment: .leading)
                }
                Spacer(minLength: HubSpace.lg)
                ConversationArtwork()
                    .frame(width: 190, height: 150)
                    .accessibilityHidden(true)
            }
            HStack(spacing: HubSpace.lg) {
                Button {
                    store.add()
                } label: {
                    Label(tr("Add an account"), systemImage: "plus")
                }
                .buttonStyle(HubButtonStyle(prominent: true))
                Label(tr("Private sessions, on your Mac"), systemImage: "lock")
                    .font(HubFont.caption)
                    .foregroundStyle(HubStyle.textSecondary)
            }
        }
        .padding(HubSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: HubRadius.hero, style: .continuous)
                .fill(HubStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: HubRadius.hero, style: .continuous)
                        .fill(HubStyle.accentColor(for: currentAccent).opacity(0.06).gradient)
                }
        }
        .overlay(
            RoundedRectangle(cornerRadius: HubRadius.hero, style: .continuous)
                .strokeBorder(HubStyle.border, lineWidth: 1)
        )
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: HubSpace.md) {
            HStack(alignment: .center, spacing: HubSpace.xs) {
                Text(tr("Your accounts"))
                    .font(HubFont.sectionTitle)
                    .tracking(-0.2)
                    .foregroundStyle(HubStyle.textPrimary)
                HubBadge(text: "\(store.accounts.count)")
                Spacer()
                Text(tr("Pick up where you left off"))
                    .font(HubFont.caption)
                    .foregroundStyle(HubStyle.textSecondary)
            }
            LazyVGrid(columns: columns, spacing: HubSpace.md) {
                ForEach(store.accounts) { account in
                    AccountOverviewCard(account: account, session: browsers.sessions[account.id]) {
                        store.select(account.id)
                    }
                    .contextMenu {
                        Button(tr("Edit Account…")) { store.editingAccount = account }
                        Button(tr(account.notificationsMuted ? "Unmute Notifications" : "Mute Notifications")) {
                            store.setMuted(account, !account.notificationsMuted)
                        }
                        if store.canMove(account, by: -1) {
                            Button(tr("Move Up")) { store.move(account, by: -1) }
                        }
                        if store.canMove(account, by: 1) {
                            Button(tr("Move Down")) { store.move(account, by: 1) }
                        }
                        Button(tr("Remove Account…"), role: .destructive) { store.removingAccount = account }
                    }
                }
            }
        }
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: HubSpace.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Bring your people together"))
                    .font(HubFont.sectionTitle)
                    .tracking(-0.2)
                    .foregroundStyle(HubStyle.textPrimary)
                Spacer()
                Text(tr("Choose a service to get started"))
                    .font(HubFont.caption)
                    .foregroundStyle(HubStyle.textSecondary)
            }
            LazyVGrid(columns: columns, spacing: HubSpace.md) {
                ForEach(ChatService.allCases) { service in
                    ServiceCard(service: service) { store.add(service: service) }
                }
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: HubSpace.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(HubStyle.textSecondary)
            Text(
                tr(
                    "Each service opens its official web experience. Sign in directly with the provider. ChatHub does not run a message relay server. Calls and notifications vary by service."
                )
            )
            .font(HubFont.caption)
            .foregroundStyle(HubStyle.textSecondary)
            .lineSpacing(3)
        }
        .padding(.horizontal, HubSpace.xxs)
        .padding(.bottom, HubSpace.sm)
    }
}

private struct AccountOverviewCard: View {
    let account: ChatAccount
    let session: BrowserSession?
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: HubSpace.sm) {
                ServiceIcon(service: account.service, size: 40)
                    .overlay(alignment: .bottomTrailing) {
                        if let session {
                            if session.hasFailed {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                                    .background(HubStyle.surface, in: Circle())
                                    .offset(x: 3, y: 3)
                            } else if case .loaded = session.state {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 9, height: 9)
                                    .overlay(Circle().strokeBorder(HubStyle.surface, lineWidth: 1.5))
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                VStack(alignment: .leading, spacing: HubSpace.xxs) {
                    Text(account.name)
                        .font(HubFont.rowTitle)
                        .foregroundStyle(HubStyle.textPrimary)
                        .lineLimit(1)
                    Text(account.subtitle.isEmpty ? account.service.name : account.subtitle)
                        .font(HubFont.rowSubtitle)
                        .foregroundStyle(HubStyle.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if account.notificationsMuted {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(HubStyle.textSecondary)
                        .help(tr("Notifications muted"))
                }
                if let session, session.unreadCount > 0 {
                    HubBadge(
                        text: session.unreadCount > 99 ? "99+" : "\(session.unreadCount)",
                        prominent: true
                    )
                }
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hovered ? HubStyle.accentText : HubStyle.textSecondary)
            }
            .padding(HubSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                hovered ? HubStyle.raised : HubStyle.surface,
                in: RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
                    .strokeBorder(
                        hovered ? HubStyle.accent.opacity(0.35) : HubStyle.border,
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct ServiceCard: View {
    let service: ChatService
    var isSelected = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: HubSpace.md) {
                HStack {
                    ServiceIcon(service: service, size: 38)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? HubStyle.accentText : HubStyle.textSecondary)
                }
                VStack(alignment: .leading, spacing: HubSpace.xxs) {
                    Text(service == .custom ? tr(service.name) : service.name)
                        .font(HubFont.rowTitle)
                        .foregroundStyle(HubStyle.textPrimary)
                    Text(service.description)
                        .font(HubFont.rowSubtitle)
                        .foregroundStyle(HubStyle.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(HubSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? HubStyle.selected : (hovered ? HubStyle.raised : HubStyle.surface),
                in: RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? HubStyle.accent : (hovered ? HubStyle.accent.opacity(0.35) : HubStyle.border),
                        lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(tr("Add account") + ": " + service.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ConversationArtwork: View {
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    private var currentAccent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        ZStack {
            Circle()
                .fill(HubStyle.accentColor(for: currentAccent).opacity(0.06))
                .frame(width: 155, height: 155)
            RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
                .fill(HubStyle.raised)
                .frame(width: 146, height: 68)
                .overlay(
                    RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
                        .strokeBorder(HubStyle.border, lineWidth: 1)
                )
                .rotationEffect(.degrees(-9))
                .offset(x: -13, y: -23)
                .overlay(alignment: .leading) {
                    HStack(spacing: HubSpace.xs) {
                        ServiceIcon(service: .telegram, size: 28)
                        VStack(alignment: .leading, spacing: 6) {
                            Capsule().fill(HubStyle.textPrimary.opacity(0.18)).frame(width: 58, height: 5)
                            Capsule().fill(HubStyle.textSecondary.opacity(0.14)).frame(width: 40, height: 5)
                        }
                    }
                    .rotationEffect(.degrees(-9))
                    .offset(x: 3, y: -22)
                }
            RoundedRectangle(cornerRadius: HubRadius.card, style: .continuous)
                .fill(HubStyle.accentColor(for: currentAccent).gradient)
                .frame(width: 146, height: 68)
                .rotationEffect(.degrees(7))
                .offset(x: 13, y: 38)
                .overlay {
                    HStack(spacing: HubSpace.xs) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        VStack(alignment: .leading, spacing: 7) {
                            Capsule().fill(.white.opacity(0.82)).frame(width: 58, height: 5)
                            Capsule().fill(.white.opacity(0.38)).frame(width: 38, height: 5)
                        }
                    }
                    .rotationEffect(.degrees(7))
                    .offset(x: 12, y: 38)
                }
            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HubStyle.accentTextColor(for: currentAccent))
                .offset(x: 86, y: -44)
        }
    }
}
