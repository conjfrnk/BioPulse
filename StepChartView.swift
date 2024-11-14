//
//  StepChartView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI
import Charts

struct StepsChartView: View {
    @Binding var stepsData: [Date: Double]
    @Binding var startDate: Date
    var loadPreviousWeek: () -> Void
    var loadNextWeek: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Weekly Steps")
                .font(.headline)
                .padding(.top)
                .padding(.horizontal)
            
            Chart {
                ForEach(stepsData.keys.sorted(), id: \.self) { date in
                    BarMark(
                        x: .value("Day", dayLabel(for: date)),
                        y: .value("Steps", stepsData[date] ?? 0)
                    )
                }
            }
            .chartYScale(domain: 0...(stepsData.values.max() ?? 10000))
            .frame(height: 200)
            .padding(.horizontal)
            
            HStack {
                Button(action: loadPreviousWeek) {
                    Text("Previous Week")
                }
                Spacer()
                Button(action: loadNextWeek) {
                    Text("Next Week")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    // Helper function to format the day label (S, M, T, W, etc.)
    private func dayLabel(for date: Date) -> String {
        let daySymbols = Calendar.current.shortWeekdaySymbols
        let weekdayIndex = Calendar.current.component(.weekday, from: date) - 1
        return daySymbols[weekdayIndex]
    }
}
