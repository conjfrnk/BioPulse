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

    @Environment(\.colorScheme) var colorScheme

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var sleepGoalMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "sleepGoal")
        return val > 0 ? val : 480
    }

    private var avgHRV: Double {
        guard let nights = last30Nights else { return 0 }
        let valid = nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        return valid.isEmpty ? 0 : valid.reduce(0, +) / Double(valid.count)
    }

    private var avgRHR: Double {
        guard let nights = last30Nights else { return 0 }
        let valid = nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        return valid.isEmpty ? 0 : valid.reduce(0, +) / Double(valid.count)
    }

    private var avgDuration: TimeInterval {
        guard let nights = last30Nights, !nights.isEmpty else { return 0 }
        return nights.reduce(0.0) { $0 + $1.sleepDuration } / Double(nights.count)
    }

    private var avgScore: Double {
        guard let nights = last30Nights, !nights.isEmpty else { return 0 }
        return Double(nights.reduce(0) { $0 + $1.sleepScore }) / Double(nights.count)
    }

    private var hrvPercentile: Int {
        guard let nights = last30Nights, nightData.hrv > 0 else { return 0 }
        let sorted = nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }.sorted()
        guard !sorted.isEmpty else { return 0 }
        let below = sorted.filter { $0 <= nightData.hrv }.count
        return Int(Double(below) / Double(sorted.count) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateFormatter.string(from: nightData.date))
                        .font(.title3)
                        .bold()
                    Text("\(timeFormatter.string(from: nightData.sleepStartTime)) – \(timeFormatter.string(from: nightData.sleepEndTime))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: CGFloat(nightData.sleepScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    Text("\(nightData.sleepScore)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .padding()

            Divider()

            // Duration
            HStack {
                Label {
                    Text("Duration")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.blue)
                }
                Spacer()
                Text(formatDuration(nightData.sleepDuration))
                    .font(.system(.body, design: .rounded))
                    .bold()
                let goalSec = Double(sleepGoalMinutes) * 60
                let pct = goalSec > 0 ? (nightData.sleepDuration - goalSec) / goalSec * 100 : 0
                Text(String(format: "%+.0f%%", pct))
                    .font(.caption)
                    .foregroundColor(pct >= 0 ? .green : .red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Awake time
            HStack {
                Label {
                    Text("Awake Time")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "eye.fill")
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("\(Int(nightData.totalAwakeTime / 60)) min")
                    .font(.system(.body, design: .rounded))
                    .bold()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()
                .padding(.vertical, 4)

            // Comparison Bars
            VStack(spacing: 12) {
                Text("vs 30-Night Baseline")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if nightData.hrv > 0 && avgHRV > 0 {
                    comparisonBar(
                        label: "HRV",
                        value: nightData.hrv,
                        baseline: avgHRV,
                        unit: "ms",
                        higherIsBetter: true
                    )
                }

                if nightData.restingHeartRate > 0 && avgRHR > 0 {
                    comparisonBar(
                        label: "RHR",
                        value: nightData.restingHeartRate,
                        baseline: avgRHR,
                        unit: "bpm",
                        higherIsBetter: false
                    )
                }

                if avgDuration > 0 {
                    comparisonBar(
                        label: "Duration",
                        value: nightData.sleepDuration / 3600,
                        baseline: avgDuration / 3600,
                        unit: "h",
                        higherIsBetter: true
                    )
                }

                if avgScore > 0 {
                    comparisonBar(
                        label: "Score",
                        value: Double(nightData.sleepScore),
                        baseline: avgScore,
                        unit: "",
                        higherIsBetter: true
                    )
                }
            }
            .padding(.horizontal)

            // Percentile
            if hrvPercentile > 0 {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                    Text("HRV in \(ordinal(hrvPercentile)) percentile of last 30 nights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Flags
            if let flags = flaggedIssues() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(flags)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            Divider()
                .padding(.top, 12)

            Button {
                onDismiss()
            } label: {
                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .frame(maxWidth: 340)
        .shadow(color: .black.opacity(0.2), radius: 20)
    }

    private func comparisonBar(label: String, value: Double, baseline: Double, unit: String, higherIsBetter: Bool) -> some View {
        let ratio = baseline > 0 ? value / baseline : 1.0
        let pctChange = (ratio - 1.0) * 100
        let isBetter = higherIsBetter ? value >= baseline : value <= baseline

        return HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 55, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isBetter ? Color.green : Color.red)
                        .frame(width: max(8, geo.size.width * min(ratio, 1.5) / 1.5), height: 8)

                    // Baseline marker
                    Rectangle()
                        .fill(Color.primary.opacity(0.5))
                        .frame(width: 2, height: 14)
                        .offset(x: geo.size.width / 1.5 - 1)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.0f%@", value, unit))
                .font(.caption)
                .bold()
                .frame(width: 50, alignment: .trailing)

            Text(String(format: "%+.0f%%", pctChange))
                .font(.caption2)
                .foregroundColor(isBetter ? .green : .red)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var scoreColor: Color {
        let score = nightData.sleepScore
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 { suffix = "th" }
        else if ones == 1 { suffix = "st" }
        else if ones == 2 { suffix = "nd" }
        else if ones == 3 { suffix = "rd" }
        else { suffix = "th" }
        return "\(n)\(suffix)"
    }

    private func formatDuration(_ dur: TimeInterval) -> String {
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
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
        if nightData.hrv > 0 && nightData.hrv < 30 {
            msgs.append("Low HRV")
        }
        return msgs.isEmpty ? nil : msgs.joined(separator: " • ")
    }
}
