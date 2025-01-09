//
//  ExpandedNightView.swift
//  BioPulse
//
//  Created by Connor Frank on 1/9/25.
//

import SwiftUI

struct ExpandedNightView: View {
    let nightData: HealthDataManager.NightData
    let onDismiss: () -> Void

    init(
        nightData: HealthDataManager.NightData,
        onDismiss: @escaping () -> Void
    ) {
        self.nightData = nightData
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
        let avgBedtime = UserDefaults.standard.double(
            forKey: "avgBedtimeOffset")
        let c = abs(midSleepOffset() - avgBedtime) / 3600
        return String(format: "%.1f hrs off average", c)
    }

    private func midSleepOffset() -> Double {
        let half =
            nightData.sleepStartTime.timeIntervalSinceReferenceDate
            + (nightData.sleepEndTime.timeIntervalSinceReferenceDate
                - nightData.sleepStartTime.timeIntervalSinceReferenceDate) / 2
        return half
    }

    private func flaggedIssues() -> String? {
        var msgs: [String] = []
        let diff =
            UserDefaults.standard.integer(forKey: "sleepGoal") * 60
            - Int(nightData.sleepDuration)
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
