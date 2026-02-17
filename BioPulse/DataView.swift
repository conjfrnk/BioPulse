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
    @StateObject private var healthDataManager = HealthDataManager()
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

    private var sleepGoalMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "sleepGoal")
        return val > 0 ? val : 480
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading) {
                            if isLoadingSleep {
                                VStack(spacing: 12) {
                                    ProgressView("Loading sleep data...")
                                }
                                .frame(maxWidth: .infinity, maxHeight: 200)
                            } else if let sleepData = sleepData,
                                !sleepData.isEmpty
                            {
                                SleepStagesChartView(
                                    sleepData: sleepData.map {
                                        ($0.stage, $0.startDate, $0.endDate)
                                    }
                                )
                                .id(sleepData.hashValue)

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
                                .padding(.top, 2)

                                SleepDebtView(dailyDebt: dailyDebtDelta)
                                    .padding(.top, 8)

                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "bed.double")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("No sleep data available yet. Wear your Apple Watch to bed and ensure HealthKit permissions are granted in Settings.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(
                                    maxWidth: .infinity, alignment: .center
                                )
                                .padding()
                            }
                        }
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
            healthDataManager.fetchSleepData(for: Date()) { data, error in
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
        healthDataManager.fetchSleepData(for: Date()) { data, error in
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
