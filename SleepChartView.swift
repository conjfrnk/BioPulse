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
    
    // Calculate the formatted sleep interval text (start and end times)
    private var sleepIntervalText: String {
        let nonAwakeData = sleepData.filter { $0.stage != "Awake" }.sorted { $0.startDate < $1.startDate }
        
        guard let start = nonAwakeData.first?.startDate, let end = nonAwakeData.last?.endDate else {
            return "Last Night's Sleep"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        
        return "Last Night's Sleep (\(startText) - \(endText))"
    }
    
    // Calculate total sleep duration
    private var totalSleepTime: TimeInterval {
        sleepData.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }
    
    // Calculate duration and percentage for each sleep stage
    private var sleepStageInfo: [(stage: String, color: Color, duration: String, percentage: String)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return ["Awake", "REM", "Core", "Deep"].map { stage in
            let duration = sleepData
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
                ForEach(sleepData, id: \.startDate) { data in
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
            .chartXScale(domain: xAxisDomain)
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
    
    // Calculate the x-axis domain based on sleep data intervals
    private var xAxisDomain: ClosedRange<Date> {
        let start = sleepData.map(\.startDate).min()?.roundedHourDown() ?? Date()
        let end = sleepData.map(\.endDate).max()?.roundedHourUp() ?? Date()
        return start...end
    }
}

extension Date {
    // Rounds down to the previous hour
    func roundedHourDown() -> Date {
        Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: self), minute: 0, second: 0, of: self)!
    }
    
    // Rounds up to the next hour
    func roundedHourUp() -> Date {
        Calendar.current.date(byAdding: .hour, value: 1, to: self.roundedHourDown())!
    }
}
