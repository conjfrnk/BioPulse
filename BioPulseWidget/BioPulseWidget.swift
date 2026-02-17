//
//  BioPulseWidget.swift
//  BioPulseWidget
//
//  Created by Connor Frank on 2/16/26.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct BioPulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> BioPulseEntry {
        BioPulseEntry(
            date: Date(),
            recoveryScore: 75,
            recoveryLabel: "Ready",
            sleepDebtHours: 1.5,
            optimalBedtime: "22:30",
            lastHRV: 45,
            lastRHR: 58,
            lastSleepDuration: 7.5 * 3600
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BioPulseEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BioPulseEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> BioPulseEntry {
        let defaults = UserDefaults(suiteName: "group.com.conjfrnk.BioPulse") ?? .standard
        return BioPulseEntry(
            date: Date(),
            recoveryScore: defaults.integer(forKey: "widget_recoveryScore"),
            recoveryLabel: defaults.string(forKey: "widget_recoveryLabel") ?? "—",
            sleepDebtHours: defaults.double(forKey: "widget_sleepDebtHours"),
            optimalBedtime: defaults.string(forKey: "widget_optimalBedtime"),
            lastHRV: defaults.double(forKey: "widget_lastHRV"),
            lastRHR: defaults.double(forKey: "widget_lastRHR"),
            lastSleepDuration: defaults.double(forKey: "widget_lastSleepDuration")
        )
    }
}

// MARK: - Timeline Entry

struct BioPulseEntry: TimelineEntry {
    let date: Date
    let recoveryScore: Int
    let recoveryLabel: String
    let sleepDebtHours: Double
    let optimalBedtime: String?
    let lastHRV: Double
    let lastRHR: Double
    let lastSleepDuration: TimeInterval
}

// MARK: - Recovery Widget

struct RecoveryWidgetView: View {
    var entry: BioPulseEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallRecoveryView
        case .systemMedium:
            mediumRecoveryView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            smallRecoveryView
        }
    }

    private var smallRecoveryView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.recoveryScore) / 100.0)
                    .stroke(recoveryColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text("\(entry.recoveryScore)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Text(entry.recoveryLabel)
                .font(.caption)
                .foregroundColor(recoveryColor)
            Text("Recovery")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumRecoveryView: some View {
        HStack(spacing: 16) {
            // Recovery score
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: CGFloat(entry.recoveryScore) / 100.0)
                        .stroke(recoveryColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    Text("\(entry.recoveryScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                Text(entry.recoveryLabel)
                    .font(.caption2)
                    .foregroundColor(recoveryColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("HRV: \(Int(entry.lastHRV)) ms")
                        .font(.caption)
                }
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("RHR: \(Int(entry.lastRHR)) bpm")
                        .font(.caption)
                }
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption)
                        .foregroundColor(.indigo)
                    Text("Debt: \(String(format: "%.1f", entry.sleepDebtHours))h")
                        .font(.caption)
                }
                if let bedtime = entry.optimalBedtime {
                    HStack {
                        Image(systemName: "bed.double.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Bedtime: \(bedtime)")
                            .font(.caption)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Text("\(entry.recoveryScore)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("REC")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Recovery: \(entry.recoveryScore)")
                    .font(.headline)
                Spacer()
                Text(entry.recoveryLabel)
                    .font(.caption)
            }
            HStack {
                Text("HRV \(Int(entry.lastHRV))ms")
                    .font(.caption)
                Text("•")
                Text("RHR \(Int(entry.lastRHR))")
                    .font(.caption)
                Text("•")
                Text("Debt \(String(format: "%.1f", entry.sleepDebtHours))h")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
    }

    private var inlineView: some View {
        Text("Recovery \(entry.recoveryScore) • \(entry.recoveryLabel)")
    }

    private var recoveryColor: Color {
        if entry.recoveryScore >= 67 { return .green }
        if entry.recoveryScore >= 34 { return .yellow }
        return .red
    }
}

// MARK: - Widget Configuration

struct RecoveryWidget: Widget {
    let kind = "RecoveryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BioPulseProvider()) { entry in
            RecoveryWidgetView(entry: entry)
        }
        .configurationDisplayName("Recovery Score")
        .description("Your current recovery readiness score.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Widget Bundle

@main
struct BioPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecoveryWidget()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    RecoveryWidget()
} timeline: {
    BioPulseEntry(
        date: Date(),
        recoveryScore: 82,
        recoveryLabel: "Ready",
        sleepDebtHours: 1.2,
        optimalBedtime: "22:30",
        lastHRV: 48,
        lastRHR: 56,
        lastSleepDuration: 7.5 * 3600
    )
}
