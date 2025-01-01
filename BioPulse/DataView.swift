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

    // Sleep debt for the last 7 days:
    @State private var totalSleepDebt: TimeInterval = 0
    // A dictionary of daily deltas: negative means user slept over goal that day
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

                        // Steps
                        VStack(alignment: .leading) {
                            if isLoadingSteps {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            } else {
                                StepsChartView(
                                    stepsData: $stepsData,
                                    startDate: $startDate,
                                    loadPreviousWeek: loadPreviousWeek,
                                    loadNextWeek: loadNextWeek
                                )
                            }
                        }

                        Divider()

                        // Sleep
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

                                // Show total debt:
                                Text(
                                    "Sleep Debt: \(formatTimeInterval(totalSleepDebt))"
                                )
                                .font(.subheadline)
                                .foregroundColor(
                                    totalSleepDebt > 0 ? .red : .green
                                )
                                .padding(.top, 2)

                                // Show line chart for last 7 days:
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
                print("[DATA] View appeared")
                loadAllData()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    print("[DATA] Scene became active")
                    loadAllData()
                }
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    print("[DATA] Settings sheet dismissed")
                    loadAllData()
                }
            }
            .refreshable {
                print("[DATA] Manual refresh triggered")
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
            print("[STEPS] Already loading steps data")
            return
        }
        print("[STEPS] Loading steps data for week starting \(startDate)")
        isLoadingSteps = true
        healthDataManager.fetchWeeklySteps(from: startDate) { data, error in
            if let error = error {
                print(
                    "[STEPS] Error loading steps data: \(error.localizedDescription)"
                )
            }
            DispatchQueue.main.async {
                if let data = data {
                    print("[STEPS] Loaded \(data.count) days of step data")
                    stepsData = data
                }
                isLoadingSteps = false
            }
        }
    }

    /**
     Load "last night" sleep plus nights for the last 7 days to compute
     total debt + daily delta (positive or negative).
     */
    private func loadSleepDataAndDebt() {
        guard !isLoadingSleep else {
            print("[SLEEP] Already loading sleep data")
            return
        }
        print("[SLEEP] Loading sleep data + 7-day debt")
        isLoadingSleep = true
        sleepData = nil

        let today = Date()
        healthDataManager.fetchSleepData(for: today) { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print(
                        "[SLEEP] Error loading sleep data: \(error.localizedDescription)"
                    )
                }
                if let data = data {
                    print(
                        "[SLEEP] Loaded \(data.count) sleep records for last night"
                    )
                    let records = data.map {
                        SleepRecord(
                            stage: $0.stage,
                            startDate: $0.startDate,
                            endDate: $0.endDate)
                    }
                    sleepData = records.sorted { $0.startDate < $1.startDate }
                }
                // Now fetch 7 nights to compute debt
                healthDataManager.fetchNightsOverLastNDays(
                    7,
                    sleepGoalMinutes: UserDefaults.standard.integer(
                        forKey: "sleepGoal")
                ) { fetched in
                    let result = calculate7DayDebtDelta(fetched)
                    totalSleepDebt = result.total
                    dailyDebtDelta = result.daily
                    isLoadingSleep = false
                }
            }
        }
    }

    /**
     For each of the last 7 nights, compute difference: (goalSec - actualSlept).
       - If negative => user slept more than goal => reduces debt
       - If positive => user slept less => increases debt
     We accumulate total and store each day's difference in dailyDebtDelta.
     */
    private func calculate7DayDebtDelta(_ nights: [HealthDataManager.NightData])
        -> (total: TimeInterval, daily: [Date: Double])
    {
        let goalSec =
            Double(UserDefaults.standard.integer(forKey: "sleepGoal")) * 60.0
        var daily: [Date: Double] = [:]  // day -> delta

        // Sort by date ascending so we can keep dayKey consistent
        let sorted = nights.sorted { $0.date < $1.date }
        for n in sorted {
            let dayKey = Calendar.current.startOfDay(for: n.date)
            let diff = (goalSec - n.sleepDuration)  // could be negative if overslept
            daily[dayKey] = (daily[dayKey] ?? 0) + diff
        }
        // Now compute total by summing the daily values
        // but as a final "net" number
        let total = daily.values.reduce(0, +)
        return (total, daily)
    }

    private func formatTimeInterval(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        // If t is negative, user is in "surplus" (which might be rare).
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
