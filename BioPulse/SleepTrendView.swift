//
//  SleepTrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/17/24.
//

import Charts
import SwiftUI

struct SleepTimingPoint: Identifiable {
    let id = UUID()
    let date: Date
    let bedtime: Date
    let wakeTime: Date
}

struct SleepTrendView: View {
    let sleepData: [(stage: String, startDate: Date, endDate: Date)]
    let goalSleepMinutes: Int
    let goalWakeTime: Date

    private var averageAwakeTime: TimeInterval {
        let grouped = groupSleepDataByNight()
        guard !grouped.isEmpty else { return 0 }

        var nightlyAwakeDurations: [TimeInterval] = []

        for (_, records) in grouped {
            // Sum "Awake" intervals for this night
            let awakeTime =
                records
                .filter { $0.stage == "Awake" }
                .reduce(0) { partial, entry in
                    partial + entry.endDate.timeIntervalSince(entry.startDate)
                }
            nightlyAwakeDurations.append(awakeTime)
        }

        let totalAwake = nightlyAwakeDurations.reduce(0, +)
        return totalAwake / Double(nightlyAwakeDurations.count)
    }

    /// Helper to convert the average awake time in minutes (for easy math with goalSleepMinutes)
    private var averageAwakeTimeInMinutes: Int {
        Int(averageAwakeTime / 60)
    }

    /// The adjusted goal, combining user’s desired sleep minutes + average awake minutes
    private var adjustedGoalSleepMinutes: Int {
        goalSleepMinutes + averageAwakeTimeInMinutes
    }

    private func goalTimes(for date: Date) -> (bedtime: Date, wakeTime: Date) {
        let calendar = Calendar.current

        // The user’s normal "goalWakeTime" is a Time-of-Day.
        // We apply that time-of-day to the specified date.
        let wakeComponents = calendar.dateComponents(
            [.hour, .minute], from: goalWakeTime)
        let wakeTime =
            calendar.date(
                bySettingHour: wakeComponents.hour ?? 7,
                minute: wakeComponents.minute ?? 0,
                second: 0,
                of: date
            ) ?? date  // fallback if something fails

        // Adjusted total is user’s goal + average awake. Convert minutes → seconds
        let adjustedGoalSeconds = Double(adjustedGoalSleepMinutes * 60)

        // Bedtime is wakeTime minus the adjusted total
        let bedtime =
            calendar.date(
                byAdding: .second, value: -Int(adjustedGoalSeconds),
                to: wakeTime) ?? wakeTime

        return (bedtime, wakeTime)
    }

    private func minutesSinceMidnight(from date: Date) -> Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        var minutes = comps.hour! * 60 + comps.minute!

