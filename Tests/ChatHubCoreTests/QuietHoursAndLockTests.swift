import Foundation
import Testing

@testable import ChatHubCore

@Suite("Quiet hours, snooze and app lock")
struct QuietHoursAndLockTests {
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 27) -> Date {
        Self.calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))
            ?? .distantPast
    }

    @Test func overnightWindowCoversLateNightAndEarlyMorning() {
        let quiet = QuietHours(isEnabled: true, startMinute: 22 * 60, endMinute: 7 * 60)
        #expect(quiet.contains(date(23, 30), calendar: Self.calendar))
        #expect(quiet.contains(date(3), calendar: Self.calendar))
        #expect(quiet.contains(date(22), calendar: Self.calendar))
        #expect(!quiet.contains(date(7), calendar: Self.calendar))
        #expect(!quiet.contains(date(12), calendar: Self.calendar))
    }

    @Test func sameDayWindowAndDisabledOrEmptyWindows() {
        let lunch = QuietHours(isEnabled: true, startMinute: 12 * 60, endMinute: 13 * 60)
        #expect(lunch.contains(date(12, 30), calendar: Self.calendar))
        #expect(!lunch.contains(date(13), calendar: Self.calendar))
        #expect(!QuietHours(isEnabled: false).contains(date(23), calendar: Self.calendar))
        let empty = QuietHours(isEnabled: true, startMinute: 600, endMinute: 600)
        #expect(!empty.contains(date(10), calendar: Self.calendar))
    }

    @Test func snoozeOptionsEndInTheFuture() {
        let evening = date(21)
        #expect(SnoozeOption.oneHour.endDate(from: evening, calendar: Self.calendar) == date(22))
        #expect(SnoozeOption.untilMorning.endDate(from: evening, calendar: Self.calendar) == date(8, day: 28))
        #expect(SnoozeOption.untilMorning.endDate(from: date(6), calendar: Self.calendar) == date(8))
    }

    @Test func snoozeExpiresByItself() {
        let account = ChatAccount(service: .zalo, name: "Family", snoozedUntil: date(9))
        #expect(account.isSnoozed(at: date(8)))
        #expect(!account.isSnoozed(at: date(9)))
        #expect(!ChatAccount(service: .zalo, name: "Family").isSnoozed(at: date(8)))
    }

    @Test func snoozedAndQuietHoursSilenceAlerts() {
        #expect(!NotificationPolicy.shouldAlert(isMuted: false, isViewing: false, isSnoozed: true))
        #expect(!NotificationPolicy.shouldAlert(isMuted: false, isViewing: false, isQuietHours: true))
        #expect(NotificationPolicy.shouldAlert(isMuted: false, isViewing: false))
    }

    @Test func snoozeSurvivesEncodingAndOldWorkspacesHaveNone() throws {
        let account = ChatAccount(service: .telegram, name: "Work", snoozedUntil: date(9))
        let decoded = try JSONDecoder().decode(ChatAccount.self, from: JSONEncoder().encode(account))
        #expect(decoded.snoozedUntil == account.snoozedUntil)
        let legacy = Data(
            #"{"id":"4B1F1D2C-0000-4000-8000-000000000002","service":"zalo","name":"Old","subtitle":"","createdAt":0}"#
                .utf8)
        #expect(try JSONDecoder().decode(ChatAccount.self, from: legacy).snoozedUntil == nil)
    }

    @Test func lockWaitsForTheTimeoutAndNeverLocksWithoutALeaveTime() {
        let left = date(10)
        #expect(AppLockPolicy.shouldLockOnReturn(leftAt: left, now: date(10), timeoutMinutes: 0))
        #expect(!AppLockPolicy.shouldLockOnReturn(leftAt: left, now: date(10, 4), timeoutMinutes: 5))
        #expect(AppLockPolicy.shouldLockOnReturn(leftAt: left, now: date(10, 5), timeoutMinutes: 5))
        #expect(!AppLockPolicy.shouldLockOnReturn(leftAt: nil, now: date(12), timeoutMinutes: 0))
    }
}
