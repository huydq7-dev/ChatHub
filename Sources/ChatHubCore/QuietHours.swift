import Foundation

/// A daily window in which ChatHub stays silent. Badges still update; only alerts are held back.
public struct QuietHours: Equatable, Sendable {
    public static let defaultStartMinute = 22 * 60
    public static let defaultEndMinute = 7 * 60

    public var isEnabled: Bool
    /// Minutes after midnight.
    public var startMinute: Int
    public var endMinute: Int

    public init(
        isEnabled: Bool = false, startMinute: Int = Self.defaultStartMinute, endMinute: Int = Self.defaultEndMinute
    ) {
        self.isEnabled = isEnabled
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    /// Handles windows that cross midnight, e.g. 22:00–07:00. Equal start and end mean no window.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, startMinute != endMinute else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute { return minute >= startMinute && minute < endMinute }
        return minute >= startMinute || minute < endMinute
    }
}

public enum SnoozeOption: CaseIterable, Sendable {
    case oneHour, untilMorning

    public func endDate(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .oneHour:
            return now.addingTimeInterval(3_600)
        case .untilMorning:
            return calendar.nextDate(
                after: now, matching: DateComponents(hour: 8, minute: 0), matchingPolicy: .nextTime)
                ?? now.addingTimeInterval(86_400)
        }
    }
}
