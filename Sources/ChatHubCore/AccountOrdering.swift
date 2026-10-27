import Foundation

/// Reordering and pinning. Pinned accounts always form the first group of the saved order.
public enum AccountOrdering {
    /// Puts `id` just before `target` and gives it the target's pinned state.
    public static func move(_ id: UUID, before target: UUID, in accounts: [ChatAccount]) -> [ChatAccount] {
        guard id != target,
            var moving = accounts.first(where: { $0.id == id }),
            let destination = accounts.first(where: { $0.id == target })
        else { return accounts }
        moving.isPinned = destination.isPinned
        var rest = accounts.filter { $0.id != id }
        guard let index = rest.firstIndex(where: { $0.id == target }) else { return accounts }
        rest.insert(moving, at: index)
        return rest
    }

    /// Puts `id` last; it is no longer pinned.
    public static func moveToEnd(_ id: UUID, in accounts: [ChatAccount]) -> [ChatAccount] {
        guard var moving = accounts.first(where: { $0.id == id }) else { return accounts }
        moving.isPinned = false
        return accounts.filter { $0.id != id } + [moving]
    }

    /// Pinning appends to the pinned group; unpinning puts the account right after it.
    public static func setPinned(_ pinned: Bool, for id: UUID, in accounts: [ChatAccount]) -> [ChatAccount] {
        guard var account = accounts.first(where: { $0.id == id }), account.isPinned != pinned else {
            return accounts
        }
        account.isPinned = pinned
        var rest = accounts.filter { $0.id != id }
        rest.insert(account, at: rest.prefix(while: \.isPinned).count)
        return rest
    }
}
