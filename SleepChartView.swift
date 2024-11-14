//
//  SleepChartView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI
import Charts

struct SleepStagesChartView: View {
    var sleepData: [(stage: String, startDate: Date, endDate: Date)]
    
    // Calculate the formatted sleep interval text (start and end times) based on the filtered data
    private var sleepIntervalText: String {
        let nightSleepData = sleepDataAfter2PMPreviousDay()
        
        guard let start = nightSleepData.first?.startDate, let end = nightSleepData.last?.endDate else {
            return "Last Night's Sleep"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        
        return "Last Night's Sleep (\(startText) - \(endText))"
    }
    
    // Calculate total sleep duration for the legend
    private var totalSleepTime: TimeInterval {
        sleepDataAfter2PMPreviousDay().reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }
    
    // Calculate duration and percentage for each sleep stage
    private var sleepStageInfo: [(stage: String, color: Color, duration: String, percentage: String)] {
        let filteredData = sleepDataAfter2PMPreviousDay()
        
        return ["Awake", "REM", "Core", "Deep"].map { stage in
            let duration = filteredData
                .filter { $0.stage == stage }
                .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let percentage = totalSleepTime > 0 ? (duration / totalSleepTime) * 100 : 0
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let formattedDuration = String(format: "%02dh %02dm", hours, minutes)
            let formattedPercentage = String(format: "%.1f%%", percentage)
            
            let color: Color
            switch stage {
            case "Awake": color = .red
            case "REM": color = .blue.opacity(0.5)
            case "Core": color = .blue
            case "Deep": color = .purple
            default: color = .gray
            }
            
            return (stage, color, formattedDuration, formattedPercentage)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Title with sleep interval
            Text(sleepIntervalText)
                .font(.headline)
                .padding(.top)
                .padding(.horizontal)
            
            Chart {
                ForEach(sleepDataAfter2PMPreviousDay(), id: \.startDate) { data in
                    RectangleMark(
                        xStart: .value("Start Time", data.startDate),
                        xEnd: .value("End Time", data.endDate),
                        y: .value("Stage", data.stage)
                    )
                    .foregroundStyle(
                        data.stage == "Awake" ? .red :
                            data.stage == "REM" ? .blue.opacity(0.5) :
                            data.stage == "Core" ? .blue :
                            data.stage == "Deep" ? .purple : .gray
                    )
                }
            }
            .chartXScale(domain: sleepXAxisDomain) // Set the x-axis domain for sleep chart
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                }
            }
            .chartYAxis {
                AxisMarks(values: ["Awake", "REM", "Core", "Deep"]) // Explicitly set y-axis order
            }
            .chartYScale(domain: ["Awake", "REM", "Core", "Deep"]) // Define the y-axis scale in the specified order
            .frame(height: 200)
            .padding(.horizontal)
            
            // Custom legend with equal spacing across the screen
            HStack {
                ForEach(sleepStageInfo, id: \.stage) { info in
                    VStack(alignment: .center, spacing: 4) {
                        // Colored line for each stage
                        RoundedRectangle(cornerRadius: 4)
                            .fill(info.color)
                            .frame(width: 40, height: 4) // Thin colored line with rounded corners
                        
                        // Stage info text formatted as "Stage (XX%) \n HH MM"
                        Text("\(info.stage) (\(info.percentage))\n\(info.duration)")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity) // Distribute each item evenly across the row
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    // Filter sleep data to only include entries starting from 2 PM the previous day
    private func sleepDataAfter2PMPreviousDay() -> [(stage: String, startDate: Date, endDate: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previousDay2PM = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today.addingTimeInterval(-86400))!
        
        return sleepData.filter { $0.startDate >= previousDay2PM }
    }
    
    // Calculate the x-axis domain for the sleep chart by rounding down the start and rounding up the end
    private var sleepXAxisDomain: ClosedRange<Date> {
        let nightSleepData = sleepDataAfter2PMPreviousDay()
        
        guard let start = nightSleepData.first?.startDate, let end = nightSleepData.last?.endDate else {
            // If no data is available, return a default range for the past 24 hours
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let endOfDay = Calendar.current.date(byAdding: .hour, value: 24, to: startOfDay)!
            return startOfDay...endOfDay
        }
        
        // Round the start time down to the previous hour
        let roundedStart = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: start), minute: 0, second: 0, of: start) ?? start
        
        // Round the end time up to the next hour
        var roundedEnd = Calendar.current.date(bySetting: .minute, value: 0, of: end) ?? end
        if roundedEnd < end {
            roundedEnd = Calendar.current.date(byAdding: .hour, value: 1, to: roundedEnd) ?? end
        }
        
        return roundedStart...roundedEnd
    }
}
