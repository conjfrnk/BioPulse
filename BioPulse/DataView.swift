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
    @State private var stepsData: [Date: Double] = [:]
    @State private var sleepData: [SleepRecord]?
    @State private var isLoadingSleep = false
    @State private var isLoadingSteps = false
    @State private var selectedDate: Date
    @State private var startDate: Date
    @State private var totalSleepDebt: TimeInterval = 0
    @State private var dailyDebtDelta: [Date: Double] = [:]

    init(date: Date = Date()) {
        _selectedDate = State(initialValue: date)
        let calendar = Calendar.current
        let startOfWeek = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: date))!
        _startDate = State(initialValue: startOfWeek)
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading) {
                            if isLoadingSleep {
                                ProgressView()
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
                                    Text(
                                        "Sleep Debt: \(formatTimeInterval(totalSleepDebt))"
                                    )
                                    .font(.subheadline)
                                    .foregroundColor(
                                        totalSleepDebt > 0 ? .red : .green)
                                    Spacer()
                                }
                                .padding(.top, 2)

                                SleepDebtView(dailyDebt: dailyDebtDelta)
                                    .padding(.top, 8)

                            } else {
                                Text("No sleep data available")
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
        loadStepsData()
        loadSleepDataAndDebt()
    }

    @MainActor
    private func refreshData() async {
        loadAllData()
    }

    private func loadStepsData() {
        guard !isLoadingSteps else {
            return
        }
        isLoadingSteps = true
        healthDataManager.fetchWeeklySteps(from: startDate) { data, error in
            if let data = data {
                stepsData = data
            }
            isLoadingSteps = false
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
                    sleepData = recs.sorted { $0.startDate < $1.startDate }
                }
                healthDataManager.fetchNightsOverLastNDays(
                    30,
                    sleepGoalMinutes: UserDefaults.standard.integer(
                        forKey: "sleepGoal")
                ) { fetched in
                    let result = build30dayRolling14Debt(fetched)
                    dailyDebtDelta = result.rolling
                    totalSleepDebt = result.current
                    isLoadingSleep = false
                }
            }
        }
    }

    private func build30dayRolling14Debt(
        _ nights: [HealthDataManager.NightData]
    )
        -> (rolling: [Date: Double], current: TimeInterval)
    {
        let goalSec =
            Double(UserDefaults.standard.integer(forKey: "sleepGoal")) * 60.0
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

    private func formatTimeInterval(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        if t < 0 {
            return String(format: "-%dh %02dm", abs(h), abs(m))
        } else {
            return String(format: "%dh %02dm", h, m)
        }
    }

    private func loadPreviousWeek() {
        startDate = Calendar.current.date(
            byAdding: .day, value: -7, to: startDate)!
        loadStepsData()
    }

    private func loadNextWeek() {
        startDate = Calendar.current.date(
            byAdding: .day, value: 7, to: startDate)!
        loadStepsData()
    }
}
