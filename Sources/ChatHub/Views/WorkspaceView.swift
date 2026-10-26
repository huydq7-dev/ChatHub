import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct WorkspaceView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(WorkspaceLayout.self) private var layout
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appearance") private var appearanceMode = "system"
    @AppStorage(ChatAppearancePreferences.themeKey) private var nativeThemeEnabled = true
    @AppStorage(ChatAppearancePreferences.toolsKey) private var showServiceTools = false
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    @AppStorage(ChatAppearancePreferences.densityKey) private var densityRaw = HubDensity.standard.rawValue
    @AppStorage(ChatAppearancePreferences.textScaleKey) private var textScaleRaw = HubTextScale.standard.rawValue

    private var currentAccent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        @Bindable var store = store
        HSplitView {
            WorkspaceSidebar()
                .background(
                    SidebarPositionRestorer(
                        expanded: layout.isExpanded,
                        width: layout.isExpanded ? layout.expandedWidth : WorkspaceLayout.compactWidth
                    )
                )
                .frame(
                    minWidth: layout.isExpanded ? WorkspaceLayout.minimumWidth : WorkspaceLayout.compactWidth,
                    idealWidth: layout.isExpanded ? layout.expandedWidth : WorkspaceLayout.compactWidth,
                    maxWidth: layout.isExpanded ? WorkspaceLayout.maximumWidth : WorkspaceLayout.compactWidth
                )
            detail
                .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
                .background(HubStyle.canvas)
                .layoutPriority(1)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: layout.isExpanded)
        .tint(HubStyle.accentColor(for: currentAccent))
        .toolbar { WorkspaceToolbar() }
        .onAppear {
            HubNotificationCenter.shared.onSelectAccount = { id in
                store.select(id)
            }
            browsers.preload(store.accounts)
        }
        .onChange(of: store.accounts) { _, accounts in
            browsers.preload(accounts)
        }
        .onChange(of: browserAppearance, initial: true) { _, appearance in browsers.updateAppearance(appearance) }
        .onChange(of: store.selectedID, initial: true) { _, _ in browsers.activate(store.selectedAccount) }
        .sheet(isPresented: $store.isAddingAccount) { AccountEditor(service: store.suggestedService) }
        .sheet(
            isPresented: $store.isSwitchingAccount,
            onDismiss: {
                if store.addAccountAfterSwitcher {
                    store.addAccountAfterSwitcher = false
                    store.add()
                }
            }
        ) { AccountSwitcherView() }
        .sheet(item: $store.editingAccount) { AccountEditor(account: $0) }
        .sheet(item: $store.removingAccount) { RemoveAccountView(account: $0) }
        .alert(
            tr("Something needs your attention"),
            isPresented: Binding(
                get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button(tr("OK")) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var effectiveIsDark: Bool {
        switch appearanceMode {
        case "dark": true
        case "light": false
        default: colorScheme == .dark
        }
    }

    private var browserAppearance: BrowserAppearance {
        BrowserAppearance(
            isDark: effectiveIsDark,
            themeEnabled: nativeThemeEnabled,
            reduceMotion: reduceMotion,
            showServiceTools: showServiceTools,
            accent: HubAccent(rawValue: accentRaw) ?? .iris,
            density: HubDensity(rawValue: densityRaw) ?? .standard,
            textScale: HubTextScale(rawValue: textScaleRaw) ?? .standard
        )
    }

    @ViewBuilder private var detail: some View {
        if let loadError = store.loadError {
            ContentUnavailableView {
                Label(tr("Your workspace needs attention"), systemImage: "externaldrive.badge.exclamationmark")
                    .font(HubFont.sectionTitle)
            } description: {
                Text(loadError).font(HubFont.body)
                Text(tr("Your saved file has been preserved. Fix or restore it, then try again."))
                    .font(HubFont.caption)
            } actions: {
                Button(tr("Show Saved File")) { store.revealWorkspace() }
                    .buttonStyle(HubButtonStyle())
                Button(tr("Try Again")) { store.reloadFromDisk() }
                    .buttonStyle(HubButtonStyle(prominent: true))
            }
        } else {
            ZStack {
                if let account = store.selectedAccount, let session = browsers.sessions[account.id] {
                    ConversationView(account: account, session: session)
                } else {
                    ServiceWebView(containerView: browsers.containerView, session: nil)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .allowsHitTesting(false)
                    OverviewView()
                }
            }
        }
    }
}

private struct WorkspaceSidebar: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(WorkspaceLayout.self) private var layout

    private var horizontalPadding: CGFloat { layout.isExpanded ? HubSpace.sm : HubSpace.xs }

    var body: some View {
        @Bindable var store = store
        GeometryReader { geometry in
            VStack(spacing: 0) {
                branding
                if layout.isExpanded {
                    HStack(spacing: HubSpace.xs) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HubStyle.textSecondary)
                        TextField(tr("Find an account"), text: $store.searchText)
                            .textFieldStyle(.plain)
                            .font(HubFont.body)
                            .foregroundStyle(HubStyle.textPrimary)
                            .accessibilityLabel(tr("Find an account"))
                        if !store.searchText.isEmpty {
                            Button {
                                store.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(HubStyle.textSecondary)
                            .help(tr("Clear search"))
                        }
                    }
                    .modifier(HubInputFieldSurface())
                    .padding(.horizontal, HubSpace.sm)
                    .padding(.bottom, HubSpace.sm)
                }

                SidebarAction(
                    symbol: "square.grid.2x2",
                    title: tr("Overview"),
                    shortcut: "⌘0",
                    selected: store.selectedID == nil
                ) {
                    store.select(nil)
                }
                .padding(.horizontal, horizontalPadding)

                if layout.isExpanded {
                    HStack(alignment: .center) {
                        Text(tr("Accounts"))
                            .font(HubFont.meta)
                            .foregroundStyle(HubStyle.textSecondary)
                        Spacer()
                        HubBadge(text: "\(store.accounts.count)")
                    }
                    .padding(.horizontal, HubSpace.md)
                    .padding(.top, HubSpace.lg)
                    .padding(.bottom, HubSpace.xs)
                } else {
                    Divider()
                        .overlay(HubStyle.border)
                        .padding(.horizontal, HubSpace.md)
                        .padding(.vertical, HubSpace.sm)
                }

                ScrollView {
                    LazyVStack(spacing: HubSpace.xxs) {
                        ForEach(layout.isExpanded ? store.filteredAccounts : store.accounts) { account in
                            AccountSidebarRow(account: account)
                        }
                        if layout.isExpanded && store.filteredAccounts.isEmpty {
                            Text(
                                tr(
                                    store.accounts.isEmpty
                                        ? "Your accounts will feel at home here." : "No matching accounts")
                            )
                            .font(HubFont.rowSubtitle)
                            .foregroundStyle(HubStyle.textSecondary)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(HubSpace.sm)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, HubSpace.xxs)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: HubSpace.xxs) {
                    Divider()
                        .overlay(HubStyle.border)
                        .padding(.horizontal, HubSpace.xs)
                        .padding(.bottom, HubSpace.xs)
                    SidebarAction(symbol: "magnifyingglass", title: tr("Switch Account…"), shortcut: "⌘K") {
                        store.isSwitchingAccount = true
                    }
                    SidebarAction(symbol: "plus", title: tr("Add account"), shortcut: "⌘N") { store.add() }
                        .disabled(store.loadError != nil)
                    SettingsLink {
                        HStack(spacing: HubSpace.sm) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .regular))
                                .frame(width: 34, height: 34)
                            if layout.isExpanded {
                                Text(tr("Settings"))
                                    .font(HubFont.bodyMedium)
                                    .foregroundStyle(HubStyle.textPrimary)
                                Spacer()
                                Text("⌘,")
                                    .font(HubFont.meta)
                                    .monospacedDigit()
                                    .foregroundStyle(HubStyle.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: HubSpace.rowHeight)
                        .padding(.horizontal, layout.isExpanded ? HubSpace.sm : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SidebarButtonStyle())
                    .foregroundStyle(HubStyle.textSecondary)
                    .help(tr("Settings") + " · ⌘,")
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, HubSpace.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: geometry.size.width) { _, width in layout.rememberWidth(width) }
        }
        .background(HubStyle.rail)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(HubStyle.border)
                .frame(width: 1)
        }
    }

    private var branding: some View {
        HStack(spacing: HubSpace.sm) {
            HubMark(size: 32)
            if layout.isExpanded {
                VStack(alignment: .leading, spacing: 1) {
                    Text("ChatHub")
                        .font(HubFont.brand)
                        .tracking(-0.2)
                        .foregroundStyle(HubStyle.textPrimary)
                    Text(tr("Workspace"))
                        .font(HubFont.meta)
                        .foregroundStyle(HubStyle.textSecondary)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, layout.isExpanded ? HubSpace.md : 0)
        .padding(.top, HubSpace.md)
        .padding(.bottom, HubSpace.md)
    }
}

private struct SidebarAction: View {
    @Environment(WorkspaceLayout.self) private var layout
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    let symbol: String
    let title: String
    var shortcut = ""
    var selected = false
    let action: () -> Void

    private var accent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        Button(action: action) {
            HStack(spacing: HubSpace.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: selected ? .semibold : .regular))
                    .frame(width: 34, height: 34)
                if layout.isExpanded {
                    Text(title)
                        .font(selected ? HubFont.rowTitle : HubFont.bodyMedium)
                        .foregroundStyle(selected ? HubStyle.textPrimary : HubStyle.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if !shortcut.isEmpty {
                        Text(shortcut)
                            .font(HubFont.meta)
                            .monospacedDigit()
                            .foregroundStyle(HubStyle.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: HubSpace.rowHeight)
            .padding(.horizontal, layout.isExpanded ? HubSpace.sm : 0)
            .background(
                selected ? HubStyle.selectedSurface(for: accent) : .clear,
                in: RoundedRectangle(cornerRadius: HubRadius.row, style: .continuous)
            )
            .foregroundStyle(selected ? HubStyle.accentTextColor(for: accent) : HubStyle.textSecondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle())
        .help(title + (shortcut.isEmpty ? "" : " · " + shortcut))
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct AccountSidebarRow: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(WorkspaceLayout.self) private var layout
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    let account: ChatAccount

    private var accent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }
    private var selected: Bool { store.selectedID == account.id }
    private var session: BrowserSession? { browsers.sessions[account.id] }
    private var shortcut: String {
        guard let index = store.accounts.firstIndex(where: { $0.id == account.id }), index < 9 else { return "" }
        return "⌘\(index + 1)"
    }

    var body: some View {
        Button {
            store.select(account.id)
        } label: {
            HStack(spacing: HubSpace.sm) {
                ServiceIcon(service: account.service, size: 34, branded: true)
                    .overlay(alignment: .topTrailing) {
                        if !layout.isExpanded, let session, session.unreadCount > 0 {
                            Text(session.unreadCount > 99 ? "99+" : "\(session.unreadCount)")
                                .font(.system(size: 9, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(HubStyle.accentColor(for: accent), in: Capsule())
                                .overlay(Capsule().strokeBorder(HubStyle.rail, lineWidth: 1.5))
                                .offset(x: 5, y: -4)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if let session {
                            if session.hasFailed {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                                    .background(HubStyle.rail, in: Circle())
                                    .offset(x: 3, y: 3)
                            } else if case .loaded = session.state {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().strokeBorder(HubStyle.rail, lineWidth: 1.5))
                                    .offset(x: 2, y: 2)
                            } else if case .loading = session.state {
                                Circle()
                                    .fill(HubStyle.accentColor(for: accent))
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().strokeBorder(HubStyle.rail, lineWidth: 1.5))
                                    .offset(x: 2, y: 2)
                            }
                        }
                    }
                if layout.isExpanded {
                    VStack(alignment: .leading, spacing: 2) {
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
                    if let session, session.unreadCount > 0 {
                        HubBadge(
                            text: session.unreadCount > 99 ? "99+" : "\(session.unreadCount)",
                            prominent: true
                        )
                    } else if !shortcut.isEmpty {
                        Text(shortcut)
                            .font(HubFont.meta)
                            .monospacedDigit()
                            .foregroundStyle(HubStyle.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: HubSpace.accountRowHeight)
            .padding(.horizontal, layout.isExpanded ? HubSpace.sm : 0)
            .background(
                selected ? HubStyle.selectedSurface(for: accent) : .clear,
                in: RoundedRectangle(cornerRadius: HubRadius.row, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle())
        .help(
            account.name + (account.subtitle.isEmpty ? "" : " · " + account.subtitle)
                + (shortcut.isEmpty ? "" : " · " + shortcut)
        )
        .accessibilityLabel(account.name + ", " + account.service.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu {
            Button(tr("Edit Account…")) { store.editingAccount = account }
            if store.canMove(account, by: -1) {
                Button(tr("Move Up")) { store.move(account, by: -1) }
            }
            if store.canMove(account, by: 1) {
                Button(tr("Move Down")) { store.move(account, by: 1) }
            }
            Button(tr("Open in Browser")) { if let url = account.url { NSWorkspace.shared.open(url) } }
            Divider()
            Button(tr("Remove Account…"), role: .destructive) { store.removingAccount = account }
        }
    }
}

private struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SidebarButtonSurface(isPressed: configuration.isPressed) { configuration.label }
    }
}

private struct SidebarButtonSurface<Content: View>: View {
    let isPressed: Bool
    @ViewBuilder let content: () -> Content
    @State private var hovered = false

    var body: some View {
        content()
            .background(
                isPressed ? HubStyle.pressed : (hovered ? HubStyle.hover : .clear),
                in: RoundedRectangle(cornerRadius: HubRadius.row, style: .continuous)
            )
            .onHover { hovered = $0 }
    }
}
