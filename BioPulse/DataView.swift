//
//  DataView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct SleepRecord: Hashable, Identifiable {
    let id = UUID()
    let stage: String
    let startDate: Date
    let endDate: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(stage)
        hasher.combine(startDate)
        hasher.combine(endDate)
    }

    static func == (lhs: SleepRecord, rhs: SleepRecord) -> Bool {
        lhs.id == rhs.id && lhs.stage == rhs.stage
            && lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate
    }
}

struct DataView: View {
    @EnvironmentObject var healthDataManager: HealthDataManager
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var sleepData: [SleepRecord]?
    @State private var isLoadingSleep = false
    @State private var selectedDate: Date
    @State private var totalSleepDebt: TimeInterval = 0
    @State private var dailyDebtDelta: [Date: Double] = [:]

    init(date: Date = Date()) {
        _selectedDate = State(initialValue: date)
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme

    private var sleepGoalMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "sleepGoal")
        return val > 0 ? val : 480
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate) {
            return "Today"
        } else if cal.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return SleepFormatters.fullDayDate.string(from: selectedDate)
        }
    }

    private var canGoForward: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 5)
    }

    private var sleepStageBreakdown: [(stage: String, color: Color, duration: TimeInterval, percentage: Double)] {
        guard let data = sleepData, !data.isEmpty else { return [] }
        let totalSleep = data
            .filter { $0.stage != "Awake" && $0.stage != "InBed" }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let totalInBed = data
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        return ["Deep", "Core", "REM", "Awake"].compactMap { stage in
            let duration = data
                .filter { $0.stage == stage }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            guard duration > 0 else { return nil }
            let pct: Double
            if stage == "Awake" {
                pct = totalInBed > 0 ? (duration / totalInBed) * 100 : 0
            } else {
                pct = totalSleep > 0 ? (duration / totalSleep) * 100 : 0
            }
            let color: Color = switch stage {
            case "Deep": .purple
            case "Core": .blue
            case "REM": .cyan
            case "Awake": .red
            default: .gray
            }
            return (stage, color, duration, pct)
        }
    }

    private var sleepDebtRecommendation: String {
        let debtHours = min(totalSleepDebt / 3600.0, 20.0)
        if debtHours <= 2 {
            return "You're well-rested"
        } else if debtHours <= 5 {
            return "Add ~30 min/night this week"
        } else if debtHours <= 10 {
            return "Add ~45 min/night this week"
        } else {
            return "Prioritize extra sleep; consider naps"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoadingSleep {
                    ProgressView("Loading sleep data...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let sleepData = sleepData, !sleepData.isEmpty {
                    VStack(spacing: 20) {
                        // Sleep Data card
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Sleep Data")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "bed.double.fill")
                                    .foregroundColor(.purple)
                            }

                            Divider()

                            // Date navigation
                            HStack {
                                Button {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                    loadAllData()
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                Spacer()
                                Text(dateLabel)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                    loadAllData()
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(!canGoForward)
                                .opacity(canGoForward ? 1 : 0.3)
                            }

                            SleepStagesChartView(
                                sleepData: sleepData.map {
                                    ($0.stage, $0.startDate, $0.endDate)
                                }
                            )
                            .id(sleepData.hashValue)

                            // Sleep stage summary
                            if !sleepStageBreakdown.isEmpty {
                                HStack(spacing: 0) {
                                    ForEach(sleepStageBreakdown, id: \.stage) { info in
                                        VStack(spacing: 2) {
                                            Circle()
                                                .fill(info.color)
                                                .frame(width: 8, height: 8)
                                            Text(info.stage)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            Text(SleepFormatters.formatDuration(info.duration))
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                            Text(String(format: "%.0f%%", info.percentage))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(cardBackground)

                        // Sleep Debt card
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Sleep Debt")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "moon.zzz.fill")
                                    .foregroundColor(.indigo)
                            }

                            Divider()

                            HStack {
                                Spacer()
                                let debtHours = totalSleepDebt / 3600.0
                                let cappedDebt = min(totalSleepDebt, 20.0 * 3600.0)
                                let isCapped = debtHours > 20.0
                                Text(
                                    "Sleep Debt: \(formatTimeInterval(cappedDebt))\(isCapped ? " (max)" : "")"
                                )
                                .font(.subheadline)
                                .foregroundColor(sleepDebtColor(hours: min(debtHours, 20.0)))
                                Spacer()
                            }

                            HStack {
                                Spacer()
                                Text(sleepDebtRecommendation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            SleepDebtView(dailyDebt: dailyDebtDelta)
                                .padding(.top, 8)
                        }
                        .padding()
                        .background(cardBackground)
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        // Date navigation card (shown even when empty)
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Sleep Data")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "bed.double.fill")
                                    .foregroundColor(.purple)
                            }

                            Divider()

                            // Date navigation
                            HStack {
                                Button {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                    loadAllData()
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                Spacer()
                                Text(dateLabel)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                    loadAllData()
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(!canGoForward)
                                .opacity(canGoForward ? 1 : 0.3)
                            }

                            VStack(spacing: 12) {
                                Image(systemName: "bed.double")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No sleep data available yet. Wear your Apple Watch to bed and ensure HealthKit permissions are granted in Settings.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                        }
                        .padding()
                        .background(cardBackground)
                    }
                    .padding()
                }
            }
            .navigationTitle("Data")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
            .onAppear {
                loadAllData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    loadAllData()
                }
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    loadAllData()
                }
            }
            .refreshable {
                await refreshData()
            }
        }
    }

    private func loadAllData() {
        loadSleepDataAndDebt()
    }

    @MainActor
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            isLoadingSleep = true
            sleepData = nil
            healthDataManager.fetchSleepData(for: selectedDate) { data, error in
                DispatchQueue.main.async {
                    if let data = data {
                        let recs = data.map {
                            SleepRecord(
                                stage: $0.stage, startDate: $0.startDate,
                                endDate: $0.endDate)
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.sleepData = recs.sorted { $0.startDate < $1.startDate }
                        }
                    }
                    self.healthDataManager.fetchNightsOverLastNDays(
                        30,
                        sleepGoalMinutes: self.sleepGoalMinutes
                    ) { fetched in
                        let result = self.build30dayRolling14Debt(fetched)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.dailyDebtDelta = result.rolling
                            self.totalSleepDebt = result.current
                            self.isLoadingSleep = false
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func loadSleepDataAndDebt() {
        guard !isLoadingSleep else {
            return
        }
        isLoadingSleep = true
        sleepData = nil
        healthDataManager.fetchSleepData(for: selectedDate) { data, error in
            DispatchQueue.main.async {
                if let data = data {
                    let recs = data.map {
                        SleepRecord(
                            stage: $0.stage, startDate: $0.startDate,
                            endDate: $0.endDate)
                    }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        sleepData = recs.sorted { $0.startDate < $1.startDate }
                    }
                }
                healthDataManager.fetchNightsOverLastNDays(
                    30,
                    sleepGoalMinutes: sleepGoalMinutes
                ) { fetched in
                    let result = build30dayRolling14Debt(fetched)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        dailyDebtDelta = result.rolling
                        totalSleepDebt = result.current
                        isLoadingSleep = false
                    }
                }
            }
        }
    }

    private func build30dayRolling14Debt(
        _ nights: [HealthDataManager.NightData]
    )
        -> (rolling: [Date: Double], current: TimeInterval)
    {
        let goalSec = Double(sleepGoalMinutes) * 60.0
        let sorted = nights.sorted { $0.date < $1.date }
        var dailyRaw: [Date: Double] = [:]
        for n in sorted {
            let dayKey = Calendar.current.startOfDay(for: n.date)
            let diff = goalSec - n.sleepDuration
            dailyRaw[dayKey] = (dailyRaw[dayKey] ?? 0) + diff
        }
        let allDays = dailyRaw.keys.sorted()
        var rolling14: [Date: Double] = [:]
        for day in allDays {
            guard
                let earliest = Calendar.current.date(
                    byAdding: .day, value: -13, to: day)
            else { continue }
            var sum14: Double = 0
            for d in allDays {
                if d >= earliest && d <= day {
                    sum14 += (dailyRaw[d] ?? 0)
                }
            }
            rolling14[day] = max(0, sum14)
        }
        if let latest = allDays.last {
            let curr = rolling14[latest] ?? 0
            return (rolling14, curr)
        } else {
            return ([:], 0)
        }
    }

    private func sleepDebtColor(hours: Double) -> Color {
        if hours <= 0 {
            return .green
        } else if hours <= 2 {
            return .green
        } else if hours <= 5 {
            return .yellow
        } else if hours <= 10 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatTimeInterval(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        if t < 0 {
            return String(format: "-%dh %02dm", abs(h), abs(m))
        } else {
            return String(format: "%dh %02dm", h, m)
        }
    }

}
