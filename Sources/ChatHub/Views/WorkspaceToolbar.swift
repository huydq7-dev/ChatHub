import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct WorkspaceToolbar: ToolbarContent {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(WorkspaceLayout.self) private var layout
    @AppStorage(ChatAppearancePreferences.themeKey) private var nativeThemeEnabled = true
    @AppStorage(ChatAppearancePreferences.toolsKey) private var showServiceTools = false
    @State private var showingAppearanceStudio = false
    @State private var showingDownloads = false
    private let downloads = DownloadCenter.shared

    private var supportsAppearance: Bool {
        store.selectedAccount.map { WebAppearancePolicy.supportsService($0.service) } ?? false
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                layout.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help(tr(layout.isExpanded ? "Collapse sidebar" : "Expand sidebar") + " · ⌃⌘S")
            .accessibilityLabel(tr(layout.isExpanded ? "Collapse sidebar" : "Expand sidebar"))
        }
        ToolbarItem(placement: .principal) {
            HStack(spacing: HubSpace.xs) {
                HubMark(size: 20)
                Text("ChatHub")
                    .font(HubFont.button)
                    .foregroundStyle(HubStyle.textPrimary)
                if let account = store.selectedAccount {
                    Text("·")
                        .font(HubFont.button)
                        .foregroundStyle(HubStyle.textSecondary)
                    Text(account.name)
                        .font(HubFont.bodyMedium)
                        .foregroundStyle(HubStyle.textPrimary)
                        .lineLimit(1)
                    HubBadge(text: account.subtitle.isEmpty ? account.service.name : account.subtitle)
                    if let secondary = store.secondaryAccount {
                        Text("+")
                            .font(HubFont.button)
                            .foregroundStyle(HubStyle.textSecondary)
                        Text(secondary.name)
                            .font(HubFont.bodyMedium)
                            .foregroundStyle(HubStyle.textPrimary)
                            .lineLimit(1)
                    }
                } else {
                    Text("·")
                        .font(HubFont.button)
                        .foregroundStyle(HubStyle.textSecondary)
                    Text(tr("Workspace"))
                        .font(HubFont.bodyMedium)
                        .foregroundStyle(HubStyle.textSecondary)
                }
            }
            .padding(.horizontal, HubSpace.sm)
            .padding(.vertical, 5)
            .background(
                HubStyle.raised,
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(HubStyle.border, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                store.isSwitchingAccount = true
            } label: {
                Image(systemName: "command")
            }
            .help(tr("Switch Account…") + " · ⌘K")
            .accessibilityLabel(tr("Switch Account…"))

            if !downloads.history.records.isEmpty {
                Button {
                    showingDownloads.toggle()
                } label: {
                    Image(
                        systemName: downloads.history.inProgressCount > 0
                            ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .help(tr("Downloads"))
                .accessibilityLabel(tr("Downloads"))
                .popover(isPresented: $showingDownloads, arrowEdge: .bottom) { DownloadsPopover() }
            }

            Button {
                showingAppearanceStudio.toggle()
            } label: {
                Image(systemName: "paintbrush.pointed")
            }
            .help(tr("Customize Appearance"))
            .accessibilityLabel(tr("Customize Appearance"))
            .popover(isPresented: $showingAppearanceStudio, arrowEdge: .bottom) {
                AppearanceStudioPopover(supportsServiceTools: supportsAppearance)
            }

            if let session = browsers.selectedSession {
                if supportsAppearance && nativeThemeEnabled {
                    Button {
                        showServiceTools.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(showServiceTools ? HubStyle.accentText : HubStyle.textSecondary)
                    }
                    .help(tr(showServiceTools ? "Hide extra service tools" : "Show extra service tools"))
                    .accessibilityLabel(tr(showServiceTools ? "Hide extra service tools" : "Show extra service tools"))
                }
                Button {
                    session.showFind()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help(tr("Find on this page") + " · ⌘F")
                .accessibilityLabel(tr("Find on this page"))
                Menu {
                    if supportsAppearance {
                        Toggle(tr("Match macOS Appearance"), isOn: $nativeThemeEnabled)
                        Divider()
                    }
                    Button(tr("Reload Service")) { session.reload() }
                    Button(tr("Open in Browser")) { session.openInBrowser() }
                    Button(tr("Back")) { session.webView.goBack() }.disabled(!session.canGoBack)
                    Button(tr("Forward")) { session.webView.goForward() }.disabled(!session.canGoForward)
                    Button(tr("Go to Service Home")) { session.loadHome() }
                    if store.secondaryAccount != nil {
                        Button(tr("Close Split View")) { store.closeSecondary() }
                    }
                    Divider()
                    if let account = store.selectedAccount {
                        AccountNotificationMenu(account: account)
                        Button(tr("Edit Account…")) { store.editingAccount = account }
                        Button(tr("Remove Account…"), role: .destructive) { store.removingAccount = account }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help(tr("Account options"))
                .accessibilityLabel(tr("Account options"))
            } else {
                Button {
                    store.add()
                } label: {
                    Image(systemName: "plus")
                }
                .help(tr("Add account") + " · ⌘N")
                .accessibilityLabel(tr("Add account"))
                .disabled(store.loadError != nil)
            }
        }
    }
}

private struct AppearanceStudioPopover: View {
    let supportsServiceTools: Bool
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(ChatAppearancePreferences.themeKey) private var nativeThemeEnabled = true
    @AppStorage(ChatAppearancePreferences.toolsKey) private var showServiceTools = false
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    @AppStorage(ChatAppearancePreferences.densityKey) private var densityRaw = HubDensity.standard.rawValue
    @AppStorage(ChatAppearancePreferences.textScaleKey) private var textScaleRaw = HubTextScale.standard.rawValue

    private var selectedAccent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        VStack(alignment: .leading, spacing: HubSpace.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Appearance Studio"))
                        .font(HubFont.rowTitle)
                        .foregroundStyle(HubStyle.textPrimary)
                    Text(tr("Instant across ChatHub and chat services"))
                        .font(HubFont.meta)
                        .foregroundStyle(HubStyle.textSecondary)
                }
                Spacer()
                HubMark(size: 26)
            }

            Divider().overlay(HubStyle.border)

            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Text(tr("Appearance"))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
                Picker(tr("Appearance"), selection: $appearance) {
                    Text(tr("System")).tag("system")
                    Text(tr("Light")).tag("light")
                    Text(tr("Dark")).tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: HubSpace.xs) {
                HStack {
                    Text(tr("Accent color"))
                        .font(HubFont.meta)
                        .foregroundStyle(HubStyle.textSecondary)
                    Spacer()
                    Text(selectedAccent.title)
                        .font(HubFont.meta)
                        .foregroundStyle(HubStyle.accentTextColor(for: selectedAccent))
                }
                HStack(spacing: 10) {
                    ForEach(HubAccent.allCases) { item in
                        let isSelected = selectedAccent == item
                        Button {
                            accentRaw = item.rawValue
                        } label: {
                            Circle()
                                .fill(item.swatchColor.gradient)
                                .frame(width: 26, height: 26)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle()
                                        .strokeBorder(
                                            isSelected ? HubStyle.textPrimary : .white.opacity(0.22),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .help(item.title)
                        .accessibilityLabel(item.title)
                    }
                }
            }

            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Text(tr("Text size"))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
                Picker(tr("Text size"), selection: $textScaleRaw) {
                    ForEach(HubTextScale.allCases) { scale in
                        Text(scale.title).tag(scale.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Text(tr("Layout density"))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
                Picker(tr("Layout density"), selection: $densityRaw) {
                    ForEach(HubDensity.allCases) { density in
                        Text(density.title).tag(density.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider().overlay(HubStyle.border)

            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Toggle(tr("Match macOS Appearance"), isOn: $nativeThemeEnabled)
                    .font(HubFont.captionMedium)
                if supportsServiceTools {
                    Toggle(tr("Show extra service tools"), isOn: $showServiceTools)
                        .font(HubFont.captionMedium)
                        .disabled(!nativeThemeEnabled)
                }
            }
        }
        .padding(HubSpace.md)
        .frame(width: 288)
        .background(HubStyle.surface)
        .tint(HubStyle.accentColor(for: selectedAccent))
    }
}
