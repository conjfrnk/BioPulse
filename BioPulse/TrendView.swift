//
//  TrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI
import Charts

struct TrendView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var nights: [HealthDataManager.NightData] = []

    @State private var dailyHRV: [Date: Double] = [:]
    @State private var dailyRHR: [Date: Double] = [:]
    @State private var isLoading = false

    @State private var showingSettings = false
    @State private var showingInfo = false

    @Environment(\.scenePhase) private var scenePhase

    private var goalSleepMinutes: Int {
        UserDefaults.standard.integer(forKey: "sleepGoal")
    }
    private var isGoalNotSet: Bool {
        let g = UserDefaults.standard.integer(forKey: "sleepGoal")
        let w = UserDefaults.standard.double(forKey: "goalWakeTime")
        return g == 0 || w == 0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if isLoading {
                        ProgressView("Loading data...")
                            .frame(maxWidth: .infinity)
                    } else if nights.isEmpty {
                        Text("No sleep data available")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        // Sleep chart
                        SleepTrendView(
                            sleepData: convertToStages(nights),
                            goalSleepMinutes: goalSleepMinutes,
                            goalWakeTime: fetchGoalWakeTime()
                        )

                        if dailyHRV.isEmpty {
                            Text("No HRV data (Last 30 days)")
                                .foregroundColor(.secondary)
                        } else {
                            HRVTrendChart(dailyHRV: dailyHRV)
                                .frame(height: 200)
                        }

                        if dailyRHR.isEmpty {
                            Text("No RHR data (Last 30 days)")
                                .foregroundColor(.secondary)
                        } else {
                            RHRTrendChart(dailyRHR: dailyRHR)
                                .frame(height: 200)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
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
            // .sheet(...) your Settings/Info if needed
            .onAppear {
                if isGoalNotSet {
                    showingSettings = true
                } else {
                    loadTrendData()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    if isGoalNotSet {
                        showingSettings = true
                    } else {
                        loadTrendData()
                    }
                }
            }
            .refreshable {
                await refreshTrend()
            }
        }
    }

    private func loadTrendData() {
        guard !isLoading else { return }
        isLoading = true
        nights = []
        dailyHRV = [:]
        dailyRHR = [:]

        // fetch 30 days
        healthDataManager.fetchNightsOverLastNDays(30, sleepGoalMinutes: goalSleepMinutes) { fetched in
            let cal = Calendar.current
            for n in fetched {
                let dayKey = cal.startOfDay(for: n.date)
                self.dailyHRV[dayKey] = n.hrv
                self.dailyRHR[dayKey] = n.restingHeartRate
            }
            self.nights = fetched
            self.isLoading = false
        }
    }

    @MainActor
    private func refreshTrend() async {
        loadTrendData()
    }

    private func convertToStages(_ arr: [HealthDataManager.NightData]) -> [(stage: String, startDate: Date, endDate: Date)] {
        // If you only have total time, treat it as "Core" for the chart
        let sorted = arr.sorted { $0.date > $1.date }
        let mapped = sorted.map {
            (stage: "Core", startDate: $0.sleepStartTime, endDate: $0.sleepEndTime)
        }
        // show last 8
        return Array(mapped.prefix(8).reversed())
    }

    private func fetchGoalWakeTime() -> Date {
        let c = Calendar.current
        let defaultWake = c.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let stored = UserDefaults.standard.double(forKey: "goalWakeTime")
        return stored == 0 ? defaultWake : Date(timeIntervalSince1970: stored)
    }
}
