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
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Last Night's Sleep Stages")
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
                    .foregroundStyle(by: .value("Stage", data.stage))
                }
            }
            .chartXScale(domain: xAxisDomain)
            .chartYAxis {
                AxisMarks(values: ["Awake", "REM", "Core", "Deep"]) // Explicitly set y-axis order
            }
            .chartYScale(domain: ["Awake", "REM", "Core", "Deep"]) // Define the y-axis scale in the specified order
            .chartForegroundStyleScale([
                "Awake": .red,
                "REM": .blue.opacity(0.5),
                "Core": .blue,
                "Deep": .purple
            ])
            .frame(height: 200)
            .padding(.horizontal)
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
