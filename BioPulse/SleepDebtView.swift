//
//  SleepDebtView.swift
//  BioPulse
//
//  Created by Connor Frank on 1/1/25
//

import Charts
import SwiftUI

/// Displays a 30-day line chart, but each day's Y-value is a rolling 14-day
/// acute sleep debt. The 'dailyDebt' dictionary should map each day -> a 14-day
/// sum of missed sleep (seconds). We clamp at 0 to avoid negative values.
struct SleepDebtView: View {
    let dailyDebt: [Date: Double]  // total acute debt in seconds for each day

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
                        ForEach(pts.indices, id: \.self) { i in
                            let p = pts[i]
                            LineMark(
                                x: .value("Date", p.date),
                                y: .value("Debt (hrs)", p.debt / 3600.0)
                            )
                            .foregroundStyle(.red)
                            PointMark(
                                x: .value("Date", p.date),
                                y: .value("Debt (hrs)", p.debt / 3600.0)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .chartYScale(domain: yDomain(pts))
                    .chartXScale(domain: xDomain(pts))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { val in
                            if let d = val.as(Date.self) {
                                if d >= pts.first!.date && d <= pts.last!.date {
                                    AxisValueLabel {
                                        Text(labelForDate(d))
                                    }
                                    AxisTick()
                                    AxisGridLine()
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal)
                }
            }
        }
    }

    private func sortedPoints() -> [(date: Date, debt: Double)] {
        let sortedDates = dailyDebt.keys.sorted()
        return sortedDates.map { (d: Date) -> (date: Date, debt: Double) in
            let v = dailyDebt[d] ?? 0
            return (d, max(0, v))  // clamp at 0 to avoid negative
        }
    }

    private func xDomain(_ pts: [(date: Date, debt: Double)]) -> ClosedRange<
        Date
    > {
        guard let first = pts.first?.date, let last = pts.last?.date else {
            return Date()...Date()
        }
        return first...last
    }

    private func yDomain(_ pts: [(date: Date, debt: Double)]) -> ClosedRange<
        Double
    > {
        let values = pts.map { $0.debt / 3600.0 }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let lower = min(0, minVal - 0.5)
        let upper = maxVal + 0.5
        return lower...max(upper, 1)
    }

    private func labelForDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: d)
    }
}
