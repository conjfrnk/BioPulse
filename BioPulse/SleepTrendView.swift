//
//  SleepTrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/17/24.
//

import SwiftUI
import Charts

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
    
    private func goalTimes(for date: Date) -> (bedtime: Date, wakeTime: Date) {
        let calendar = Calendar.current
        // Set wake time for the given date
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: goalWakeTime)
        let wakeTime = calendar.date(bySettingHour: wakeComponents.hour ?? 7,
                                     minute: wakeComponents.minute ?? 0,
                                     second: 0,
                                     of: date)!
        
        // Calculate bedtime by going backwards from wake time
        let bedtime = calendar.date(byAdding: .minute, value: -goalSleepMinutes, to: wakeTime)!
        
        return (bedtime, wakeTime)
    }
    
    private func minutesSinceMidnight(from date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        var minutes = components.hour! * 60 + components.minute!
        
        // If it's before 14:00 (2 PM), treat it as previous day's time
        if components.hour! < 14 {
            minutes += 24 * 60  // Add 24 hours worth of minutes
        }
        return minutes
    }
    
    // Calculated trend data
    private var trendData: [SleepTimingPoint] {
        let calendar = Calendar.current
        
        // Group sleep data by night (using 2PM cutoff for date grouping)
        let groupedByNight = Dictionary(grouping: sleepData) { entry in
            // If time is before 2PM, consider it part of the previous day
            if calendar.component(.hour, from: entry.startDate) < 14 {
                return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: entry.startDate))!
            }
            return calendar.startOfDay(for: entry.startDate)
        }
        
        return groupedByNight.compactMap { (date, nightData) -> SleepTimingPoint? in
            // Find first and last non-Awake stage
            guard let firstSleepStage = nightData
                .filter({ $0.stage != "Awake" })
                .min(by: { $0.startDate < $1.startDate }),
                  let lastSleepStage = nightData
                .filter({ $0.stage != "Awake" })
                .max(by: { $0.endDate < $1.endDate }) else {
                return nil
            }
            
            return SleepTimingPoint(
                date: date,
                bedtime: firstSleepStage.startDate,
                wakeTime: lastSleepStage.endDate
            )
        }
        .sorted(by: { $0.date > $1.date })
        .prefix(14)
        .reversed()
    }
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // Find y-axis bounds based on data
    private var yAxisBounds: ClosedRange<Int> {
        // Get all relevant times
        var allMinutes: [Int] = []
        for point in trendData {
            allMinutes.append(minutesSinceMidnight(from: point.bedtime))
            allMinutes.append(minutesSinceMidnight(from: point.wakeTime))
            let goals = goalTimes(for: point.date)
            allMinutes.append(minutesSinceMidnight(from: goals.bedtime))
            allMinutes.append(minutesSinceMidnight(from: goals.wakeTime))
        }
        
        // Round to nearest hour for padding
        let minMinutes = (allMinutes.min() ?? 0) / 60 * 60 - 60 // Round down and subtract an hour
        let maxMinutes = ((allMinutes.max() ?? (24 * 60)) + 59) / 60 * 60 + 60 // Round up and add an hour
        
        return minMinutes...maxMinutes
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Just the day name abbreviation
        return formatter
    }()
    
    private var displayedDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        }.reversed()
    }
    
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
                            let bedtimeMinutes = minutesSinceMidnight(from: point.bedtime)
                            let wakeTimeMinutes = minutesSinceMidnight(from: point.wakeTime)
                            let goals = goalTimes(for: point.date)
                            let goalBedMinutes = minutesSinceMidnight(from: goals.bedtime)
                            let goalWakeMinutes = minutesSinceMidnight(from: goals.wakeTime)
                            
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
                            
                            // Goal bedtime point
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Time", goalBedMinutes)
                            )
                            .foregroundStyle(.green.opacity(0.5))
                            .symbolSize(50)
                            .symbol(.circle)
                            
                            // Goal wake time point
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Time", goalWakeMinutes)
                            )
                            .foregroundStyle(.green.opacity(0.5))
                            .symbolSize(50)
                            .symbol(.circle)
                        }
                    }
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
                    .chartYAxis {
                        AxisMarks(values: .stride(by: 120)) { value in // 120 minutes = 2 hours
                            if let minutes = value.as(Int.self) {
                                let displayMinutes = minutes % (24 * 60)
                                let date = Calendar.current.date(
                                    bySettingHour: displayMinutes / 60,
                                    minute: displayMinutes % 60,
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
                    .frame(height: 300)
                    .padding(.horizontal)
                    
                    // Legend
                    HStack(spacing: 20) {
                        HStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            Text("Actual Sleep")
                                .font(.caption)
                        }
                        
                        HStack {
                            Circle()
                                .fill(.green.opacity(0.5))
                                .frame(width: 8, height: 8)
                            Text("Goal Times")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    
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
                                    Text(timeFormatter.string(from: lastNight.bedtime))
                                        .font(.body)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("Wake Time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(timeFormatter.string(from: lastNight.wakeTime))
                                        .font(.body)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}
