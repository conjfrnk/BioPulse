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

    let sleepNights: [HealthDataManager.NightData]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep (Last 8 nights)")
                .font(.headline)
                .padding(.horizontal)

            if trendData.isEmpty {
                Text("No trend data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                chartContent
            }
        }
    }

    private var df: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                sleepBars
                bedtimeAndWakePoints
                bedtimeLines
                wakeLines
                goalLines
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: 120)) { v in
                    if let minutes = v.as(Int.self) {
                        let disp = minutes % (24 * 60)
                        let d =
                            Calendar.current.date(
                                bySettingHour: disp / 60,
                                minute: disp % 60,
                                second: 0,
                                of: Date()
                            ) ?? Date()
                        AxisValueLabel {
                            Text(timeString(d))
                        }
                        AxisTick()
                        AxisGridLine()
                    }
                }
            }
            .chartYScale(domain: yAxisDomain())
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { val in
                    if let date = val.as(Date.self) {
                        AxisValueLabel {
                            Text(df.string(from: date))
                                .rotationEffect(.degrees(-45))
                        }
                        AxisTick()
                        AxisGridLine()
                    }
                }
            }
            .frame(height: 300)
            .padding(.horizontal)

            lastNightInfo
            recommendedBedtimeInfo
        }
    }

    private var sleepBars: some ChartContent {
        ForEach(trendData) { point in
            let b = minutesSinceMidnight(from: point.bedtime)
            let w = minutesSinceMidnight(from: point.wakeTime)
            RectangleMark(
                x: .value("Date", point.date),
                yStart: .value("Time", b),
                yEnd: .value("Time", w),
                width: 15
            )
            .foregroundStyle(.blue.opacity(0.3))
        }
    }

    private var bedtimeAndWakePoints: some ChartContent {
        ForEach(trendData) { point in
            let b = minutesSinceMidnight(from: point.bedtime)
            let w = minutesSinceMidnight(from: point.wakeTime)
            PointMark(
                x: .value("Date", point.date),
                y: .value("Time", b)
            )
            .foregroundStyle(.blue)
            .symbolSize(50)
            PointMark(
                x: .value("Date", point.date),
                y: .value("Time", w)
            )
            .foregroundStyle(.blue)
            .symbolSize(50)
        }
    }

    private var bedtimeLines: some ChartContent {
        ForEach(
            Array(zip(trendData.dropLast(), trendData.dropFirst())), id: \.0.id
        ) { p1, p2 in
            LineMark(
                x: .value("Date", p1.date),
                y: .value("Time", minutesSinceMidnight(from: p1.bedtime)),
                series: .value("Series", "Bedtime")
            )
            LineMark(
                x: .value("Date", p2.date),
                y: .value("Time", minutesSinceMidnight(from: p2.bedtime)),
                series: .value("Series", "Bedtime")
            )
            .foregroundStyle(.blue)
        }
    }

    private var wakeLines: some ChartContent {
        ForEach(
            Array(zip(trendData.dropLast(), trendData.dropFirst())), id: \.0.id
        ) { p1, p2 in
            LineMark(
                x: .value("Date", p1.date),
                y: .value("Time", minutesSinceMidnight(from: p1.wakeTime)),
                series: .value("Series", "Wake time")
            )
            LineMark(
                x: .value("Date", p2.date),
                y: .value("Time", minutesSinceMidnight(from: p2.wakeTime)),
                series: .value("Series", "Wake time")
            )
            .foregroundStyle(.blue)
        }
    }

    @ChartContentBuilder
    private var goalLines: some ChartContent {
        if let firstPoint = trendData.first {
            let (bed, wak) = goalTimes(for: firstPoint.date)
            let bm = minutesSinceMidnight(from: bed)
            let wm = minutesSinceMidnight(from: wak)
            RuleMark(y: .value("GoalBedtime", bm))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            RuleMark(y: .value("GoalWakeTime", wm))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
    }

    private var lastNightInfo: some View {
        if let lastNight = trendData.last {
            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Night:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Bedtime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeString(lastNight.bedtime))
                                .font(.body)
                        }
                        VStack(alignment: .leading) {
                            Text("Wake Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(timeString(lastNight.wakeTime))
                                .font(.body)
                        }
                    }
                }
                .padding(.horizontal)
            )
        }
        return AnyView(EmptyView())
    }

    private var recommendedBedtimeInfo: some View {
        let (recoBed, recoWake) = goalTimes(for: Date())
        return VStack(alignment: .leading, spacing: 8) {
            // Replacing old stage-based awake calculation with the real one from the NightData array
            Text(
                "Average Awake Time: \(durationStr(averageAwakeTimeFromNights))"
            )
            .font(.footnote)
            .foregroundColor(.secondary)
            Text("Recommended Bedtime (Tonight): \(timeString(recoBed))")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Goal Wake Time: \(timeString(recoWake))")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // This was the old internal stage-based awake logic. We no longer need it, so we won't use it.
    // We rely on the actual NightData's totalAwakeTime.

    private var averageAwakeTimeFromNights: TimeInterval {
        guard !sleepNights.isEmpty else { return 0 }
        let totalAwake = sleepNights.reduce(0) { $0 + $1.totalAwakeTime }
        return totalAwake / Double(sleepNights.count)
    }

    private var averageAwakeTimeInMinutes: Int {
        Int(averageAwakeTimeFromNights / 60)
    }

    private var adjustedGoalSleepMinutes: Int {
        goalSleepMinutes + averageAwakeTimeInMinutes
    }

    private func goalTimes(for date: Date) -> (bedtime: Date, wakeTime: Date) {
        let c = Calendar.current
        let comps = c.dateComponents([.hour, .minute], from: goalWakeTime)
        let w =
            c.date(
                bySettingHour: comps.hour ?? 7, minute: comps.minute ?? 0,
                second: 0, of: date) ?? date
        let secs = Double(adjustedGoalSleepMinutes * 60)
        let bed = c.date(byAdding: .second, value: -Int(secs), to: w) ?? w
        return (bed, w)
    }

    private func minutesSinceMidnight(from date: Date) -> Int {
        let c = Calendar.current
        let comps = c.dateComponents([.hour, .minute], from: date)
        var m = comps.hour! * 60 + comps.minute!
        if comps.hour! < 14 {
            m += 24 * 60
        }
        return m
    }

    private var trendData: [SleepTimingPoint] {
        let c = Calendar.current
        var grouped:
            [Date: [(
                stage: String,
                startDate: Date,
                endDate: Date
            )]] = [:]
        for entry in sleepData {
            let h = c.component(.hour, from: entry.startDate)
            let key: Date
            if h < 14 {
                key = c.date(
                    byAdding: .day, value: -1,
                    to: c.startOfDay(for: entry.startDate))!
            } else {
                key = c.startOfDay(for: entry.startDate)
            }
            grouped[key, default: []].append(entry)
        }

        let pts = grouped.compactMap { (night, recs) -> SleepTimingPoint? in
            let nonAwake = recs.filter { $0.stage != "Awake" }
            guard
                let first = nonAwake.min(by: { $0.startDate < $1.startDate }),
                let last = nonAwake.max(by: { $0.endDate < $1.endDate })
            else {
                return nil
            }
            return SleepTimingPoint(
                date: night,
                bedtime: first.startDate,
                wakeTime: last.endDate
            )
        }
        .sorted { $0.date > $1.date }
        .prefix(8)
        .reversed()
        return Array(pts)
    }

    private func durationStr(_ dur: TimeInterval) -> String {
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func yAxisDomain() -> ClosedRange<Int> {
        var bedMins: [Int] = []
        var wakeMins: [Int] = []
        for p in trendData {
            bedMins.append(minutesSinceMidnight(from: p.bedtime))
            wakeMins.append(minutesSinceMidnight(from: p.wakeTime))
            let (gb, gw) = goalTimes(for: p.date)
            bedMins.append(minutesSinceMidnight(from: gb))
            wakeMins.append(minutesSinceMidnight(from: gw))
        }
        guard let earliest = bedMins.min(), let latest = wakeMins.max()
        else {
            return 0...1440
        }
        return (earliest - 60)...(latest + 60)
    }
}
