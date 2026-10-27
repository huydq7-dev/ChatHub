import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct SettingsView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(WorkspaceLayout.self) private var layout
    @Environment(AppUpdater.self) private var updater
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(ChatAppearancePreferences.themeKey) private var nativeThemeEnabled = true
    @AppStorage(ChatAppearancePreferences.toolsKey) private var showServiceTools = false
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    @AppStorage(ChatAppearancePreferences.densityKey) private var densityRaw = HubDensity.standard.rawValue
    @AppStorage(ChatAppearancePreferences.textScaleKey) private var textScaleRaw = HubTextScale.standard.rawValue
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("privacyShieldEnabled") private var privacyShieldEnabled = false
    @AppStorage("alwaysOnTopEnabled") private var alwaysOnTopEnabled = false

    private var selectedAccent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    var body: some View {
        @Bindable var layout = layout
        @Bindable var updater = updater
        Form {
            Section {
                HStack(spacing: HubSpace.md) {
                    HubMark(size: 46)
                    VStack(alignment: .leading, spacing: HubSpace.xxs) {
                        Text("ChatHub")
                            .font(HubFont.modalTitle)
                            .tracking(-0.3)
                            .foregroundStyle(HubStyle.textPrimary)
                        Text(tr("A calmer place for your chats."))
                            .font(HubFont.rowSubtitle)
                            .foregroundStyle(HubStyle.textSecondary)
                    }
                    Spacer()
                    HubBadge(
                        text: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
                    )
                }
                .padding(.vertical, HubSpace.xxs)
            }
            Section(tr("Make it yours")) {
                Picker(tr("Appearance"), selection: $appearance) {
                    Text(tr("System")).tag("system")
                    Text(tr("Light")).tag("light")
                    Text(tr("Dark")).tag("dark")
                }
                .pickerStyle(.segmented)

                LabeledContent(tr("Accent color")) {
                    HStack(spacing: 10) {
                        ForEach(HubAccent.allCases) { item in
                            let isSelected = selectedAccent == item
                            Button {
                                accentRaw = item.rawValue
                            } label: {
                                Circle()
                                    .fill(item.swatchColor.gradient)
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
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
                        }
                    }
                }

                Picker(tr("Text size"), selection: $textScaleRaw) {
                    ForEach(HubTextScale.allCases) { scale in
                        Text(scale.title).tag(scale.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Picker(tr("Layout density"), selection: $densityRaw) {
                    ForEach(HubDensity.allCases) { density in
                        Text(density.title).tag(density.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent(tr("Language"), value: tr("Follows your macOS app language"))
                Toggle(tr("Show account names in sidebar"), isOn: $layout.isExpanded)
            }
            Section {
                Toggle(tr("Match macOS Appearance"), isOn: $nativeThemeEnabled)
                Toggle(tr("Show extra service tools"), isOn: $showServiceTools).disabled(!nativeThemeEnabled)
            } header: {
                Text(tr("Chat appearance"))
            } footer: {
                Text(
                    tr(
                        "One ChatHub appearance for Telegram, Messenger and Zalo. Colors, typography and chat surfaces follow the appearance above. Show extra tools to access service-specific controls. Turn off to restore the original interfaces."
                    ))
            }
            Section {
                Toggle(tr("Show Menu Bar Icon"), isOn: $showMenuBarExtra)
                Toggle(tr("Privacy Shield (Blur messages)"), isOn: $privacyShieldEnabled)
                Toggle(tr("Keep window always on top"), isOn: $alwaysOnTopEnabled)
            } header: {
                Text(tr("Workspace & Privacy"))
            } footer: {
                Text(
                    tr(
                        "Privacy Shield blurs messages and media in open chats; hover with your mouse to peek. Always on Top keeps ChatHub visible above other windows."
                    ))
            }
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: HubSpace.xxs) {
                        Text(tr("System Notifications"))
                            .font(HubFont.body)
                        Text(
                            tr(
                                "Receive notifications for new messages across your active and background accounts."
                            )
                        )
                        .font(HubFont.caption)
                        .foregroundStyle(HubStyle.textSecondary)
                    }
                    Spacer()
                    Button(tr("Send Test Notification")) {
                        HubNotificationCenter.shared.sendTestNotification()
                    }
                }
            } header: {
                Text(tr("Notifications"))
            } footer: {
                Text(
                    tr(
                        "Make sure notifications are enabled for ChatHub in macOS System Settings > Notifications."
                    ))
            }
            Section {
                Toggle(tr("Automatically check for updates"), isOn: $updater.automaticChecksEnabled)
                HStack {
                    if updater.isChecking {
                        ProgressView().controlSize(.small)
                        Text(tr("Checking for updates…")).font(HubFont.caption)
                    } else if let date = updater.lastChecked {
                        Text(tr("Last checked"))
                        Text(date, style: .relative).foregroundStyle(HubStyle.textSecondary)
                    }
                    Spacer()
                    Button(tr("Check for Updates…")) { updater.checkManually() }
                        .disabled(updater.isChecking)
                }
            } header: {
                Text(tr("Updates"))
            } footer: {
                Text(
                    tr(
                        "ChatHub checks GitHub Releases every six hours. New versions appear in the workspace. Installation is manual; your chats and account profiles stay in place."
                    ))
            }
            Section {
                LabeledContent(tr("Accounts"), value: "\(store.accounts.count)")
                LabeledContent(tr("Open service sessions"), value: "\(browsers.sessions.count)")
                Button(tr("Show Workspace File in Finder")) { store.revealWorkspace() }
            } header: {
                Text(tr("Your data"))
            } footer: {
                Text(
                    tr(
                        "Account names are saved locally. Each account’s cookies and website data use a separate WebKit profile. Remove an account to delete its local session. ChatHub does not send your messages to a ChatHub server."
                    ))
            }
            Section {
                Text(
                    tr(
                        "Calling, screen sharing and background notifications depend on each service."
                    )
                )
                .font(HubFont.caption)
                .foregroundStyle(HubStyle.textSecondary)
                Text(tr("Closing the window keeps your loaded sessions running. Press ⌘Q to quit ChatHub."))
                    .font(HubFont.caption)
                    .foregroundStyle(HubStyle.textSecondary)
            } header: {
                Text(tr("Good to know"))
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 740)
        .tint(HubStyle.accentColor(for: selectedAccent))
    }
}
