//
//  RHRTrendChart.swift
//  BioPulse
//
//  Created by Connor Frank on 12/31/24.
//

import Charts
import SwiftUI

struct RHRTrendChart: View {
    let dailyRHR: [Date: Double]
    var selectedPeriod: Int = 30

    var body: some View {
        let filteredRHR = dailyRHR.filter { $0.value != 0 }
        if filteredRHR.isEmpty {
            Text("No RHR data")
        } else {
            let dateKeys = filteredRHR.keys.sorted()
            let minVal = filteredRHR.values.min() ?? 50
            let maxVal = filteredRHR.values.max() ?? 90
            let yLo = max(35, minVal - 5)
            let yHi = maxVal + 5
            let avgRHR =
                filteredRHR.values.reduce(0, +) / Double(filteredRHR.count)
            let earliest = dateKeys.first ?? Date()
            let latest = dateKeys.last ?? Date()
            let movingAvg = computeMovingAverage(data: filteredRHR, window: 7)

            VStack(alignment: .leading) {
                Chart {
                    // Healthy range band (green): 50-70 bpm
                    RectangleMark(
                        xStart: .value("Start", earliest),
                        xEnd: .value("End", latest),
                        yStart: .value("Lo", max(yLo, 50)),
                        yEnd: .value("Hi", min(yHi, 70))
                    )
                    .foregroundStyle(.green.opacity(0.1))

                    // Below healthy band (yellow): 40-50 bpm
                    if yLo < 50 {
                        RectangleMark(
                            xStart: .value("Start", earliest),
                            xEnd: .value("End", latest),
                            yStart: .value("Lo", max(yLo, 40)),
                            yEnd: .value("Hi", 50)
                        )
                        .foregroundStyle(.yellow.opacity(0.1))
                    }

                    // Above healthy band (yellow): 70-80 bpm
                    if yHi > 70 {
                        RectangleMark(
                            xStart: .value("Start", earliest),
                            xEnd: .value("End", latest),
                            yStart: .value("Lo", 70),
                            yEnd: .value("Hi", min(yHi, 80))
                        )
                        .foregroundStyle(.yellow.opacity(0.1))
                    }

                    ForEach(dateKeys, id: \.self) { d in
                        LineMark(
                            x: .value("Date", d),
                            y: .value("RHR", filteredRHR[d] ?? 0),
                            series: .value("Series", "Daily")
                        )
                        .foregroundStyle(.red)
                    }
                    ForEach(dateKeys, id: \.self) { d in
                        AreaMark(
                            x: .value("Date", d),
                            y: .value("RHR", filteredRHR[d] ?? 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.3), Color.red.opacity(0.05)]),
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
                            y: .value("RHR", movingAvg[d] ?? 0),
                            series: .value("Series", "7d Avg")
                        )
                        .foregroundStyle(Color.red.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    RuleMark(y: .value("Avg RHR", avgRHR))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.gray)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg: \(Int(avgRHR)) bpm")
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
                .padding(.bottom, 30)
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
