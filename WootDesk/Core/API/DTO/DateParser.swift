import Foundation

/// Tolerant parser for various timestamp formats across Chatwoot versions.
public enum DateParser: Sendable {
    /// Parses a date from any common Chatwoot representation:
    /// - Numeric Unix timestamp in seconds or milliseconds
    /// - ISO8601 string representation
    public static func parse(_ value: Any?) -> Date? {
        guard let value else { return nil }

        if let date = value as? Date {
            return date
        }

        if let number = value as? NSNumber {
            return parseUnixTime(number.doubleValue)
        }

        if let doubleVal = value as? Double {
            return parseUnixTime(doubleVal)
        }

        if let intVal = value as? Int {
            return parseUnixTime(Double(intVal))
        }

        if let stringVal = value as? String {
            if let doubleVal = Double(stringVal) {
                return parseUnixTime(doubleVal)
            }
            if let date = try? Date(stringVal, strategy: .iso8601) {
                return date
            }
            // Fallback for fractional seconds or custom formats
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: stringVal) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: stringVal) {
                return date
            }
        }

        return nil
    }

    private static func parseUnixTime(_ timestamp: Double) -> Date {
        // Values greater than 10^11 represent milliseconds
        if timestamp > 100_000_000_000 {
            return Date(timeIntervalSince1970: timestamp / 1000.0)
        }
        return Date(timeIntervalSince1970: timestamp)
    }
}
