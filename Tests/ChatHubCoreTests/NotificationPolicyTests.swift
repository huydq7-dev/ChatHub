import Foundation
import Testing

@testable import ChatHubCore

@Suite("Notification policy and muting")
struct NotificationPolicyTests {
    @Test func mutedOrVisibleConversationsDoNotAlert() {
        #expect(NotificationPolicy.shouldAlert(isMuted: false, isViewing: false))
        #expect(!NotificationPolicy.shouldAlert(isMuted: true, isViewing: false))
        #expect(!NotificationPolicy.shouldAlert(isMuted: false, isViewing: true))
    }

    @Test func fallbackIsSkippedWhenTheServiceAlreadyNotified() {
        let increase = Date(timeIntervalSince1970: 1_000)
        #expect(NotificationPolicy.needsFallback(increasedAt: increase, lastServiceNotification: nil))
        #expect(
            NotificationPolicy.needsFallback(
                increasedAt: increase, lastServiceNotification: increase.addingTimeInterval(-5)))
        #expect(
            !NotificationPolicy.needsFallback(
                increasedAt: increase, lastServiceNotification: increase.addingTimeInterval(1)))
    }

    @Test func dockBadgeExcludesMutedAccounts() {
        let loud = UUID()
        let quiet = UUID()
        let total = NotificationPolicy.dockTotal(unread: [loud: 3, quiet: 40], muted: [quiet])
        #expect(total == 3)
        #expect(NotificationPolicy.badgeLabel(total: total) == "3")
        #expect(NotificationPolicy.badgeLabel(total: 0) == nil)
        #expect(NotificationPolicy.badgeLabel(total: 150) == "99+")
    }

    @Test func workspacesSavedBeforeMutingStillLoadAsUnmuted() throws {
        let legacy = """
            {"id":"4B1F1D2C-0000-4000-8000-000000000001","service":"telegram","name":"Work",
             "subtitle":"","createdAt":0}
            """
        let account = try JSONDecoder().decode(ChatAccount.self, from: Data(legacy.utf8))
        #expect(account.notificationsMuted == false)
    }

    @Test func mutedStateSurvivesEncodingAndValidation() throws {
        let account = try ChatAccount(service: .zalo, name: "Family", notificationsMuted: true).validated()
        let decoded = try JSONDecoder().decode(ChatAccount.self, from: JSONEncoder().encode(account))
        #expect(decoded.notificationsMuted)
        #expect(decoded == account)
    }
}
