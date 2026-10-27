import Foundation
import Testing

@testable import ChatHubCore

@Suite("Unread navigation and sleeping")
struct AccountNavigationTests {
    private let a = ChatAccount(service: .telegram, name: "A")
    private let b = ChatAccount(service: .zalo, name: "B")
    private let c = ChatAccount(service: .messenger, name: "C")
    private var all: [ChatAccount] { [a, b, c] }

    @Test func nextUnreadWrapsAroundAndSkipsTheCurrentAccount() {
        let unread = [a.id: 2, c.id: 1]
        #expect(AccountNavigation.nextUnread(after: a.id, accounts: all, unread: unread) == c.id)
        #expect(AccountNavigation.nextUnread(after: c.id, accounts: all, unread: unread) == a.id)
        #expect(AccountNavigation.nextUnread(after: nil, accounts: all, unread: unread) == a.id)
    }

    @Test func nextUnreadIsNilWhenNothingElseIsUnread() {
        #expect(AccountNavigation.nextUnread(after: a.id, accounts: all, unread: [a.id: 5]) == nil)
        #expect(AccountNavigation.nextUnread(after: nil, accounts: [], unread: [:]) == nil)
        #expect(AccountNavigation.nextUnread(after: b.id, accounts: all, unread: [:]) == nil)
    }

    @Test func mutedAccountsAreNotJumpTargets() {
        var quiet = c
        quiet.notificationsMuted = true
        let accounts = [a, b, quiet]
        #expect(AccountNavigation.nextUnread(after: a.id, accounts: accounts, unread: [quiet.id: 9]) == nil)
        #expect(AccountNavigation.unreadFirst(accounts, unread: [quiet.id: 9]).map(\.id) == accounts.map(\.id))
    }

    @Test func unreadFirstKeepsSavedOrderWithinGroups() {
        let ordered = AccountNavigation.unreadFirst(all, unread: [b.id: 1, c.id: 4])
        #expect(ordered.map(\.name) == ["B", "C", "A"])
    }

    @Test func onlyIdleMutedBackgroundAccountsSleep() {
        let now = Date(timeIntervalSince1970: 100_000)
        let idle = now.addingTimeInterval(-7_200)
        func sleeps(
            muted: Bool = true, selected: Bool = false, downloading: Bool = false,
            lastActive: Date? = nil, after: TimeInterval = 3_600
        ) -> Bool {
            HibernationPolicy.shouldSleep(
                isMuted: muted, isSelected: selected, hasActiveDownload: downloading,
                lastActive: lastActive ?? idle, now: now, idleAfter: after)
        }
        #expect(sleeps())
        #expect(!sleeps(muted: false))
        #expect(!sleeps(selected: true))
        #expect(!sleeps(downloading: true))
        #expect(!sleeps(lastActive: now.addingTimeInterval(-60)))
        #expect(!sleeps(after: 0))
    }
}
