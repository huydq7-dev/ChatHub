import Foundation

/// Ordering and jumping between accounts by unread state. Muted accounts never pull the user's attention.
public enum AccountNavigation {
    /// The next account after `current` (wrapping around) that has unread messages and is not muted.
    public static func nextUnread(after current: UUID?, accounts: [ChatAccount], unread: [UUID: Int]) -> UUID? {
        guard !accounts.isEmpty else { return nil }
        let startIndex = current.flatMap { id in accounts.firstIndex { $0.id == id } } ?? -1
        for step in 1...accounts.count {
            let candidate = accounts[(startIndex + step) % accounts.count]
            guard candidate.id != current else { continue }
            if !candidate.notificationsMuted, (unread[candidate.id] ?? 0) > 0 { return candidate.id }
        }
        return nil
    }

    /// Accounts with unread messages first; everything else keeps the saved order.
    public static func unreadFirst(_ accounts: [ChatAccount], unread: [UUID: Int]) -> [ChatAccount] {
        let hasUnread = accounts.filter { !$0.notificationsMuted && (unread[$0.id] ?? 0) > 0 }
        let ids = Set(hasUnread.map(\.id))
        return hasUnread + accounts.filter { !ids.contains($0.id) }
    }
}
