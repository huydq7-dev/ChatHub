import SwiftUI

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

struct AccountEditor: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let existingAccount: ChatAccount?
    @State private var service: ChatService?
    @State private var name: String
    @State private var subtitle: String
    @State private var website: String
    @State private var linkBrowser: String?
    @State private var validationError: String?
    private let installedBrowsers = LinkOpener.installedBrowsers()
    @FocusState private var nameIsFocused: Bool

    init(account: ChatAccount? = nil, service: ChatService? = nil) {
        existingAccount = account
        _service = State(initialValue: account?.service ?? service)
        _name = State(initialValue: account?.name ?? service?.name ?? "")
        _subtitle = State(initialValue: account?.subtitle ?? "")
        _website = State(initialValue: account?.customURL?.absoluteString ?? "https://")
        _linkBrowser = State(initialValue: account?.linkBrowserID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HubSpace.xl) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HubSpace.xxs) {
                    Text(tr(existingAccount == nil ? "Make yourself at home." : "A name that feels right."))
                        .font(HubFont.pageTitle)
                        .tracking(-0.5)
                        .foregroundStyle(HubStyle.textPrimary)
                    Text(
                        tr(
                            existingAccount == nil
                                ? "Choose a service. Your conversations are one sign-in away."
                                : "Keep your accounts easy to tell apart.")
                    )
                    .font(HubFont.body)
                    .foregroundStyle(HubStyle.textSecondary)
                }
                Spacer()
                HubMark(size: 38)
            }

            if let service {
                details(service)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: HubSpace.sm
                ) {
                    ForEach(ChatService.allCases) { item in
                        ServiceCard(service: item) {
                            service = item
                            name = item == .custom ? "" : item.name
                            nameIsFocused = true
                        }
                    }
                }
            }

            if let validationError {
                Label(validationError, systemImage: "exclamationmark.circle")
                    .font(HubFont.captionMedium)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().overlay(HubStyle.border)
            HStack(spacing: HubSpace.sm) {
                if service != nil {
                    Label(tr("Separate sign-in for every account"), systemImage: "lock.shield")
                        .font(HubFont.caption)
                        .foregroundStyle(HubStyle.textSecondary)
                } else {
                    Text(tr("You can add multiple accounts for the same service."))
                        .font(HubFont.caption)
                        .foregroundStyle(HubStyle.textSecondary)
                }
                Spacer()
                Button(tr("Cancel")) { dismiss() }
                    .buttonStyle(HubButtonStyle())
                    .keyboardShortcut(.cancelAction)
                if service != nil {
                    Button(tr(existingAccount == nil ? "Add Account" : "Save Changes"), action: submit)
                        .buttonStyle(HubButtonStyle(prominent: true))
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(HubSpace.xl)
        .frame(width: 620)
        .background(HubStyle.canvas)
        .tint(HubStyle.accent)
        .onAppear { nameIsFocused = service != nil }
    }

    private func details(_ service: ChatService) -> some View {
        VStack(alignment: .leading, spacing: HubSpace.md) {
            HStack(spacing: HubSpace.sm) {
                ServiceIcon(service: service, size: 42)
                VStack(alignment: .leading, spacing: HubSpace.xxs) {
                    Text(service == .custom ? tr(service.name) : service.name)
                        .font(HubFont.rowTitle)
                        .foregroundStyle(HubStyle.textPrimary)
                    Text(service == .custom ? tr("Your own web messaging service") : service.homeURL?.host ?? "")
                        .font(HubFont.rowSubtitle)
                        .foregroundStyle(HubStyle.textSecondary)
                }
                Spacer()
                if existingAccount == nil {
                    Button(tr("Change")) {
                        self.service = nil
                        validationError = nil
                    }
                    .font(HubFont.captionMedium)
                    .buttonStyle(.link)
                }
            }
            .padding(HubSpace.md)
            .modifier(CardSurface())

            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Text(tr("Account name"))
                    .font(HubFont.captionMedium)
                    .foregroundStyle(HubStyle.textPrimary)
                TextField(tr("e.g. Telegram · Personal"), text: $name)
                    .textFieldStyle(.plain)
                    .font(HubFont.body)
                    .focused($nameIsFocused)
                    .modifier(HubInputFieldSurface())
                Text(tr("This name is only used in your ChatHub workspace."))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
            }
            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Text(tr("Label (optional)"))
                    .font(HubFont.captionMedium)
                    .foregroundStyle(HubStyle.textPrimary)
                TextField(tr("Personal, work, a little of both…"), text: $subtitle)
                    .textFieldStyle(.plain)
                    .font(HubFont.body)
                    .modifier(HubInputFieldSurface())
            }
            VStack(alignment: .leading, spacing: HubSpace.xs) {
                Text(tr("Open links in"))
                    .font(HubFont.captionMedium)
                    .foregroundStyle(HubStyle.textPrimary)
                Picker(tr("Open links in"), selection: $linkBrowser) {
                    Text(tr("Default browser")).tag(String?.none)
                    ForEach(installedBrowsers) { browser in
                        Text(browser.name).tag(String?.some(browser.id))
                    }
                }
                .labelsHidden()
                Text(tr("Links to other websites open in this browser instead of the system default."))
                    .font(HubFont.meta)
                    .foregroundStyle(HubStyle.textSecondary)
            }
            if service == .custom {
                VStack(alignment: .leading, spacing: HubSpace.xs) {
                    Text(tr("Website address"))
                        .font(HubFont.captionMedium)
                        .foregroundStyle(HubStyle.textPrimary)
                    TextField("https://chat.example.com", text: $website)
                        .textFieldStyle(.plain)
                        .font(HubFont.body)
                        .disabled(existingAccount != nil)
                        .modifier(HubInputFieldSurface())
                    Text(tr("Use the HTTPS address of a web chat. Compatibility depends on the website."))
                        .font(HubFont.meta)
                        .foregroundStyle(HubStyle.textSecondary)
                }
            }
            if existingAccount == nil {
                Text(
                    tr(
                        "Next, you’ll sign in directly on the service’s official website. ChatHub never asks for your password in this form."
                    )
                )
                .font(HubFont.caption)
                .foregroundStyle(HubStyle.textSecondary)
                .lineSpacing(3)
            }
        }
    }

    private func submit() {
        guard let service else { return }
        do {
            let url = service == .custom ? try SafeWebsiteURL.parse(website) : nil
            var account = existingAccount ?? ChatAccount(service: service, name: name, customURL: url)
            account.name = name
            account.subtitle = subtitle
            account.linkBrowserID = linkBrowser
            account = try account.validated()
            if store.saveAccount(account) { dismiss() }
        } catch { validationError = tr(error.localizedDescription) }
    }
}

