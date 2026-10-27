import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct SettingsView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(WorkspaceLayout.self) private var layout
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage(ChatAppearancePreferences.themeKey) private var nativeThemeEnabled = true
    @AppStorage(ChatAppearancePreferences.toolsKey) private var showServiceTools = false
    @AppStorage(ChatAppearancePreferences.accentKey) private var accentRaw = HubAccent.iris.rawValue
    @AppStorage(ChatAppearancePreferences.densityKey) private var densityRaw = HubDensity.standard.rawValue
    @AppStorage(ChatAppearancePreferences.textScaleKey) private var textScaleRaw = HubTextScale.standard.rawValue
    @AppStorage(ChatAppearancePreferences.keepConnectedKey) private var keepConnected = true
    @AppStorage(ChatAppearancePreferences.showMenuBarKey) private var showMenuBar = true
    @AppStorage(ChatAppearancePreferences.sleepIdleHoursKey) private var sleepIdleHours = 1
    @State private var launchAtLogin = LaunchAtLogin.isRegistered
    @State private var launchError: String?

    private var selectedAccent: HubAccent { HubAccent(rawValue: accentRaw) ?? .iris }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                do {
                    try LaunchAtLogin.set(enabled)
                    launchError = nil
                } catch {
                    launchError = error.localizedDescription
                }
                launchAtLogin = LaunchAtLogin.isRegistered
            }
        )
    }

    private func idleLabel(_ hours: Int) -> String {
        switch hours {
        case 0: tr("Never")
        case 1: tr("1 hour")
        default: String(format: tr("%d hours"), hours)
        }
    }

    var body: some View {
        @Bindable var layout = layout
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
                Toggle(tr("Keep accounts connected in the background"), isOn: $keepConnected)
                Picker(tr("Sleep muted accounts after"), selection: $sleepIdleHours) {
                    ForEach(HibernationPolicy.allowedIdleHours, id: \.self) { hours in
                        Text(idleLabel(hours)).tag(hours)
                    }
                }
            } header: {
                Text(tr("Notifications"))
            } footer: {
                Text(
                    tr(
                        "Loads every account after launch so unread badges and notifications work before you open it. Uses more memory. Takes effect next launch when turned off. Mute individual accounts from their context menu."
                    ) + " "
                        + tr(
                            "Muted accounts that sit idle release their memory and reopen when selected. Accounts with notifications stay awake."
                        ))
            }
            QuietHoursSettingsSection()
            PrivacySettingsSection()
            Section {
                Toggle(tr("Show in menu bar"), isOn: $showMenuBar)
                Toggle(tr("Open ChatHub at login"), isOn: launchAtLoginBinding)
            } header: {
                Text(tr("Menu bar and startup"))
            } footer: {
                if let launchError {
                    Text(launchError).foregroundStyle(.red)
                } else if LaunchAtLogin.status == .requiresApproval {
                    Text(tr("Approve ChatHub in System Settings → General → Login Items."))
                }
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
