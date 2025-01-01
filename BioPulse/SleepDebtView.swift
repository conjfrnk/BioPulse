//
//  SleepDebtView.swift
//  BioPulse
//
//  Created by Connor Frank on 1/1/25
//

import Charts
import SwiftUI

/// Displays a line chart for the last 30 days of rolling 14-day sleep debt.
/// - X-axis domain: [lastDate - 30 days ... lastDate].
/// - Only four custom X-axis labels: 28d ago, 21d ago, 14d ago, 7d ago.
/// - No vertical lines/ticks on x-axis.
/// - The y-axis is default, so it shows horizontal grid lines/numeric labels.
/// - The aggregator can use data older than 30 days if needed for the 14-day sum.
/// - The chart only “displays” from 30 days ago to now.
struct SleepDebtView: View {
    let dailyDebt: [Date: Double]  // rolling 14-day totals in seconds, up to 30 days

    var body: some View {
        VStack(alignment: .leading) {
            Text("Sleep Debt (Last 30 Days)")
                .font(.headline)
                .padding(.horizontal)

            if dailyDebt.isEmpty {
                Text("No sleep debt data")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let pts = sortedPoints()
                if pts.isEmpty {
                    Text("No sleep debt data")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Chart {
                        // Remove the PointMark so only the red line is visible
                        ForEach(pts.indices, id: \.self) { i in
                            let p = pts[i]
                            LineMark(
                                x: .value("Date", p.date),
                                y: .value("Debt (hrs)", p.debt / 3600.0)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .chartXScale(domain: xDomain(pts))
                    .chartXAxis {
                        // Only four custom marks: 28d, 21d, 14d, 7d
                        // No vertical lines or ticks
                        AxisMarks(values: customAxisMarkers(pts)) { value in
                            AxisValueLabel(centered: true) {
                                if let d = value.as(Date.self) {
                                    Text(customLabel(for: d))
                                } else {
                                    Text("")
                                }
                            }
                            AxisTick(stroke: StrokeStyle(lineWidth: 0))
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                        }
                    }
                    .chartYAxis {
                        // Default Y-axis with horizontal lines
                        AxisMarks(preset: .automatic) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
            }
        }
    }

    /// Sort ascending by date, clamp debt >= 0
    private func sortedPoints() -> [(date: Date, debt: Double)] {
        let sortedDates = dailyDebt.keys.sorted()
        return sortedDates.map { d in
            (d, max(0, dailyDebt[d] ?? 0))
        }
    }

    /**
     X-axis domain: [lastDate - 30d, lastDate].
     Even if some data is older, we only *display* the last 30 days.
     The aggregator can use older data for the 14-day rolling sums, that’s fine.
     */
    private func xDomain(_ pts: [(date: Date, debt: Double)])
        -> ClosedRange<Date>
    {
        guard let lastDate = pts.last?.date else {
            return Date()...Date()
        }
        let earliest =
            Calendar.current.date(byAdding: .day, value: -30, to: lastDate)
            ?? lastDate
        return earliest...lastDate
    }

    /**
     Markers at 28, 21, 14, 7 days before lastDate.
     Guarantee all four appear, even if they normally clamp to domain edges.
     */
    private func customAxisMarkers(_ pts: [(date: Date, debt: Double)])
        -> [Date]
    {
        guard let lastDate = pts.last?.date else { return [] }
        let offsets = [28, 21, 14, 7]

        var markers: [Date] = []
        for offset in offsets {
            if let marker = Calendar.current.date(
                byAdding: .day, value: -offset, to: lastDate)
            {
                markers.append(marker)
            }
        }
        // We want to ensure they appear even if outside the domain.
        // The chart will clip them visually, but we do *not* clamp so they appear on the axis.
        return markers
    }

    /**
     Convert the difference from lastDate to a string: "28d ago," etc.
     If dayDiff is 0 => "0d ago" or blank. Typically won't happen unless offset=0.
     */
    private func customLabel(for d: Date) -> String {
        guard let lastDate = sortedPoints().last?.date else { return "" }
        let diff = Calendar.current.dateComponents(
            [.day], from: d, to: lastDate)
        let dayDiff = abs(diff.day ?? 0)
        return "\(dayDiff)d ago"
    }
}
