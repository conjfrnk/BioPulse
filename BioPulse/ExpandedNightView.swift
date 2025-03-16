//
//  ExpandedNightView.swift
//  BioPulse
//
//  Created by Connor Frank on 1/9/25.
//

import SwiftUI

struct ExpandedNightView: View {
    let nightData: HealthDataManager.NightData
    let last30Nights: [HealthDataManager.NightData]?
    let onDismiss: () -> Void

    init(nightData: HealthDataManager.NightData, last30Nights: [HealthDataManager.NightData]? = nil, onDismiss: @escaping () -> Void) {
        self.nightData = nightData
        self.last30Nights = last30Nights
        self.onDismiss = onDismiss
    }

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(spacing: 16) {
            Text(dateFormatter.string(from: nightData.date))
                .font(.title3)
            Text("Sleep Duration: \(formatDuration(nightData.sleepDuration))")
            Text("Sleep Consistency Deviation: \(consistencyString())")
            if nightData.restingHeartRate > 0 {
                Text("RHR: \(Int(nightData.restingHeartRate)) bpm")
            }
            if nightData.hrv > 0 {
                Text("HRV: \(Int(nightData.hrv)) ms")
            }
            if let flags = flaggedIssues() {
                Text(flags)
                    .foregroundColor(.red)
            }
            Button("Close") {
                onDismiss()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .frame(maxWidth: 320)
        .shadow(radius: 10)
    }

    private func formatDuration(_ dur: TimeInterval) -> String {
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func consistencyString() -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let avgBedtimeSeconds: Double
        if let nights = last30Nights, !nights.isEmpty {
            // Calculate the average sleep start time (in seconds since midnight)
            let total = nights.reduce(0.0) { sum, night in
                let comps = calendar.dateComponents([.hour, .minute], from: night.sleepStartTime)
                let seconds = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
                return sum + seconds
            }
            avgBedtimeSeconds = total / Double(nights.count)
        } else {
            let comps = calendar.dateComponents([.hour, .minute], from: nightData.sleepStartTime)
            let seconds = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
            avgBedtimeSeconds = seconds
        }
        let avgBedtimeDate = today.addingTimeInterval(avgBedtimeSeconds)
        // Use the current night's sleep start time (bedtime) in seconds since midnight
        let compsCurrent = calendar.dateComponents([.hour, .minute], from: nightData.sleepStartTime)
        let currentBedtimeSeconds = Double((compsCurrent.hour ?? 0) * 3600 + (compsCurrent.minute ?? 0) * 60)
        let deviationSec = abs(currentBedtimeSeconds - avgBedtimeSeconds)
        let devHours = Int(deviationSec) / 3600
        let devMinutes = (Int(deviationSec) % 3600) / 60
        let deviationStr = String(format: "%02dh %02dm", devHours, devMinutes)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Deviation: \(deviationStr) off average (average: \(formatter.string(from: avgBedtimeDate)))"
    }

    private func midSleepOffset() -> Double {
        let half = nightData.sleepStartTime.timeIntervalSinceReferenceDate + (nightData.sleepEndTime.timeIntervalSinceReferenceDate - nightData.sleepStartTime.timeIntervalSinceReferenceDate) / 2
        return half.truncatingRemainder(dividingBy: 86400)
    }

    private func flaggedIssues() -> String? {
        var msgs: [String] = []
        let diff = UserDefaults.standard.integer(forKey: "sleepGoal") * 60 - Int(nightData.sleepDuration)
        if diff > 3600 {
            msgs.append("Significant sleep debt")
        }
        if nightData.restingHeartRate > 100 {
            msgs.append("Elevated RHR")
        }
        if nightData.hrv < 30 {
            msgs.append("Low HRV")
        }
        return msgs.isEmpty ? nil : msgs.joined(separator: ", ")
    }
}
