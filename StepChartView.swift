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
            Text("Weekly Steps (\(formattedDateRange))")
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
                .disabled(isNextWeekButtonDisabled)
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

    // Computed property for the date range
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let start = formatter.string(from: startDate)
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }

    // Computed property to determine if "Next Week" button should be disabled
    private var isNextWeekButtonDisabled: Bool {
        let calendar = Calendar.current
        let startOfCurrentWeek = calendar.startOfWeek(for: Date())
        return startDate >= startOfCurrentWeek
    }
}

// Extension to add startOfWeek function to Calendar
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }
}
