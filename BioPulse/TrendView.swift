//
//  TrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import Charts
import SwiftUI

struct SleepStageEntry: Identifiable {
    let id = UUID()
    let date: Date
    let stage: String
    let hours: Double
}

struct TrendView: View {
    @EnvironmentObject var healthDataManager: HealthDataManager
    @State private var nights: [HealthDataManager.NightData] = []
    @State private var allNights: [HealthDataManager.NightData] = []
    @State private var dailyHRV: [Date: Double] = [:]
    @State private var dailyRHR: [Date: Double] = [:]
    @State private var isLoading = false
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var selectedPeriod = 30

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme

    private var goalSleepMinutes: Int {
        UserDefaults.standard.integer(forKey: "sleepGoal")
    }
    private var isGoalNotSet: Bool {
        let g = UserDefaults.standard.integer(forKey: "sleepGoal")
        let w = UserDefaults.standard.double(forKey: "goalWakeTime")
        return g == 0 || w == 0
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 5)
    }

    private var filteredNights: [HealthDataManager.NightData] {
        let sorted = allNights.sorted { $0.date > $1.date }
        return Array(sorted.prefix(selectedPeriod))
    }

    private var filteredHRV: [Date: Double] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -selectedPeriod, to: Date()) ?? Date()
        return dailyHRV.filter { $0.key >= cutoff }
    }

    private var filteredRHR: [Date: Double] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -selectedPeriod, to: Date()) ?? Date()
        return dailyRHR.filter { $0.key >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Period", selection: $selectedPeriod) {
                        Text("7d").tag(7)
                        Text("14d").tag(14)
                        Text("30d").tag(30)
                        Text("90d").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView("Loading data...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if allNights.isEmpty {
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
                        .padding(.top, 40)
                    } else {
                        // Sleep Trend card
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Sleep Trend")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.blue)
                            }

                            Divider()

                            SleepTrendView(
                                sleepData: convertToStages(filteredNights),
                                goalSleepMinutes: goalSleepMinutes,
                                goalWakeTime: fetchGoalWakeTime(),
                                sleepNights: filteredNights
                            )
                        }
                        .padding()
                        .background(cardBackground)

                        sleepStagesSection

                        // HRV card
                        if filteredHRV.filter({ $0.value != 0 }).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("Heart Rate Variability")
                                        .font(.headline)
                                } icon: {
                                    Image(systemName: "waveform.path.ecg")
                                        .foregroundColor(.green)
                                }

                                Divider()

                                Text("No HRV data (Last \(selectedPeriod) days)")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(cardBackground)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("Heart Rate Variability")
                                        .font(.headline)
                                } icon: {
                                    Image(systemName: "waveform.path.ecg")
                                        .foregroundColor(.green)
                                }

                                Text("Nightly HRV trend (\(selectedPeriod)d)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Divider()

                                HRVTrendChart(dailyHRV: filteredHRV, selectedPeriod: selectedPeriod)
                                    .frame(height: 200)
                            }
                            .padding()
                            .background(cardBackground)
                        }

                        // RHR card
                        if filteredRHR.filter({ $0.value != 0 }).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("Resting Heart Rate")
                                        .font(.headline)
                                } icon: {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                }

                                Divider()

                                Text("No RHR data (Last \(selectedPeriod) days)")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(cardBackground)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Label {
                                    Text("Resting Heart Rate")
                                        .font(.headline)
                                } icon: {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                }

                                Text("Nightly resting heart rate trend (\(selectedPeriod)d)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Divider()

                                RHRTrendChart(dailyRHR: filteredRHR, selectedPeriod: selectedPeriod)
                                    .frame(height: 200)
                            }
                            .padding()
                            .background(cardBackground)
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

    // MARK: - Sleep Stages Section

    @ViewBuilder
    private var sleepStagesSection: some View {
        let stageData = buildSleepStageData()
        if !stageData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Sleep Stages")
                        .font(.headline)
                } icon: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                }

                Divider()

                Chart {
                    ForEach(stageData) { entry in
                        BarMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Hours", entry.hours)
                        )
                        .foregroundStyle(by: .value("Stage", entry.stage))
                    }
                }
                .chartForegroundStyleScale([
                    "Deep": Color.purple,
                    "REM": Color.cyan,
                    "Core": Color.blue,
                ])
                .chartYAxis {
                    AxisMarks { value in
                        if let h = value.as(Double.self) {
                            AxisValueLabel { Text("\(h, specifier: "%.0f")h") }
                            AxisTick()
                            AxisGridLine()
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(stageData.count / 3, 7))) { val in
                        if let date = val.as(Date.self) {
                            AxisValueLabel {
                                Text(shortDateString(date))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
            .padding()
            .background(cardBackground)
        }
    }

    private func buildSleepStageData() -> [SleepStageEntry] {
        let cal = Calendar.current
        var entries: [SleepStageEntry] = []
        for night in filteredNights {
            let dayKey = cal.startOfDay(for: night.date)
            let deepHours = night.deepSleepDuration / 3600.0
            let remHours = night.remSleepDuration / 3600.0
            let coreHours = night.coreSleepDuration / 3600.0
            if deepHours + remHours + coreHours > 0 {
                entries.append(SleepStageEntry(date: dayKey, stage: "Deep", hours: deepHours))
                entries.append(SleepStageEntry(date: dayKey, stage: "REM", hours: remHours))
                entries.append(SleepStageEntry(date: dayKey, stage: "Core", hours: coreHours))
            }
        }
        return entries.sorted { $0.date < $1.date }
    }

    private func shortDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    // MARK: - Data Loading

    private func loadTrendData() {
        if isLoading { return }
        isLoading = true
        allNights = []
        dailyHRV = [:]
        dailyRHR = [:]
        healthDataManager.fetchNightsOverLastNDays(
            90, sleepGoalMinutes: goalSleepMinutes
        ) { fetched in
            let sorted = fetched.sorted { $0.date > $1.date }
            let cal = Calendar.current
            var newHRV: [Date: Double] = [:]
            var newRHR: [Date: Double] = [:]
            for n in sorted {
                let dayKey = cal.startOfDay(for: n.date)
                newHRV[dayKey] = n.hrv
                newRHR[dayKey] = n.restingHeartRate
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                allNights = sorted
                nights = Array(sorted.prefix(30))
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
            allNights = []
            dailyHRV = [:]
            dailyRHR = [:]
            healthDataManager.fetchNightsOverLastNDays(
                90, sleepGoalMinutes: goalSleepMinutes
            ) { fetched in
                let sorted = fetched.sorted { $0.date > $1.date }
                let cal = Calendar.current
                var newHRV: [Date: Double] = [:]
                var newRHR: [Date: Double] = [:]
                for n in sorted {
                    let dayKey = cal.startOfDay(for: n.date)
                    newHRV[dayKey] = n.hrv
                    newRHR[dayKey] = n.restingHeartRate
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.allNights = sorted
                    self.nights = Array(sorted.prefix(30))
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
        return Array(mapped.reversed())
    }

    private func fetchGoalWakeTime() -> Date {
        let c = Calendar.current
        let defaultWake =
            c.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let stored = UserDefaults.standard.double(forKey: "goalWakeTime")
        return stored == 0 ? defaultWake : Date(timeIntervalSince1970: stored)
    }
}
