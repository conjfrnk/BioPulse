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
    var selectedPeriod: Int = 30

    var body: some View {
        let filteredHRV = dailyHRV.filter { $0.value != 0 }
        if filteredHRV.isEmpty {
            Text("No HRV data")
        } else {
            let dateKeys = filteredHRV.keys.sorted()
            let minVal = filteredHRV.values.min() ?? 30
            let maxVal = filteredHRV.values.max() ?? 80
            let yLo = max(0, min(minVal - 5, 20))
            let yHi = max(maxVal + 5, 80)
            let avgHRV =
                filteredHRV.values.reduce(0, +) / Double(filteredHRV.count)
            let earliest = dateKeys.first ?? Date()
            let latest = dateKeys.last ?? Date()
            let movingAvg = computeMovingAverage(data: filteredHRV, window: 7)

            VStack(alignment: .leading) {
                Chart {
                    // Healthy range band (green)
                    RectangleMark(
                        xStart: .value("Start", earliest),
                        xEnd: .value("End", latest),
                        yStart: .value("Lo", max(yLo, 40)),
                        yEnd: .value("Hi", min(yHi, 80))
                    )
                    .foregroundStyle(.green.opacity(0.1))

                    // Below average band (yellow)
                    RectangleMark(
                        xStart: .value("Start", earliest),
                        xEnd: .value("End", latest),
                        yStart: .value("Lo", max(yLo, 20)),
                        yEnd: .value("Hi", min(yHi, 40))
                    )
                    .foregroundStyle(.yellow.opacity(0.1))

                    ForEach(dateKeys, id: \.self) { d in
                        LineMark(
                            x: .value("Date", d),
                            y: .value("HRV", filteredHRV[d] ?? 0),
                            series: .value("Series", "Daily")
                        )
                        .foregroundStyle(.green)
                    }
                    ForEach(dateKeys, id: \.self) { d in
                        AreaMark(
                            x: .value("Date", d),
                            y: .value("HRV", filteredHRV[d] ?? 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // 7-day moving average
                    let maKeys = movingAvg.keys.sorted()
                    ForEach(maKeys, id: \.self) { d in
                        LineMark(
                            x: .value("Date", d),
                            y: .value("HRV", movingAvg[d] ?? 0),
                            series: .value("Series", "7d Avg")
                        )
                        .foregroundStyle(Color.green.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    RuleMark(y: .value("Avg HRV", avgHRV))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.gray)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg: \(Int(avgHRV)) ms")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                        }
                }
                .chartYScale(domain: yLo...yHi)
                .chartXScale(domain: earliest...max(earliest, latest))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { val in
                        if let dd = val.as(Date.self) {
                            let now = Date()
                            let daysAgo = abs(
                                Calendar.current.dateComponents(
                                    [.day], from: dd, to: now
                                ).day ?? 0)
                            AxisValueLabel { Text("\(daysAgo)d ago") }
                        }
                    }
                }
                .frame(height: 200)
                .clipped()
                .padding(.horizontal, 16)
            }
        }
    }

    private func computeMovingAverage(data: [Date: Double], window: Int) -> [Date: Double] {
        let sorted = data.sorted { $0.key < $1.key }
        var result: [Date: Double] = [:]
        for i in 0..<sorted.count {
            let start = max(0, i - window + 1)
            let slice = sorted[start...i]
            let avg = slice.map(\.value).reduce(0, +) / Double(slice.count)
            result[sorted[i].key] = avg
        }
        return result
    }
}
