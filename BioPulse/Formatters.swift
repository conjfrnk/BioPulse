//
//  Formatters.swift
//  BioPulse
//
//  Created by Connor Frank on 2/16/26.
//

import Foundation

/// Shared date formatters and formatting utilities for sleep data display.
/// Eliminates duplicated formatting code across views.
enum SleepFormatters {

    // MARK: - Reusable DateFormatters (created once, not per-call)

    /// "HH:mm" format (e.g. "23:15")
    static let timeOfDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "EEE, MMM d" format (e.g. "Mon, Jan 6")
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "EEEE, MMM d" format (e.g. "Monday, Jan 6")
    static let fullDayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    /// "yyyy-MM-dd" format for data export
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Duration Formatting

    /// Formats a duration in seconds as "Xh YYm" (e.g. "7h 32m").
    /// Handles negative durations with a leading minus sign.
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let isNegative = totalSeconds < 0
        let absSeconds = abs(totalSeconds)
        let h = absSeconds / 3600
        let m = (absSeconds % 3600) / 60
        let formatted = String(format: "%dh %02dm", h, m)
        return isNegative ? "-\(formatted)" : formatted
    }

    /// Formats a duration in seconds as a compact decimal hours string (e.g. "7.5h").
    static func formatDurationShort(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600.0
        return String(format: "%.1fh", hours)
    }

    // MARK: - Time of Day Formatting

    /// Formats a Date as "HH:mm" (e.g. "07:30").
    static func formatTimeOfDay(_ date: Date) -> String {
        return timeOfDay.string(from: date)
    }

    /// Converts a minute-of-day value (e.g. 450.0 = 7:30 AM) to "HH:mm".
    /// Values >= 1440 wrap around (e.g. 1500 becomes 01:00).
    static func formatMinutesAsTime(_ minutes: Double) -> String {
        var normalized = minutes
        if normalized >= 1440 { normalized -= 1440 }
        if normalized < 0 { normalized += 1440 }
        let h = Int(normalized) / 60
        let m = Int(normalized) % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Percentage Formatting

    /// Formats a 0-100 value as "XX%" (e.g. 85.3 becomes "85%").
    static func formatPercentage(_ value: Double) -> String {
        return String(format: "%.0f%%", value)
    }

    /// Formats a value as a signed percentage change (e.g. "+12%" or "-5%").
    static func formatPercentageChange(_ value: Double) -> String {
        return String(format: "%+.0f%%", value)
    }

    /// Formats a value as a signed percentage change with one decimal (e.g. "+12.3%").
    static func formatPercentageChangePrecise(_ value: Double) -> String {
        return String(format: "%+.1f%%", value)
    }
}
