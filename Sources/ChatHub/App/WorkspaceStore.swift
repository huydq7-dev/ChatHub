import AppKit
import Observation

#if SWIFT_PACKAGE
    import ChatHubCore
#endif

@MainActor @Observable
final class WorkspaceStore {
    private(set) var accounts: [ChatAccount] = []
    private(set) var selectedID: UUID?
    private(set) var loadError: String?
    /// Accounts whose service is asking to sign in again. Not saved; the next launch re-detects it.
    private(set) var signedOut: Set<UUID> = []
    var errorMessage: String?
    var isAddingAccount = false
    var isSwitchingAccount = false
    var addAccountAfterSwitcher = false
    var suggestedService: ChatService?
    var editingAccount: ChatAccount?
    var removingAccount: ChatAccount?
    var searchText = ""
    @ObservationIgnored private let repository: WorkspaceRepository

    init(fileURL: URL? = nil) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatHub", isDirectory: true)
        repository = WorkspaceRepository(fileURL: fileURL ?? folder.appendingPathComponent("workspace.json"))
        reloadFromDisk()
    }

    var selectedAccount: ChatAccount? { accounts.first { $0.id == selectedID } }
    var filteredAccounts: [ChatAccount] {
        guard !searchText.isEmpty else { return accounts }
        return accounts.filter {
            "\($0.name) \($0.service.name) \($0.subtitle)".localizedCaseInsensitiveContains(searchText)
        }
    }

    func reloadFromDisk() {
        do {
            let archive = try repository.load()
            accounts = archive.accounts
            selectedID = archive.selectedAccountID
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func select(_ id: UUID?) {
        guard id == nil || accounts.contains(where: { $0.id == id }) else { return }
        if commit(accounts: accounts, selectedID: id) { selectedID = id }
    }

    /// Jumps to the next account with unread messages. Returns false when there is none.
    @discardableResult
    func selectNextUnread(unread: [UUID: Int]) -> Bool {
        guard let next = AccountNavigation.nextUnread(after: selectedID, accounts: accounts, unread: unread)
        else { return false }
        select(next)
        return selectedID == next
    }

    func add(service: ChatService? = nil) {
        suggestedService = service
        isAddingAccount = true
    }

    @discardableResult
    func saveAccount(_ account: ChatAccount) -> Bool {
        do {
            let account = try account.validated()
            var updated = accounts
            if let index = updated.firstIndex(where: { $0.id == account.id }) {
                updated[index] = account
            } else {
                updated.append(account)
            }
            guard commit(accounts: updated, selectedID: account.id) else { return false }
            accounts = updated
            selectedID = account.id
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func remove(_ account: ChatAccount) -> Bool {
        let updated = accounts.filter { $0.id != account.id }
        let selection = selectedID == account.id ? nil : selectedID
        guard commit(accounts: updated, selectedID: selection) else { return false }
        accounts = updated
        selectedID = selection
        signedOut.remove(account.id)
        return true
    }

    func canMove(_ account: ChatAccount, by offset: Int) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return false }
        let target = index + offset
        // Pinned accounts stay above the others; moving across the boundary is done by pinning.
        return accounts.indices.contains(target) && accounts[target].isPinned == accounts[index].isPinned
    }

    @discardableResult
    func move(_ account: ChatAccount, by offset: Int) -> Bool {
        guard canMove(account, by: offset),
            let index = accounts.firstIndex(where: { $0.id == account.id })
        else { return false }
        let target = index + offset
        var updated = accounts
        let item = updated.remove(at: index)
        updated.insert(item, at: target)
        guard commit(accounts: updated, selectedID: selectedID) else { return false }
        accounts = updated
        return true
    }

    /// The account being dragged, if the payload is one of ours. Reordering is off while a search filters the list.
    func draggedAccountID(from items: [String]) -> UUID? {
        guard searchText.isEmpty, let first = items.first, let id = UUID(uuidString: first),
            accounts.contains(where: { $0.id == id })
        else { return nil }
        return id
    }

    @discardableResult
    func moveAccount(_ id: UUID, before target: UUID) -> Bool {
        replaceOrder(AccountOrdering.move(id, before: target, in: accounts))
    }

    @discardableResult
    func moveAccountToEnd(_ id: UUID) -> Bool {
        replaceOrder(AccountOrdering.moveToEnd(id, in: accounts))
    }

    @discardableResult
    func setPinned(_ account: ChatAccount, _ pinned: Bool) -> Bool {
        replaceOrder(AccountOrdering.setPinned(pinned, for: account.id, in: accounts))
    }

    private func replaceOrder(_ updated: [ChatAccount]) -> Bool {
        guard updated != accounts, commit(accounts: updated, selectedID: selectedID) else { return false }
        accounts = updated
        return true
    }

    /// Records whether a service is asking to sign in. Returns true when a session that had been
    /// signed in has just expired, so the caller can tell the user once.
    @discardableResult
    func recordSignInState(for id: UUID, signInRequired: Bool) -> Bool {
        guard let account = accounts.first(where: { $0.id == id }) else { return false }
        if signInRequired {
            guard account.hasSignedIn, !signedOut.contains(id) else { return false }
            signedOut.insert(id)
            return true
        }
        signedOut.remove(id)
        if !account.hasSignedIn { _ = change(account) { $0.hasSignedIn = true } }
        return false
    }

    func isMuted(_ id: UUID) -> Bool { accounts.first { $0.id == id }?.notificationsMuted ?? false }
    func isSnoozed(_ id: UUID) -> Bool { accounts.first { $0.id == id }?.isSnoozed() ?? false }

    @discardableResult
    func setMuted(_ account: ChatAccount, _ muted: Bool) -> Bool {
        let changed = change(account) { $0.notificationsMuted = muted }
        if changed { HubNotificationCenter.shared.refreshBadge() }
        return changed
    }

    /// Silences alerts until `date`, or resumes them right away when `date` is nil.
    @discardableResult
    func setSnooze(_ account: ChatAccount, until date: Date?) -> Bool {
        change(account) { $0.snoozedUntil = date }
    }

    private func change(_ account: ChatAccount, _ edit: (inout ChatAccount) -> Void) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return false }
        var updated = accounts
        edit(&updated[index])
        guard commit(accounts: updated, selectedID: selectedID) else { return false }
        accounts = updated
        return true
    }

    func revealWorkspace() { NSWorkspace.shared.selectFile(repository.fileURL.path, inFileViewerRootedAtPath: "") }

    private func commit(accounts: [ChatAccount], selectedID: UUID?) -> Bool {
        guard loadError == nil else {
            errorMessage = tr("Resolve the workspace storage error before making changes.")
            return false
        }
        do {
            try repository.save(WorkspaceArchive(accounts: accounts, selectedAccountID: selectedID))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
