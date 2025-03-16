//
//  SleepChartView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI
import Charts

struct SleepStagesChartView: View, Equatable {
    let sleepData: [(stage: String, startDate: Date, endDate: Date)]

    static func == (lhs: SleepStagesChartView, rhs: SleepStagesChartView) -> Bool {
        // Compare sleep data entries
        guard lhs.sleepData.count == rhs.sleepData.count else { return false }

        return zip(lhs.sleepData, rhs.sleepData).allSatisfy { lhsEntry, rhsEntry in
            lhsEntry.stage == rhsEntry.stage &&
            lhsEntry.startDate == rhsEntry.startDate &&
            lhsEntry.endDate == rhsEntry.endDate
        }
    }

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

    // Calculate actual sleep time (excluding Awake and InBed)
    private var totalSleepTime: TimeInterval {
        sleepDataAfter2PMPreviousDay()
            .filter { $0.stage != "Awake" && $0.stage != "InBed" }
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }

    // Calculate total time in bed (including all stages)
    private var totalTimeInBed: TimeInterval {
        sleepDataAfter2PMPreviousDay()
            .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }

    // Calculate duration and percentage for each sleep stage
    private var sleepStageInfo: [(stage: String, color: Color, duration: String, percentage: String)] {
        let filteredData = sleepDataAfter2PMPreviousDay()

        return ["Awake", "REM", "Core", "Deep"].map { stage in
            let duration = filteredData
                .filter { $0.stage == stage }
                .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

            // Calculate percentage based on appropriate total
            let percentage: Double
            if stage == "Awake" {
                // Calculate wake time as percentage of total time in bed
                percentage = totalTimeInBed > 0 ? (duration / totalTimeInBed) * 100 : 0
            } else {
                // Calculate sleep stages as percentage of actual sleep time
                percentage = totalSleepTime > 0 ? (duration / totalSleepTime) * 100 : 0
            }

            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let formattedDuration = String(format: "%dh %02dm", hours, minutes)
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
            .chartXScale(domain: sleepXAxisDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) {
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                }
            }
            .chartYAxis {
                AxisMarks(values: ["Awake", "REM", "Core", "Deep"])
            }
            .chartYScale(domain: ["Awake", "REM", "Core", "Deep"])
            .frame(height: 200)
            .padding(.horizontal)

            // Add total sleep duration
            Text("Total Sleep: \(formatDuration(totalSleepTime))")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Custom legend with equal spacing across the screen
            HStack {
                ForEach(sleepStageInfo, id: \.stage) { info in
                    VStack(alignment: .center, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(info.color)
                            .frame(width: 40, height: 4)

                        Text("\(info.stage) (\(info.percentage))\n\(info.duration)")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    // Filter sleep data to only include entries starting from 6 PM the previous day
    private func sleepDataAfter2PMPreviousDay() -> [(stage: String, startDate: Date, endDate: Date)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let previousDay2PM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today.addingTimeInterval(-86400))!

        return sleepData.filter { $0.startDate >= previousDay2PM }
    }

    private var sleepXAxisDomain: ClosedRange<Date> {
        let nightSleepData = sleepDataAfter2PMPreviousDay()

        guard let start = nightSleepData.first?.startDate, let end = nightSleepData.last?.endDate else {
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let endOfDay = Calendar.current.date(byAdding: .hour, value: 24, to: startOfDay)!
            return startOfDay...endOfDay
        }

        let roundedStart = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: start), minute: 0, second: 0, of: start) ?? start

        var roundedEnd = Calendar.current.date(bySetting: .minute, value: 0, of: end) ?? end
        if roundedEnd < end {
            roundedEnd = Calendar.current.date(byAdding: .hour, value: 1, to: roundedEnd) ?? end
        }

        return roundedStart...roundedEnd
    }
}
