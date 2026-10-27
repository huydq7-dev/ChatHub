import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct PaletteAction: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let shortcut: String
    let keywords: String
    var isEnabled: Bool = true
    let perform: () -> Void
}

struct AccountSwitcherView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(\.dismiss) private var dismiss
    @AppStorage("privacyShieldEnabled") private var privacyShieldEnabled = false
    @AppStorage("alwaysOnTopEnabled") private var alwaysOnTopEnabled = false
    @AppStorage("appearance") private var appearance = "system"
    @State private var query = ""
    @State private var highlighted = "overview"
    @FocusState private var searchFocused: Bool

    private var allActions: [PaletteAction] {
        [
            PaletteAction(
                id: "action-privacy",
                title: privacyShieldEnabled ? tr("Disable Privacy Shield") : tr("Enable Privacy Shield"),
                subtitle: tr("Blur messages with hover peek"),
                systemImage: privacyShieldEnabled ? "eye.slash.fill" : "eye.slash",
                shortcut: "⌘⇧P",
                keywords: "privacy shield boss mode blur che tin nhan",
                perform: { privacyShieldEnabled.toggle() }
            ),
            PaletteAction(
                id: "action-pin",
                title: alwaysOnTopEnabled ? tr("Disable Always on Top") : tr("Keep Window on Top"),
                subtitle: tr("Float window above other apps"),
                systemImage: alwaysOnTopEnabled ? "pin.fill" : "pin",
                shortcut: "⌘⇧T",
                keywords: "pin always on top float ghim cua so",
                perform: { alwaysOnTopEnabled.toggle() }
            ),
            PaletteAction(
                id: "action-add",
                title: tr("Add Account…"),
                subtitle: tr("Connect Telegram, Messenger, Zalo…"),
                systemImage: "plus.circle",
                shortcut: "⌘N",
                keywords: "add account new them tai khoan",
                perform: { store.addAccountAfterSwitcher = true }
            ),
            PaletteAction(
                id: "action-reload",
                title: tr("Reload Service"),
                subtitle: tr("Refresh current conversation"),
                systemImage: "arrow.clockwise",
                shortcut: "⌘R",
                keywords: "reload refresh tai lai",
                isEnabled: store.selectedID != nil,
                perform: { browsers.selectedSession?.reload() }
            ),
            PaletteAction(
                id: "action-find",
                title: tr("Find in Conversation…"),
                subtitle: tr("Search text in current chat"),
                systemImage: "magnifyingglass",
                shortcut: "⌘F",
                keywords: "find search tim kiem",
                isEnabled: store.selectedID != nil,
                perform: { browsers.selectedSession?.showFind() }
            ),
            PaletteAction(
                id: "action-browser",
                title: tr("Open in Browser"),
                subtitle: tr("Open in Safari or default browser"),
                systemImage: "safari",
                shortcut: "⌘⇧B",
                keywords: "browser open safari web ngoai",
                isEnabled: store.selectedID != nil,
                perform: { browsers.selectedSession?.openInBrowser() }
            ),
            PaletteAction(
                id: "action-theme",
                title: tr("Toggle Dark / Light Mode"),
                subtitle: tr("Switch between dark and light appearance"),
                systemImage: "circle.righthalf.filled",
                shortcut: "",
                keywords: "dark light theme mode giao dien sang toi",
                perform: {
                    appearance = (appearance == "dark" ? "light" : "dark")
                }
            ),
            PaletteAction(
                id: "action-settings",
                title: tr("Settings…"),
                subtitle: tr("Preferences, theme and data"),
                systemImage: "gearshape",
                shortcut: "⌘,",
                keywords: "settings preferences cai dat",
                perform: {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            ),
        ]
    }

    private var matchingActions: [PaletteAction] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allActions }
        return allActions.filter {
            $0.isEnabled
                && "\($0.title) \($0.subtitle) \($0.keywords)".localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var matchingAccounts: [ChatAccount] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.accounts }
        return store.accounts.filter {
            "\($0.name) \($0.subtitle) \($0.service.name)".localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var showOverview: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || tr("Overview").localizedCaseInsensitiveContains(trimmed)
    }

    private var destinations: [String] {
        var items: [String] = []
        if showOverview { items.append("overview") }
        items.append(contentsOf: matchingAccounts.map { $0.id.uuidString })
        items.append(contentsOf: matchingActions.map { $0.id })
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: HubSpace.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(HubStyle.textSecondary)
                TextField(tr("Search accounts or type a command…"), text: $query)
                    .textFieldStyle(.plain)
                    .font(HubFont.header)
                    .foregroundStyle(HubStyle.textPrimary)
                    .focused($searchFocused)
                    .onSubmit { open(highlighted) }
                    .onMoveCommand { move($0) }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(HubStyle.textSecondary)
                }
                .buttonStyle(.plain)
                .help(tr("Cancel"))
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, HubSpace.lg)
            .padding(.vertical, HubSpace.md)
            .liquidGlassCard(cornerRadius: 0)

            Divider().overlay(HubStyle.border)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: HubSpace.xxs) {
                        if showOverview || !matchingAccounts.isEmpty {
                            Text(tr("Accounts").uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(HubStyle.textSecondary.opacity(0.8))
                                .padding(.horizontal, HubSpace.sm)
                                .padding(.top, HubSpace.xs)

                            if showOverview {
                                switcherRow(
                                    id: "overview",
                                    title: tr("Overview"),
                                    subtitle: tr("Your workspace"),
                                    shortcut: "⌘0"
                                ) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(HubStyle.raised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(HubStyle.border, lineWidth: 1)
                                        )
                                        .overlay {
                                            Image(systemName: "square.grid.2x2")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(HubStyle.accentText)
                                        }
                                        .frame(width: 34, height: 34)
                                }
                            }

                            ForEach(Array(matchingAccounts.enumerated()), id: \.element.id) { index, account in
                                let indexShortcut = index < 9 ? "⌘\(index + 1)" : ""
                                switcherRow(
                                    id: account.id.uuidString,
                                    title: account.name,
                                    subtitle: account.subtitle.isEmpty ? account.service.name : account.subtitle,
                                    shortcut: indexShortcut
                                ) {
                                    ServiceIcon(service: account.service, size: 34)
                                }
                            }
                        }

                        if !matchingActions.isEmpty {
                            Text(tr("Actions").uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(HubStyle.textSecondary.opacity(0.8))
                                .padding(.horizontal, HubSpace.sm)
                                .padding(.top, (showOverview || !matchingAccounts.isEmpty) ? HubSpace.sm : HubSpace.xs)

                            ForEach(matchingActions) { action in
                                switcherRow(
                                    id: action.id,
                                    title: action.title,
                                    subtitle: action.subtitle,
                                    shortcut: action.shortcut
                                ) {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(HubStyle.raised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(HubStyle.border, lineWidth: 1)
                                        )
                                        .overlay {
                                            Image(systemName: action.systemImage)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(HubStyle.accentText)
                                        }
                                        .frame(width: 34, height: 34)
                                }
                            }
                        }

                        if destinations.isEmpty {
                            ContentUnavailableView.search(text: query).frame(height: 220)
                        }
                    }
                    .padding(HubSpace.sm)
                }
                .onChange(of: highlighted) { _, value in proxy.scrollTo(value, anchor: .center) }
            }
            .frame(height: 350)
            .background(HubStyle.canvas)

            Divider().overlay(HubStyle.border)

            HStack {
                Text(tr("↑↓ to navigate · ↩ to select · esc to close"))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
                Spacer()
                Button(tr("Add account")) {
                    store.addAccountAfterSwitcher = true
                    dismiss()
                }
                .buttonStyle(.link)
                .font(HubFont.captionMedium)
            }
            .padding(.horizontal, HubSpace.lg)
            .padding(.vertical, HubSpace.sm)
            .background(HubStyle.surface)
        }
        .frame(width: 520)
        .background(HubStyle.canvas)
        .tint(HubStyle.accent)
        .onAppear {
            highlighted = store.selectedID?.uuidString ?? "overview"
            searchFocused = true
        }
        .onChange(of: query) { _, _ in highlighted = destinations.first ?? "" }
    }

    private func switcherRow<Icon: View>(
        id: String,
        title: String,
        subtitle: String,
        shortcut: String = "",
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        let isSelected = highlighted == id
        return Button {
            open(id)
        } label: {
            HStack(spacing: HubSpace.sm) {
                icon()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HubFont.rowTitle)
                        .foregroundStyle(HubStyle.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(HubFont.rowSubtitle)
                        .foregroundStyle(HubStyle.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(HubStyle.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(HubStyle.raised, in: RoundedRectangle(cornerRadius: 5))
                }
                if isSelected {
                    Image(systemName: "return")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HubStyle.accentText)
                }
            }
            .padding(.horizontal, HubSpace.sm)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassCard(
                cornerRadius: HubRadius.row,
                tint: isSelected ? HubStyle.accent.opacity(0.18) : nil,
                interactive: true
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(HubStyle.accentText)
                        .frame(width: 3, height: 18)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func move(_ direction: MoveCommandDirection) {
        let ids = destinations
        guard !ids.isEmpty else { return }
        let index = ids.firstIndex(of: highlighted) ?? 0
        if direction == .down { highlighted = ids[min(index + 1, ids.count - 1)] }
        if direction == .up { highlighted = ids[max(index - 1, 0)] }
    }

    private func open(_ id: String) {
        if id == "overview" {
            store.select(nil)
            dismiss()
        } else if let uuid = UUID(uuidString: id) {
            store.select(uuid)
            dismiss()
        } else if let action = allActions.first(where: { $0.id == id }) {
            action.perform()
            dismiss()
        }
    }
}