        // If it's before 14:00 (2 PM), treat it as "previous day"
        if comps.hour! < 14 {
            minutes += 24 * 60
        }
        return minutes
    }

    private var trendData: [SleepTimingPoint] {
        let grouped = groupSleepDataByNight()  // Reuse grouping logic
        // Build SleepTimingPoint from each night’s first/last non-Awake stage
        let points = grouped.compactMap {
            (nightDate, records) -> SleepTimingPoint? in
            let nonAwake = records.filter { $0.stage != "Awake" }
            guard
                let firstSleepStage = nonAwake.min(by: {
                    $0.startDate < $1.startDate
                }),
                let lastSleepStage = nonAwake.max(by: {
                    $0.endDate < $1.endDate
                })
            else {
                return nil
            }
            return SleepTimingPoint(
                date: nightDate, bedtime: firstSleepStage.startDate,
                wakeTime: lastSleepStage.endDate)
        }
        .sorted { $0.date > $1.date }
        .prefix(14)
        .reversed()

        return Array(points)
    }

    private func groupSleepDataByNight() -> [Date: [(
        stage: String, startDate: Date, endDate: Date
    )]] {
        var result = [Date: [(stage: String, startDate: Date, endDate: Date)]]()
        let calendar = Calendar.current

        for entry in sleepData {
            // If time is before 2 PM, consider it part of the "previous day"
            let hour = calendar.component(.hour, from: entry.startDate)
            let dateKey: Date
            if hour < 14 {
                // previous day’s start
                dateKey = calendar.date(
                    byAdding: .day, value: -1,
                    to: calendar.startOfDay(for: entry.startDate))!
            } else {
                dateKey = calendar.startOfDay(for: entry.startDate)
            }
            result[dateKey, default: []].append(entry)
        }
        return result
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // The chart needs a domain on the Y-axis
    private var yAxisBounds: ClosedRange<Int> {
        var bedtimeMinutes: [Int] = []
        var wakeTimeMinutes: [Int] = []

        for point in trendData {
            bedtimeMinutes.append(minutesSinceMidnight(from: point.bedtime))
            wakeTimeMinutes.append(minutesSinceMidnight(from: point.wakeTime))

            // Also consider the user’s *adjusted* (goal) bedtime & wake for each date
            let (goalBedtime, goalWake) = goalTimes(for: point.date)
            bedtimeMinutes.append(minutesSinceMidnight(from: goalBedtime))
            wakeTimeMinutes.append(minutesSinceMidnight(from: goalWake))
        }

        guard let earliest = bedtimeMinutes.min(),
            let latest = wakeTimeMinutes.max()
        else {
            return 0...1440
        }
        return (earliest - 60)...(latest + 60)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Sleep Timing Trends")
                .font(.headline)
                .padding(.horizontal)

            if trendData.isEmpty {
                Text("No trend data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(trendData) { point in
                            let bedtimeMinutes = minutesSinceMidnight(
                                from: point.bedtime)
                            let wakeTimeMinutes = minutesSinceMidnight(
                                from: point.wakeTime)

                            // Sleep duration bar
                            RectangleMark(
                                x: .value("Date", point.date),
                                yStart: .value("Time", bedtimeMinutes),
                                yEnd: .value("Time", wakeTimeMinutes),
                                width: 15
                            )
                            .foregroundStyle(.blue.opacity(0.3))

                            // Actual bedtime point
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Time", bedtimeMinutes)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(50)

                            // Actual wake time point
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Time", wakeTimeMinutes)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(50)
                        }

                        // Connect bedtime with a line
                        ForEach(
                            Array(
                                zip(trendData.dropLast(), trendData.dropFirst())
                            ), id: \.0.id
                        ) { p1, p2 in
                            LineMark(
                                x: .value("Date", p1.date),
                                y: .value(
                                    "Time",
                                    minutesSinceMidnight(from: p1.bedtime)),
                                series: .value("Series", "Bedtime")
                            )
                            LineMark(
                                x: .value("Date", p2.date),
                                y: .value(
                                    "Time",
                                    minutesSinceMidnight(from: p2.bedtime)),
                                series: .value("Series", "Bedtime")
                            )
                            .foregroundStyle(.blue)
                        }

                        // Connect wake times with a line
                        ForEach(
                            Array(
                                zip(trendData.dropLast(), trendData.dropFirst())
                            ), id: \.0.id
                        ) { p1, p2 in
                            LineMark(
                                x: .value("Date", p1.date),
                                y: .value(
                                    "Time",
                                    minutesSinceMidnight(from: p1.wakeTime)),
                                series: .value("Series", "Wake time")
                            )
                            LineMark(
                                x: .value("Date", p2.date),
                                y: .value(
                                    "Time",
                                    minutesSinceMidnight(from: p2.wakeTime)),
                                series: .value("Series", "Wake time")
                            )
                            .foregroundStyle(.blue)
                        }

                        // Goal bedtime & wake time lines
                        if let firstPoint = trendData.first {
                            let (bed, wake) = goalTimes(for: firstPoint.date)
                            let bedMinutes = minutesSinceMidnight(from: bed)
                            let wakeMinutes = minutesSinceMidnight(from: wake)

                            RuleMark(y: .value("GoalBedtime", bedMinutes))
                                .foregroundStyle(.green.opacity(0.5))
                                .lineStyle(
                                    StrokeStyle(lineWidth: 2, dash: [5, 5]))

                            RuleMark(y: .value("GoalWakeTime", wakeMinutes))
                                .foregroundStyle(.green.opacity(0.5))
                                .lineStyle(
                                    StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .stride(by: 120)) { value in
                            if let minutes = value.as(Int.self) {
                                let display = minutes % (24 * 60)
                                let date =
                                    Calendar.current.date(
                                        bySettingHour: display / 60,
                                        minute: display % 60,
                                        second: 0,
                                        of: Date()
                                    ) ?? Date()
                                AxisValueLabel {
                                    Text(timeFormatter.string(from: date))
                                }
                                AxisTick()
                                AxisGridLine()
                            }
                        }
                    }
                    .chartYScale(domain: yAxisBounds)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(dateFormatter.string(from: date))
                                        .rotationEffect(.degrees(-45))
                                }
                                AxisTick()
                                AxisGridLine()
                            }
                        }
                    }
                    .frame(height: 300)
                    .padding(.horizontal)

                    HStack(spacing: 20) {
                        HStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            Text("Actual Sleep")
                                .font(.caption)
                        }
                        HStack {
                            Rectangle()
                                .fill(.green.opacity(0.5))
                                .frame(width: 20, height: 2)
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            style: StrokeStyle(dash: [5, 5])
                                        )
                                        .foregroundColor(.green.opacity(0.5))
                                )
                            Text("Goal Times")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)

                    // Show last night’s bedtime/waketime as before
                    if let lastNight = trendData.last {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Night:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("Bedtime")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(
                                        timeFormatter.string(
                                            from: lastNight.bedtime)
                                    )
                                    .font(.body)
                                }
                                VStack(alignment: .leading) {
                                    Text("Wake Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(
                                        timeFormatter.string(
                                            from: lastNight.wakeTime)
                                    )
                                    .font(.body)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        let tonight = Date()
                        let (recoBedtime, recoWakeTime) = goalTimes(
                            for: tonight)

                        Text(
                            "Average Awake Time: \(formatDuration(averageAwakeTime))"
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)

                        Text(
                            "Recommended Bedtime (Tonight): \(timeFormatter.string(from: recoBedtime))"
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)

                        Text(
                            "Goal Wake Time: \(timeFormatter.string(from: recoWakeTime))"
                        )
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // Helper to format a TimeInterval as Hh Mm
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}
