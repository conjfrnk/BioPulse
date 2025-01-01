//
//  HRVTrendChart.swift
//  BioPulse
//
//  Created by Connor Frank on 12/31/24.
//

import Charts
import SwiftUI

struct HRVTrendChart: View {
    let dailyHRV: [Date: Double]

    var body: some View {
        let filteredHRV = dailyHRV.filter { $0.value != 0 }
        if filteredHRV.isEmpty {
            Text("No HRV data")
        } else {
            let dateKeys = filteredHRV.keys.sorted()
            let minVal = filteredHRV.values.min() ?? 30
            let maxVal = filteredHRV.values.max() ?? 80
            let yLo = max(0, minVal - 5)
            let yHi = maxVal + 5
            let avgHRV =
                filteredHRV.values.reduce(0, +) / Double(filteredHRV.count)
            let earliest = dateKeys.first ?? Date()
            let latest = dateKeys.last ?? Date()

            VStack(alignment: .leading) {
                Text("HRV (Last 30 Days)")
                    .font(.headline)
                    .padding(.horizontal, 16)

                Chart {
                    ForEach(dateKeys, id: \.self) { d in
                        LineMark(
                            x: .value("Date", d),
                            y: .value("HRV", filteredHRV[d] ?? 0)
                        )
                    }
                    RuleMark(y: .value("Avg HRV", avgHRV))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.gray)
                }
                .chartYScale(domain: yLo...yHi)
                .chartXScale(domain: earliest...max(earliest, latest))
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
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 16)
            }
        }
    }
}
