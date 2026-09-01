import Foundation

/// The snooze durations WootDesk offers, plus the custom option that lets an
/// agent choose an exact return time.
///
/// Every option resolves to an absolute future date before it is sent, because
/// Chatwoot stores a return timestamp rather than a duration.
public enum ConversationSnoozeOption: String, CaseIterable, Identifiable, Sendable {
    case anHour
    case tomorrowMorning
    case nextWeek

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .anHour:
            return String(localized: "For an Hour", comment: "Snooze duration")
        case .tomorrowMorning:
            return String(localized: "Until Tomorrow Morning", comment: "Snooze duration")
        case .nextWeek:
            return String(localized: "Until Next Week", comment: "Snooze duration")
        }
    }

    /// The hour at which the morning-based options return a conversation.
    private static let morningHour = 9

    /// Resolves the option to an absolute return time.
    ///
    /// - Returns: The return date, or `nil` when the calendar cannot produce one
    ///   for the supplied reference date. A missing date is never replaced with a
    ///   guess, so the caller reports that the snooze time is unavailable.
    public func returnDate(
        from reference: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch self {
        case .anHour:
            return calendar.date(byAdding: .hour, value: 1, to: reference)
        case .tomorrowMorning:
            return Self.morning(daysAfter: 1, from: reference, calendar: calendar)
        case .nextWeek:
            return Self.morning(daysAfter: 7, from: reference, calendar: calendar)
        }
    }

    private static func morning(
        daysAfter days: Int,
        from reference: Date,
        calendar: Calendar
    ) -> Date? {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: reference) else {
            return nil
        }
        return calendar.date(
            bySettingHour: morningHour,
            minute: 0,
            second: 0,
            of: shifted
        )
    }
}
