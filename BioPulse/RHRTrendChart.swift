//
//  RHRTrendChart.swift
//  BioPulse
//
//  Created by Connor Frank on 12/31/24.
//

import SwiftUI
import Charts

struct RHRTrendChart: View {
    let dailyRHR: [Date: Double]

    var body: some View {
        if dailyRHR.isEmpty {
            Text("No RHR data")
        } else {
            let dateKeys = dailyRHR.keys.sorted()
            let minVal = dailyRHR.values.min() ?? 50
            let maxVal = dailyRHR.values.max() ?? 90
            let yLo = max(40, minVal - 5)
            let yHi = maxVal + 5
            let avgRHR = dailyRHR.values.reduce(0, +) / Double(dailyRHR.count)
            let earliest = dateKeys.first ?? Date()
            let latest   = dateKeys.last  ?? Date()

            VStack(alignment: .leading) {
                Text("Resting HR (Last 30 Days)")
                    .font(.headline)
                    .padding(.horizontal, 16)

                Chart {
                    ForEach(dateKeys, id: \.self) { d in
                        LineMark(
                            x: .value("Date", d),
                            y: .value("RHR", dailyRHR[d] ?? 0)
                        )
                    }
                    RuleMark(y: .value("Average RHR", avgRHR))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.gray)
                }
                .chartYScale(domain: yLo...yHi)
                .chartXScale(domain: earliest...max(earliest, latest))
                .chartXAxis {
                    let now = Date()
                    let d7  = Calendar.current.date(byAdding: .day, value: -7,  to: now)!
                    let d14 = Calendar.current.date(byAdding: .day, value: -14, to: now)!
                    let d21 = Calendar.current.date(byAdding: .day, value: -21, to: now)!
                    let d28 = Calendar.current.date(byAdding: .day, value: -28, to: now)!
                    AxisMarks(values: [d28, d21, d14, d7]) { val in
                        if let dd = val.as(Date.self) {
                            let daysAgo = abs(Calendar.current.dateComponents([.day], from: dd, to: now).day ?? 0)
                            AxisValueLabel { Text("\(daysAgo)d ago") }
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
    }
}
