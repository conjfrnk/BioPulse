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

    // The total sleep debt at this moment (rolling 14-day).
    @State private var totalSleepDebt: TimeInterval = 0
    // A dictionary mapping each of the last 30 days -> rolling 14-day debt
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
                                // Show last night's sleep chart
                                SleepStagesChartView(
                                    sleepData: sleepData.map {
                                        ($0.stage, $0.startDate, $0.endDate)
                                    }
                                )
                                .id(sleepData.hashValue)

                                // Center the Sleep Debt text
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

                                // 30-day chart, each day is a rolling 14-day sum
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
            .onChange(of: scenePhase) { _, newPhase in
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
     Load last night's sleep + the last 30 nights for the rolling 14-day sum
     which we display in SleepDebtView plus a single total for "today."
     */
    private func loadSleepDataAndDebt() {
        guard !isLoadingSleep else {
            print("[SLEEP] Already loading sleep data")
            return
        }
        isLoadingSleep = true
        sleepData = nil

        // Load last night's sleep
        healthDataManager.fetchSleepData(for: Date()) { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print(
                        "[SLEEP] Error loading last night's sleep: \(error.localizedDescription)"
                    )
                }
                if let data = data {
                    let recs = data.map {
                        SleepRecord(
                            stage: $0.stage, startDate: $0.startDate,
                            endDate: $0.endDate)
                    }
                    sleepData = recs.sorted { $0.startDate < $1.startDate }
                }
                // Now load 30 nights to build rolling 14-day sums
                healthDataManager.fetchNightsOverLastNDays(
                    30,
                    sleepGoalMinutes: UserDefaults.standard.integer(
                        forKey: "sleepGoal")
                ) { fetched in
                    // Convert to a day -> rolling 14-day sum
                    let result = build30dayRolling14Debt(fetched)
                    dailyDebtDelta = result.rolling
                    totalSleepDebt = result.current
                    isLoadingSleep = false
                }
            }
        }
    }

    /**
     For each day in the last 30, sum the prior 14 nights' deficits.
     Each daily value is clamped at 0 if negative. Also we keep track of the "most recent day"
     for the user's current debt.
     */
    private func build30dayRolling14Debt(
        _ nights: [HealthDataManager.NightData]
    )
        -> (rolling: [Date: Double], current: TimeInterval)
    {
        let goalSec =
            Double(UserDefaults.standard.integer(forKey: "sleepGoal")) * 60.0
        // Sort nights by ascending date
        let sorted = nights.sorted { $0.date < $1.date }

        // Build a dictionary: day -> sum of (goalSec - actual) for that day
        var dailyRaw: [Date: Double] = [:]
        for n in sorted {
            let dayKey = Calendar.current.startOfDay(for: n.date)
            let diff = goalSec - n.sleepDuration  // can be negative if overslept
            dailyRaw[dayKey] = (dailyRaw[dayKey] ?? 0) + diff
        }

        // Now for each day in the last 30, we do a 14-day sum
        let allDays = dailyRaw.keys.sorted()
        var rolling14: [Date: Double] = [:]

        for day in allDays {
            // find the earliest day in the 14-day window
            guard
                let earliest = Calendar.current.date(
                    byAdding: .day, value: -13, to: day)
            else { continue }

            // sum dailyRaw for all days in [earliest .. day]
            var sum14: Double = 0
            for d in allDays {
                if d >= earliest && d <= day {
                    sum14 += (dailyRaw[d] ?? 0)
                }
            }
            // clamp at 0 if negative
            rolling14[day] = max(0, sum14)
        }

        // "current" = the rolling sum for the most recent day
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
            // Negative means overslept more than goal, though we clamp final to 0,
            // but let's handle if we don't clamp
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
