//
//  TrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import Charts
import SwiftUI

struct HRVTrendChart: View {
    let dailyHRV: [Date: Double]
    let baseline: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("HRV (Last 30 Days)")
                .font(.headline)
                // Add consistent horizontal padding for the title
                .padding(.horizontal, 16)

            Chart {
                ForEach(dailyHRV.keys.sorted(), id: \.self) { day in
                    LineMark(
                        x: .value("Date", day),
                        y: .value("HRV", dailyHRV[day] ?? 0)
                    )
                }
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(.gray)
            }
            // Ensure consistent horizontal padding around the chart
            .padding(.horizontal, 16)
            .frame(height: 200)
            .chartXAxis {
                // Show x-axis label once a week
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(
                            format: .dateTime.month(.abbreviated).day()
                        )
                    }
                }
            }
        }
    }
}

struct RHRTrendChart: View {
    let dailyRHR: [Date: Double]
    let baseline: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Resting HR (Last 30 Days)")
                .font(.headline)
                .padding(.horizontal, 16)

            Chart {
                ForEach(dailyRHR.keys.sorted(), id: \.self) { day in
                    LineMark(
                        x: .value("Date", day),
                        y: .value("RHR", dailyRHR[day] ?? 0)
                    )
                }
                RuleMark(y: .value("Baseline", baseline))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 16)
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(
                            format: .dateTime.month(.abbreviated).day()
                        )
                    }
                }
            }
        }
    }
}

struct TrendView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var sleepData:
        [(stage: String, startDate: Date, endDate: Date)]?
    @State private var isLoadingSleep = false

    @Environment(\.scenePhase) private var scenePhase

    private var goalWakeTime: Date {
        let defaultWakeTime =
            Calendar.current.date(
                bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let timeInterval = UserDefaults.standard.double(forKey: "goalWakeTime")
        return timeInterval == 0
            ? defaultWakeTime
            : Date(timeIntervalSince1970: timeInterval)
    }
    private var goalSleepMinutes: Int {
        UserDefaults.standard.integer(forKey: "sleepGoal")
    }
    private var isGoalNotSet: Bool {
        let storedSleepGoal = UserDefaults.standard.integer(forKey: "sleepGoal")
        let storedWakeTime = UserDefaults.standard.double(
            forKey: "goalWakeTime")
        return storedSleepGoal == 0 || storedWakeTime == 0
    }

    @State private var dailyHRV: [Date: Double] = [:]
    @State private var hrvBaseline: Double = 0
    @State private var isLoadingHRV = false

    @State private var dailyRHR: [Date: Double] = [:]
    @State private var rhrBaseline: Double = 0
    @State private var isLoadingRHR = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Sleep chart (7 days)
                    if isLoadingSleep {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    } else if let sleepData = sleepData, !sleepData.isEmpty {
                        SleepTrendView(
                            sleepData: sleepData,
                            goalSleepMinutes: goalSleepMinutes,
                            goalWakeTime: goalWakeTime
                        )
                    } else {
                        Text("No sleep data available")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }

                    // HRV chart (30 days)
                    if isLoadingHRV {
                        ProgressView()
                            .frame(height: 200)
                    } else if dailyHRV.isEmpty {
                        Text("No HRV data available (last 30 days)")
                    } else {
                        HRVTrendChart(dailyHRV: dailyHRV, baseline: hrvBaseline)
                            .frame(height: 200)
                    }

                    // RHR chart (30 days)
                    if isLoadingRHR {
                        ProgressView()
                            .frame(height: 200)
                    } else if dailyRHR.isEmpty {
                        Text("No RHR data available (last 30 days)")
                    } else {
                        RHRTrendChart(dailyRHR: dailyRHR, baseline: rhrBaseline)
                            .frame(height: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingInfo = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
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
                if isGoalNotSet {
                    showingSettings = true
                } else {
                    loadSleepData()
                    loadBaselines()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    if isGoalNotSet {
                        showingSettings = true
                    } else {
                        loadSleepData()
                        loadBaselines()
                    }
                }
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    if isGoalNotSet {
                        showingSettings = true
                    } else {
                        loadSleepData()
                        loadBaselines()
                    }
                }
            }
            .refreshable {
                await refreshData()
            }
        }
    }

    // MARK: - Sleep Data (7 days)

    private func loadSleepData() {
        guard !isLoadingSleep else {
            return
        }
        isLoadingSleep = true
        sleepData = nil
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        loadSleepDataForRange(startDate: startDate, endDate: endDate) { data in
            DispatchQueue.main.async {
                self.sleepData = data
                self.isLoadingSleep = false
            }
        }
    }

    private func loadSleepDataForRange(
        startDate: Date,
        endDate: Date,
        completion: @escaping (
            [(stage: String, startDate: Date, endDate: Date)]
        ) -> Void
    ) {
        var allData: [(stage: String, startDate: Date, endDate: Date)] = []
        let group = DispatchGroup()
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            group.enter()
            healthDataManager.fetchSleepData(for: currentDate) { data, _ in
                if let data = data {
                    allData.append(contentsOf: data)
                }
                group.leave()
            }
            if let nextDay = calendar.date(
                byAdding: .day, value: 1, to: currentDate)
            {
                currentDate = nextDay
            } else {
                break
            }
        }

        group.notify(queue: .main) {
            completion(allData)
        }
    }

    @MainActor
    private func refreshData() async {
        loadSleepData()
        loadBaselines()
    }

    // MARK: - HRV / RHR Baselines (30 days)

    private func loadBaselines() {
        // HRV
        isLoadingHRV = true
        healthDataManager.fetchDailyHRVOverLast30Days { data, _ in
            DispatchQueue.main.async {
                self.isLoadingHRV = false
                if let data = data {
                    self.dailyHRV = data
                    if !data.isEmpty {
                        let values = data.values
                        self.hrvBaseline =
                            values.reduce(0, +) / Double(values.count)
                    }
                }
            }
        }

        // RHR
        isLoadingRHR = true
        healthDataManager.fetchDailyRestingHROverLast30Days { data, _ in
            DispatchQueue.main.async {
                self.isLoadingRHR = false
                if let data = data {
                    self.dailyRHR = data
                    if !data.isEmpty {
                        let values = data.values
                        self.rhrBaseline =
                            values.reduce(0, +) / Double(values.count)
                    }
                }
            }
        }
    }
}