struct RemoveAccountView: View {
    @Environment(WorkspaceStore.self) private var store
    @Environment(BrowserPool.self) private var browsers
    @Environment(\.dismiss) private var dismiss
    let account: ChatAccount
    @State private var isRemoving = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HubSpace.md) {
            ServiceIcon(service: account.service, size: 44)
            Text(tr("Remove this account?"))
                .font(HubFont.modalTitle)
                .tracking(-0.3)
                .foregroundStyle(HubStyle.textPrimary)
            Text(account.name)
                .font(HubFont.rowTitle)
                .foregroundStyle(HubStyle.textPrimary)
            Text(
                tr(
                    "This removes the account from ChatHub and deletes its local sign-in cookies and website data. Your account and messages on the service will not be deleted. Unsaved drafts and active downloads may be lost."
                )
            )
            .font(HubFont.body)
            .foregroundStyle(HubStyle.textSecondary)
            .lineSpacing(4)
            if let error {
                Text(error)
                    .font(HubFont.captionMedium)
                    .foregroundStyle(.red)
            }
            HStack(spacing: HubSpace.sm) {
                if isRemoving { ProgressView().controlSize(.small) }
                Spacer()
                Button(tr("Cancel")) { dismiss() }
                    .buttonStyle(HubButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRemoving)
                Button(tr("Remove Account"), role: .destructive) {
                    isRemoving = true
                    Task {
                        await browsers.remove(account)
                        if store.remove(account) {
                            dismiss()
                        } else {
                            error = store.errorMessage
                            store.errorMessage = nil
                            browsers.activate(store.selectedAccount)
                        }
                        isRemoving = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isRemoving)
            }
        }
        .padding(HubSpace.xl)
        .frame(width: 450)
        .background(HubStyle.canvas)
        .interactiveDismissDisabled(isRemoving)
    }
}
