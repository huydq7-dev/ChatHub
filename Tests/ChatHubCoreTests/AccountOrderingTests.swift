import Foundation
import Testing

@testable import ChatHubCore

@Suite("Account ordering, pinning and sign-in detection")
struct AccountOrderingTests {
    private let a = ChatAccount(service: .telegram, name: "A", isPinned: true)
    private let b = ChatAccount(service: .zalo, name: "B")
    private let c = ChatAccount(service: .messenger, name: "C")
    private let d = ChatAccount(service: .discord, name: "D")

    private func names(_ accounts: [ChatAccount]) -> String { accounts.map(\.name).joined() }

    @Test func movingBeforeATargetTakesItsPinnedState() {
        let moved = AccountOrdering.move(c.id, before: b.id, in: [a, b, c, d])
        #expect(names(moved) == "ACBD")
        #expect(moved[1].isPinned == false)
        let pinnedDrop = AccountOrdering.move(d.id, before: a.id, in: [a, b, c, d])
        #expect(names(pinnedDrop) == "DABC")
        #expect(pinnedDrop[0].isPinned)
    }

    @Test func invalidMovesLeaveTheOrderAlone() {
        let all = [a, b, c, d]
        #expect(AccountOrdering.move(b.id, before: b.id, in: all) == all)
        #expect(AccountOrdering.move(UUID(), before: b.id, in: all) == all)
        #expect(AccountOrdering.move(b.id, before: UUID(), in: all) == all)
    }

    @Test func movingToTheEndUnpins() {
        let moved = AccountOrdering.moveToEnd(a.id, in: [a, b, c])
        #expect(names(moved) == "BCA")
        #expect(moved.last?.isPinned == false)
    }

    @Test func pinningJoinsThePinnedGroupAndUnpinningLeavesIt() {
        let pinned = AccountOrdering.setPinned(true, for: c.id, in: [a, b, c, d])
        #expect(names(pinned) == "ACBD")
        #expect(pinned.prefix(2).allSatisfy { $0.isPinned })
        let unpinned = AccountOrdering.setPinned(false, for: a.id, in: pinned)
        #expect(names(unpinned) == "CABD")
        #expect(AccountOrdering.setPinned(true, for: a.id, in: [a, b]) == [a, b])
    }

    @Test func signInPagesAreRecognisedPerService() throws {
        func url(_ value: String) -> URL? { URL(string: value) }
        #expect(SignInDetector.isSignInPage(service: .zalo, url: url("https://id.zalo.me/account?continue=x")))
        #expect(!SignInDetector.isSignInPage(service: .zalo, url: url("https://chat.zalo.me/")))
        #expect(SignInDetector.isSignInPage(service: .messenger, url: url("https://www.facebook.com/login/?next=x")))
        #expect(SignInDetector.isSignInPage(service: .messenger, url: url("https://www.facebook.com/checkpoint/1/")))
        #expect(!SignInDetector.isSignInPage(service: .messenger, url: url("https://www.facebook.com/messages/t/1")))
        #expect(!SignInDetector.isSignInPage(service: .messenger, url: url("https://evilfacebook.com/login")))
        #expect(SignInDetector.isSignInPage(service: .discord, url: url("https://discord.com/login")))
        #expect(!SignInDetector.isSignInPage(service: .telegram, url: url("https://web.telegram.org/a/")))
        #expect(!SignInDetector.isSignInPage(service: .zalo, url: nil))
    }

    @Test func eachServiceUsesExactlyOneKindOfSignal() {
        for service in ChatService.allCases {
            #expect(!(SignInDetector.usesURLSignal(service) && SignInDetector.usesPageSignal(service)))
        }
        #expect(SignInDetector.usesPageSignal(.telegram))
        #expect(!SignInDetector.usesURLSignal(.custom) && !SignInDetector.usesPageSignal(.custom))
    }

    @Test func oldWorkspacesDecodeAsUnpinnedAndNeverSignedIn() throws {
        let legacy = Data(
            #"{"id":"4B1F1D2C-0000-4000-8000-000000000003","service":"zalo","name":"Old","subtitle":"","createdAt":0}"#
                .utf8)
        let account = try JSONDecoder().decode(ChatAccount.self, from: legacy)
        #expect(!account.isPinned && !account.hasSignedIn)
        let saved = ChatAccount(service: .zalo, name: "New", isPinned: true, hasSignedIn: true)
        let decoded = try JSONDecoder().decode(ChatAccount.self, from: JSONEncoder().encode(saved))
        #expect(decoded.isPinned && decoded.hasSignedIn)
    }
}
