//
//  SleepDebtView.swift
//  BioPulse
//
//  Created by Connor Frank on 1/1/25
//

import Charts
import SwiftUI

struct SleepDebtView: View {
    let dailyDebt: [Date: Double]  // Rolling 14-day totals in seconds, for up to 30 days

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
                        }
                    }
                    .chartXScale(domain: xDomain(pts))
                    .chartXAxis {
                        let now = Date()
                        let d7 = Calendar.current.date(
                            byAdding: .day, value: -7, to: now)!
                        let d14 = Calendar.current.date(
                            byAdding: .day, value: -14, to: now)!
                        let d21 = Calendar.current.date(
                            byAdding: .day, value: -21, to: now)!
                        let d28 = Calendar.current.date(
                            byAdding: .day, value: -28, to: now)!
                        AxisMarks(values: [d28, d21, d14, d7]) { val in
                            if let dd = val.as(Date.self) {
                                let daysAgo = abs(
                                    Calendar.current.dateComponents(
                                        [.day], from: dd, to: now
                                    ).day ?? 0)
                                AxisValueLabel { Text("\(daysAgo)d ago") }
                            }
                            AxisTick(stroke: StrokeStyle(lineWidth: 0))
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                        }
                    }
                    .chartYAxis {
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

    private func sortedPoints() -> [(date: Date, debt: Double)] {
        let sortedDates = dailyDebt.keys.sorted()
        return sortedDates.map { d in
            (d, max(0, dailyDebt[d] ?? 0))
        }
    }

    private func xDomain(_ pts: [(date: Date, debt: Double)]) -> ClosedRange<
        Date
    > {
        guard let lastDate = pts.last?.date else {
            return Date()...Date()
        }
        let startDate =
            Calendar.current.date(byAdding: .day, value: -30, to: lastDate)
            ?? lastDate
        return startDate...lastDate
    }
}
