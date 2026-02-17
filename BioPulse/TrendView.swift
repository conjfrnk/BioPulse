//
//  TrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import Charts
import SwiftUI

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    if isLoading {
                        ProgressView("Loading data...")
                            .frame(maxWidth: .infinity)
                    } else if nights.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No sleep data available yet. Wear your Apple Watch to bed and ensure HealthKit permissions are granted in Settings.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    } else {
                        SleepTrendView(
                            sleepData: convertToStages(nights),
                            goalSleepMinutes: goalSleepMinutes,
                            goalWakeTime: fetchGoalWakeTime(),
                            sleepNights: nights
                        )
                        if dailyHRV.filter({ $0.value != 0 }).isEmpty {
                            Text("No HRV data (Last 30 days)")
                                .foregroundColor(.secondary)
                        } else {
                            HRVTrendChart(dailyHRV: dailyHRV)
                                .frame(height: 200)
                                .padding(.bottom, 20)
                        }
                        if dailyRHR.filter({ $0.value != 0 }).isEmpty {
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    loadTrendData()
                }
            }
        }
    }

    private func loadTrendData() {
        if isLoading { return }
        isLoading = true
        nights = []
        dailyHRV = [:]
        dailyRHR = [:]
        healthDataManager.fetchNightsOverLastNDays(
            90, sleepGoalMinutes: goalSleepMinutes
        ) { fetched in
            let sorted = fetched.sorted { $0.date > $1.date }
            let last30 = Array(sorted.prefix(30))
            let cal = Calendar.current
            var newHRV: [Date: Double] = [:]
            var newRHR: [Date: Double] = [:]
            for n in last30 {
                let dayKey = cal.startOfDay(for: n.date)
                newHRV[dayKey] = n.hrv
                newRHR[dayKey] = n.restingHeartRate
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                nights = sorted
                dailyHRV = newHRV
                dailyRHR = newRHR
                isLoading = false
            }
        }
    }

    @MainActor
    private func refreshTrend() async {
        await withCheckedContinuation { continuation in
            guard !isLoading else {
                continuation.resume()
                return
            }
            isLoading = true
            nights = []
            dailyHRV = [:]
            dailyRHR = [:]
            healthDataManager.fetchNightsOverLastNDays(
                90, sleepGoalMinutes: goalSleepMinutes
            ) { fetched in
                let sorted = fetched.sorted { $0.date > $1.date }
                let last30 = Array(sorted.prefix(30))
                let cal = Calendar.current
                var newHRV: [Date: Double] = [:]
                var newRHR: [Date: Double] = [:]
                for n in last30 {
                    let dayKey = cal.startOfDay(for: n.date)
                    newHRV[dayKey] = n.hrv
                    newRHR[dayKey] = n.restingHeartRate
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.nights = sorted
                    self.dailyHRV = newHRV
                    self.dailyRHR = newRHR
                    self.isLoading = false
                }
                continuation.resume()
            }
        }
    }

    private func convertToStages(_ arr: [HealthDataManager.NightData]) -> [(
        stage: String, startDate: Date, endDate: Date
    )] {
        let sorted = arr.sorted { $0.date > $1.date }
        let mapped = sorted.map {
            (
                stage: "Core",
                startDate: $0.sleepStartTime,
                endDate: $0.sleepEndTime
            )
        }
        return Array(mapped.prefix(8).reversed())
    }

    private func fetchGoalWakeTime() -> Date {
        let c = Calendar.current
        let defaultWake =
            c.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let stored = UserDefaults.standard.double(forKey: "goalWakeTime")
        return stored == 0 ? defaultWake : Date(timeIntervalSince1970: stored)
    }
}
