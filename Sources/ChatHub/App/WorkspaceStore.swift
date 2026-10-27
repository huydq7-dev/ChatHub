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
        return true
    }

    func canMove(_ account: ChatAccount, by offset: Int) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return false }
        let target = index + offset
        return accounts.indices.contains(target)
    }

    @discardableResult
    func move(_ account: ChatAccount, by offset: Int) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return false }
        let target = index + offset
        guard accounts.indices.contains(target) else { return false }
        var updated = accounts
        let item = updated.remove(at: index)
        updated.insert(item, at: target)
        guard commit(accounts: updated, selectedID: selectedID) else { return false }
        accounts = updated
        return true
    }

    func isMuted(_ id: UUID) -> Bool { accounts.first { $0.id == id }?.notificationsMuted ?? false }

    @discardableResult
    func setMuted(_ account: ChatAccount, _ muted: Bool) -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return false }
        var updated = accounts
        updated[index].notificationsMuted = muted
        guard commit(accounts: updated, selectedID: selectedID) else { return false }
        accounts = updated
        HubNotificationCenter.shared.refreshBadge()
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
