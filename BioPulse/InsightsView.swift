//
//  InsightsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI
import UIKit

struct InsightsView: View {
    @EnvironmentObject var healthDataManager: HealthDataManager
    @State private var nights: [HealthDataManager.NightData] = []
    @State private var isLoading = false
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    @State private var showingReportSheet = false
    @Environment(\.colorScheme) var colorScheme

    private var sleepGoalMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "sleepGoal")
        return val > 0 ? val : 480
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Analyzing your sleep data...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if nights.isEmpty {
                    Text("No sleep data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 20) {
                        recoveryReadinessCard
                        weeklySummaryCard
                        historicalComparisonCard
                        trendIndicatorsCard
                        correlationInsightsCard
                        autonomicBalanceCard
                        sleepEfficiencyCard
                        sleepArchitectureCard
                        sleepDebtCard
                        chronotypeCard
                        optimalSleepWindowCard
                        bedtimeConsistencyCard
                        sleepRegularityCard
                        socialJetLagCard
                        dataActionsCard
                        personalizedTipsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
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
                loadData()
            }
            .refreshable {
                await refreshData()
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    loadData()
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        if isLoading { return }
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            30, sleepGoalMinutes: sleepGoalMinutes
        ) { fetched in
            withAnimation(.easeInOut(duration: 0.3)) {
                nights = fetched.sorted { $0.date > $1.date }
                isLoading = false
            }
            updateWidgetData()
        }
    }

    @MainActor
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            guard !isLoading else {
                continuation.resume()
                return
            }
            isLoading = true
            healthDataManager.fetchNightsOverLastNDays(
                30, sleepGoalMinutes: sleepGoalMinutes
            ) { fetched in
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.nights = fetched.sorted { $0.date > $1.date }
                    self.isLoading = false
                }
                continuation.resume()
            }
        }
    }

    private func updateWidgetData() {
        SharedDefaults.writeWidgetData(
            recoveryScore: recoveryReadinessScore,
            recoveryLabel: recoveryLabel,
            sleepDebtHours: sleepDebtHours,
            optimalBedtime: optimalBedtimeWindow?.start,
            lastHRV: nights.first?.hrv ?? 0,
            lastRHR: nights.first?.restingHeartRate ?? 0,
            lastSleepDuration: nights.first?.sleepDuration ?? 0
        )
    }

    // MARK: - Data Slices

    private var last7Nights: [HealthDataManager.NightData] {
        Array(nights.prefix(7))
    }

    private var prior7Nights: [HealthDataManager.NightData] {
        Array(nights.dropFirst(7).prefix(7))
    }

    private var last14Nights: [HealthDataManager.NightData] {
        Array(nights.prefix(14))
    }

    // MARK: - Recovery Readiness Score
    // Composite metric inspired by Whoop Recovery / Oura Readiness
    // Weights: HRV baseline deviation (35%), RHR baseline deviation (25%),
    //          Sleep duration vs goal (25%), Sleep debt factor (15%)

    private var recoveryReadinessScore: Int {
        guard let lastNight = nights.first else { return 0 }
        let hrvVals = nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        let rhrVals = nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }

        let hrvBaseline = hrvVals.isEmpty ? 50.0 : hrvVals.reduce(0, +) / Double(hrvVals.count)
        let rhrBaseline = rhrVals.isEmpty ? 60.0 : rhrVals.reduce(0, +) / Double(rhrVals.count)

        // HRV component: higher than baseline = better
        let hrvScore: Double
        if hrvBaseline > 0 && lastNight.hrv > 0 {
            let ratio = lastNight.hrv / hrvBaseline
            hrvScore = min(100, max(0, ratio * 100))
        } else {
            hrvScore = 50
        }

        // RHR component: lower than baseline = better
        let rhrScore: Double
        if rhrBaseline > 0 && lastNight.restingHeartRate > 0 {
            let ratio = rhrBaseline / lastNight.restingHeartRate
            rhrScore = min(100, max(0, ratio * 100))
        } else {
            rhrScore = 50
        }

        // Duration component
        let goalSec = Double(sleepGoalMinutes) * 60
        let durationRatio = goalSec > 0 ? min(1.0, lastNight.sleepDuration / goalSec) : 0.5
        let durationScore = durationRatio * 100

        // Debt component
        let debtHrs = sleepDebtHours
        let debtScore = max(0, 100 - (debtHrs * 15))

        let composite = hrvScore * 0.35 + rhrScore * 0.25 + durationScore * 0.25 + debtScore * 0.15
        return max(0, min(100, Int(composite)))
    }

    private var recoveryLabel: String {
        let score = recoveryReadinessScore
        if score >= 67 { return "Ready" }
        if score >= 34 { return "Moderate" }
        return "Strained"
    }

    private var recoveryColor: Color {
        let score = recoveryReadinessScore
        if score >= 67 { return .green }
        if score >= 34 { return .yellow }
        return .red
    }

    // Recovery confidence based on 7-day rolling SD
    // Plews et al. (2013) - higher HRV CV indicates maladaptation
    private var recoveryConfidence: (label: String, sd: Double, color: Color) {
        let scores = last7Nights.map { night -> Double in
            // Calculate per-night recovery score inline
            let hrvVals = nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
            let rhrVals = nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
            let hrvBaseline = hrvVals.isEmpty ? 50.0 : hrvVals.reduce(0, +) / Double(hrvVals.count)
            let rhrBaseline = rhrVals.isEmpty ? 60.0 : rhrVals.reduce(0, +) / Double(rhrVals.count)

            let hrvScore: Double
            if hrvBaseline > 0 && night.hrv > 0 {
                hrvScore = min(100, max(0, (night.hrv / hrvBaseline) * 100))
            } else { hrvScore = 50 }

            let rhrScore: Double
            if rhrBaseline > 0 && night.restingHeartRate > 0 {
                rhrScore = min(100, max(0, (rhrBaseline / night.restingHeartRate) * 100))
            } else { rhrScore = 50 }

            let goalSec = Double(sleepGoalMinutes) * 60
            let durationScore = goalSec > 0 ? min(1.0, night.sleepDuration / goalSec) * 100 : 50

            let composite = hrvScore * 0.35 + rhrScore * 0.25 + durationScore * 0.25 + 50.0 * 0.15
            return max(0, min(100, composite))
        }
        guard scores.count >= 2 else { return ("N/A", 0, .secondary) }
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(scores.count)
        let sd = sqrt(variance)
        if sd < 8 { return ("Stable", sd, .green) }
        if sd < 15 { return ("Moderate", sd, .yellow) }
        return ("Volatile", sd, .red)
    }

    // MARK: - Autonomic Balance
    // HRV:RHR ratio as a proxy for parasympathetic vs sympathetic dominance
    // Higher ratio = better parasympathetic tone (rest & recovery)
    // Research: Shaffer & Ginsberg (2017) - HRV review

    private var autonomicBalanceRatio: Double {
        guard let lastNight = nights.first,
              lastNight.hrv > 0, lastNight.restingHeartRate > 0
        else { return 0 }
        return lastNight.hrv / lastNight.restingHeartRate
    }

    private var avgAutonomicBalance: Double {
        let valid = nights.filter { $0.hrv > 0 && $0.restingHeartRate > 0 }
        guard !valid.isEmpty else { return 0 }
        let ratios = valid.map { $0.hrv / $0.restingHeartRate }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    private var autonomicLabel: String {
        let ratio = autonomicBalanceRatio
        if ratio >= 1.0 { return "Parasympathetic dominant" }
        if ratio >= 0.6 { return "Balanced" }
        return "Sympathetic dominant"
    }

    private var autonomicColor: Color {
        let ratio = autonomicBalanceRatio
        if ratio >= 1.0 { return .green }
        if ratio >= 0.6 { return .blue }
        return .orange
    }

    // MARK: - Sleep Efficiency
    // Time asleep / total time in bed * 100
    // Optimal: 85-95% (AASM standard)
    // >95% may indicate sleep deprivation

    private func sleepEfficiency(for night: HealthDataManager.NightData) -> Double {
        let timeInBed = night.sleepEndTime.timeIntervalSince(night.sleepStartTime)
        guard timeInBed > 0 else { return 0 }
        return (night.sleepDuration / timeInBed) * 100
    }

    private var avgSleepEfficiency7: Double {
        guard !last7Nights.isEmpty else { return 0 }
        let effs = last7Nights.map { sleepEfficiency(for: $0) }
        return effs.reduce(0, +) / Double(effs.count)
    }

    private var sleepEfficiencyLabel: String {
        let eff = avgSleepEfficiency7
        if eff >= 95 { return "Possibly sleep deprived" }
        if eff >= 85 { return "Optimal" }
        if eff >= 75 { return "Fair" }
        return "Poor"
    }

    private var sleepEfficiencyColor: Color {
        let eff = avgSleepEfficiency7
        if eff >= 95 { return .yellow }
        if eff >= 85 { return .green }
        if eff >= 75 { return .yellow }
        return .red
    }

    // MARK: - Chronotype Detection
    // Based on sleep midpoint (MSF - midpoint of sleep on free days)
    // Roenneberg et al. (2004) Munich ChronoType Questionnaire
    // Early: midpoint < 3:00 AM
    // Intermediate: 3:00-4:30 AM
    // Late: > 4:30 AM

    private var sleepMidpointMinutes: Double {
        let relevant = last14Nights
        guard !relevant.isEmpty else { return 0 }
        let midpoints = relevant.map { night -> Double in
            let start = minuteOfDay(from: night.sleepStartTime)
            let durationMin = night.sleepDuration / 60
            return start + durationMin / 2
        }
        return midpoints.reduce(0, +) / Double(midpoints.count)
    }

    private var chronotype: String {
        let mid = sleepMidpointMinutes
        var normalized = mid
        if normalized >= 24 * 60 { normalized -= 24 * 60 }
        // Convert to hours for readability
        if normalized < 150 { return "Definite Early" }       // before 2:30 AM
        if normalized < 210 { return "Moderate Early" }       // 2:30-3:30 AM
        if normalized < 270 { return "Intermediate" }          // 3:30-4:30 AM
        if normalized < 330 { return "Moderate Late" }        // 4:30-5:30 AM
        return "Definite Late"                                  // after 5:30 AM
    }

    private var chronotypeIcon: String {
        let mid = sleepMidpointMinutes
        var normalized = mid
        if normalized >= 24 * 60 { normalized -= 24 * 60 }
        if normalized < 210 { return "sunrise.fill" }
        if normalized < 270 { return "sun.max.fill" }
        return "moon.stars.fill"
    }

    // MARK: - Social Jet Lag
    // Difference between weekend and weekday sleep midpoint
    // Wittmann et al. (2006) - >1h associated with health risks
    // >2h associated with metabolic syndrome risk

    private var socialJetLagMinutes: Double {
        let cal = Calendar.current
        let restDays = UserDefaults.standard.array(forKey: "restDays") as? [Int] ?? [1, 7]
        var workDayMidpoints: [Double] = []
        var restDayMidpoints: [Double] = []

        for night in last14Nights {
            let wakeDay = cal.component(.weekday, from: night.sleepEndTime)
            let isRestDay = restDays.contains(wakeDay)
            let start = minuteOfDay(from: night.sleepStartTime)
            let durationMin = night.sleepDuration / 60
            let midpoint = start + durationMin / 2

            if isRestDay {
                restDayMidpoints.append(midpoint)
            } else {
                workDayMidpoints.append(midpoint)
            }
        }

        guard !workDayMidpoints.isEmpty, !restDayMidpoints.isEmpty else { return 0 }
        let workDayAvg = workDayMidpoints.reduce(0, +) / Double(workDayMidpoints.count)
        let restDayAvg = restDayMidpoints.reduce(0, +) / Double(restDayMidpoints.count)
        return abs(restDayAvg - workDayAvg)
    }

    private var socialJetLagLabel: String {
        let minutes = socialJetLagMinutes
        if minutes < 30 { return "Minimal" }
        if minutes < 60 { return "Mild" }
        if minutes < 120 { return "Moderate" }
        return "Severe"
    }

    private var socialJetLagColor: Color {
        let minutes = socialJetLagMinutes
        if minutes < 30 { return .green }
        if minutes < 60 { return .yellow }
        if minutes < 120 { return .orange }
        return .red
    }

    // MARK: - HRV Coefficient of Variation
    // CV = (SD / Mean) * 100
    // Lower CV = more stable ANS, better adaptation
    // Higher CV can indicate overtraining or illness onset
    // Plews et al. (2013) - HRV monitoring in athletes

    private var hrvCV: Double {
        let hrvVals = last14Nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        guard hrvVals.count >= 3 else { return 0 }
        let mean = hrvVals.reduce(0, +) / Double(hrvVals.count)
        guard mean > 0 else { return 0 }
        let variance = hrvVals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hrvVals.count)
        return (sqrt(variance) / mean) * 100
    }

    // MARK: - Autonomic Balance Index (ABI)
    // Normalized: (HRV/HRV_baseline) / (RHR/RHR_baseline)
    // Centers around 1.0; accounts for personal baselines
    // Research: Shaffer & Ginsberg (2017)

    private var autonomicBalanceIndex: Double {
        guard let lastNight = nights.first,
              lastNight.hrv > 0, lastNight.restingHeartRate > 0 else { return 0 }
        let hrvVals = nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        let rhrVals = nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        let hrvBase = hrvVals.isEmpty ? 50.0 : hrvVals.reduce(0, +) / Double(hrvVals.count)
        let rhrBase = rhrVals.isEmpty ? 60.0 : rhrVals.reduce(0, +) / Double(rhrVals.count)
        guard hrvBase > 0, rhrBase > 0 else { return 0 }
        return (lastNight.hrv / hrvBase) / (lastNight.restingHeartRate / rhrBase)
    }

    private var abiLabel: String {
        let abi = autonomicBalanceIndex
        if abi >= 1.1 { return "Strong recovery" }
        if abi >= 0.85 { return "Balanced" }
        if abi > 0 { return "Under stress" }
        return "No data"
    }

    private var abiColor: Color {
        let abi = autonomicBalanceIndex
        if abi >= 1.1 { return .green }
        if abi >= 0.85 { return .blue }
        return .orange
    }

    // MARK: - Sleep Regularity Index
    // Simplified SRI: 100 - avg(bedtime_variability, waketime_variability)
    // Research: Phillips et al. (2017), Windred et al. (2024)
    // Highest SRI quintile = 30% lower all-cause mortality

    private var wakeTimeVariabilityMinutes: Double {
        guard last14Nights.count >= 2 else { return 0 }
        let wakeMinutes = last14Nights.map { minuteOfDay(from: $0.sleepEndTime) }
        let mean = wakeMinutes.reduce(0, +) / Double(wakeMinutes.count)
        let variance = wakeMinutes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(wakeMinutes.count)
        return sqrt(variance)
    }

    private var sleepRegularityScore: Double {
        guard last14Nights.count >= 7 else { return 0 }
        let avgVar = (bedtimeConsistencyMinutes14 + wakeTimeVariabilityMinutes) / 2
        return max(0, min(100, 100 - avgVar))
    }

    private var regularityLabel: String {
        let score = sleepRegularityScore
        if score >= 85 { return "Excellent" }
        if score >= 70 { return "Good" }
        if score >= 50 { return "Fair" }
        return "Poor"
    }

    private var regularityColor: Color {
        let score = sleepRegularityScore
        if score >= 85 { return .green }
        if score >= 70 { return .blue }
        if score >= 50 { return .yellow }
        return .red
    }

    // MARK: - Optimal Sleep Window
    // Data-driven bedtime from nights with best recovery (top quartile HRV)

    private var optimalBedtimeWindow: (start: String, end: String)? {
        let validNights = nights.filter { $0.hrv > 0 }
        guard validNights.count >= 14 else { return nil }
        let sortedByHRV = validNights.sorted { $0.hrv > $1.hrv }
        let topCount = max(1, validNights.count / 4)
        let bestNights = Array(sortedByHRV.prefix(topCount))
        let bedtimes = bestNights.map { minuteOfDay(from: $0.sleepStartTime) }
        let avgBedtime = bedtimes.reduce(0, +) / Double(bedtimes.count)
        return (start: formatMinuteOfDay(avgBedtime - 30), end: formatMinuteOfDay(avgBedtime + 30))
    }

    private func formatMinuteOfDay(_ minutes: Double) -> String {
        var normalized = minutes
        if normalized >= 24 * 60 { normalized -= 24 * 60 }
        let h = Int(normalized) / 60
        let m = Int(normalized) % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - HRV Pattern Detection
    // Plews et al. (2013) - 5 pattern signatures

    private var hrvPatternDescription: String {
        switch hrvTrend {
        case .declining:
            if hrvCV > 0 && hrvCV < 8 {
                return "Overtraining signal: declining HRV with reduced variability"
            }
            return "Acute stress or early illness: declining HRV"
        case .improving:
            if hrvCV > 0 && hrvCV < 8 {
                return "Watch for parasympathetic overtraining"
            }
            return "Positive adaptation: improving recovery"
        case .stable:
            if hrvCV > 20 {
                return "Inconsistent recovery patterns"
            }
            return "Stable autonomic baseline"
        }
    }

    // MARK: - Correlation Insights
    // Automated pattern detection from sleep data

    private var correlationInsights: [String] {
        var insights: [String] = []
        guard nights.count >= 14 else { return ["Need 14+ nights of data for correlation analysis"] }

        // Correlation: Early bedtime vs HRV
        let nightsWithHRV = nights.filter { $0.hrv > 0 }
        if nightsWithHRV.count >= 10 {
            let sorted = nightsWithHRV.sorted { minuteOfDay(from: $0.sleepStartTime) < minuteOfDay(from: $1.sleepStartTime) }
            let earlyHalf = Array(sorted.prefix(sorted.count / 2))
            let lateHalf = Array(sorted.suffix(sorted.count / 2))
            let earlyAvgHRV = earlyHalf.map { $0.hrv }.reduce(0, +) / Double(earlyHalf.count)
            let lateAvgHRV = lateHalf.map { $0.hrv }.reduce(0, +) / Double(lateHalf.count)
            if earlyAvgHRV > lateAvgHRV * 1.05 {
                let pct = Int((earlyAvgHRV / lateAvgHRV - 1) * 100)
                let cutoff = minuteOfDay(from: sorted[sorted.count / 2].sleepStartTime)
                var normalized = cutoff
                if normalized >= 24 * 60 { normalized -= 24 * 60 }
                let h = Int(normalized) / 60
                let m = Int(normalized) % 60
                insights.append("HRV is \(pct)% higher when you sleep before \(String(format: "%02d:%02d", h, m))")
            }
        }

        // Correlation: Sleep duration vs next-day score
        if nights.count >= 14 {
            let longNights = nights.filter { $0.sleepDuration >= Double(sleepGoalMinutes) * 60 }
            let shortNights = nights.filter { $0.sleepDuration < Double(sleepGoalMinutes) * 60 }
            if longNights.count >= 3 && shortNights.count >= 3 {
                let longAvgScore = Double(longNights.map { $0.sleepScore }.reduce(0, +)) / Double(longNights.count)
                let shortAvgScore = Double(shortNights.map { $0.sleepScore }.reduce(0, +)) / Double(shortNights.count)
                if longAvgScore > shortAvgScore + 3 {
                    insights.append("Sleep score averages \(Int(longAvgScore - shortAvgScore)) points higher when you meet your sleep goal")
                }
            }
        }

        // Correlation: Consistency vs HRV
        if nights.count >= 14 {
            let cal = Calendar.current
            let weekdays = nights.filter {
                let wd = cal.component(.weekday, from: $0.sleepStartTime)
                return wd >= 2 && wd <= 6
            }
            let weekends = nights.filter {
                let wd = cal.component(.weekday, from: $0.sleepStartTime)
                return wd == 1 || wd == 7
            }
            if weekdays.count >= 5 && weekends.count >= 2 {
                let wdHRV = weekdays.compactMap { $0.hrv > 0 ? $0.hrv : nil }
                let weHRV = weekends.compactMap { $0.hrv > 0 ? $0.hrv : nil }
                if !wdHRV.isEmpty && !weHRV.isEmpty {
                    let wdAvg = wdHRV.reduce(0, +) / Double(wdHRV.count)
                    let weAvg = weHRV.reduce(0, +) / Double(weHRV.count)
                    if abs(wdAvg - weAvg) > 3 {
                        let better = wdAvg > weAvg ? "weekdays" : "weekends"
                        let diff = Int(abs(wdAvg - weAvg))
                        insights.append("HRV averages \(diff)ms higher on \(better)")
                    }
                }
            }
        }

        // Correlation: Awake time vs efficiency
        let avgAwake = nights.isEmpty ? 0 : nights.reduce(0.0) { $0 + $1.totalAwakeTime } / Double(nights.count)
        if avgAwake > 30 * 60 {
            let lowAwakeNights = nights.filter { $0.totalAwakeTime < avgAwake }
            let highAwakeNights = nights.filter { $0.totalAwakeTime >= avgAwake }
            if lowAwakeNights.count >= 3 && highAwakeNights.count >= 3 {
                let lowAvgScore = Double(lowAwakeNights.map { $0.sleepScore }.reduce(0, +)) / Double(lowAwakeNights.count)
                let highAvgScore = Double(highAwakeNights.map { $0.sleepScore }.reduce(0, +)) / Double(highAwakeNights.count)
                if lowAvgScore > highAvgScore + 2 {
                    insights.append("Less nighttime wakefulness correlates with \(Int(lowAvgScore - highAvgScore))-point higher sleep scores")
                }
            }
        }

        if insights.isEmpty {
            insights.append("Collecting more data to find patterns in your sleep")
        }

        return Array(insights.prefix(4))
    }

    // MARK: - Historical Comparison

    private var weekOverWeekComparison: (thisWeek: (avgScore: Double, avgDuration: TimeInterval, avgHRV: Double), lastWeek: (avgScore: Double, avgDuration: TimeInterval, avgHRV: Double))? {
        guard nights.count >= 14 else { return nil }
        let thisWeek = Array(nights.prefix(7))
        let lastWeek = Array(nights.dropFirst(7).prefix(7))
        guard !thisWeek.isEmpty, !lastWeek.isEmpty else { return nil }

        let tw = (
            avgScore: Double(thisWeek.reduce(0) { $0 + $1.sleepScore }) / Double(thisWeek.count),
            avgDuration: thisWeek.reduce(0.0) { $0 + $1.sleepDuration } / Double(thisWeek.count),
            avgHRV: thisWeek.compactMap { $0.hrv > 0 ? $0.hrv : nil }.reduce(0, +) / max(1, Double(thisWeek.compactMap { $0.hrv > 0 ? $0.hrv : nil }.count))
        )
        let lw = (
            avgScore: Double(lastWeek.reduce(0) { $0 + $1.sleepScore }) / Double(lastWeek.count),
            avgDuration: lastWeek.reduce(0.0) { $0 + $1.sleepDuration } / Double(lastWeek.count),
            avgHRV: lastWeek.compactMap { $0.hrv > 0 ? $0.hrv : nil }.reduce(0, +) / max(1, Double(lastWeek.compactMap { $0.hrv > 0 ? $0.hrv : nil }.count))
        )
        return (tw, lw)
    }

    // MARK: - Data Export

    private func exportCSV() -> URL? {
        var csv = "Date,Sleep Score,HRV (ms),RHR (bpm),Duration (hours),Bedtime,Wake Time,Awake Time (min)\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter()
        tf.dateFormat = "HH:mm"

        for night in nights.sorted(by: { $0.date < $1.date }) {
            let date = df.string(from: night.date)
            let duration = String(format: "%.1f", night.sleepDuration / 3600)
            let bedtime = tf.string(from: night.sleepStartTime)
            let wake = tf.string(from: night.sleepEndTime)
            let awake = String(format: "%.0f", night.totalAwakeTime / 60)
            csv += "\(date),\(night.sleepScore),\(Int(night.hrv)),\(Int(night.restingHeartRate)),\(duration),\(bedtime),\(wake),\(awake)\n"
        }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("BioPulse_Sleep_Data.csv")
        try? csv.write(to: tmpURL, atomically: true, encoding: .utf8)
        return tmpURL
    }

    private func weeklySummaryText() -> String {
        let avgDur = formatDuration(avgSleepDuration7)
        let score = Int(avgSleepScore7)
        let eff = String(format: "%.0f", avgSleepEfficiency7)
        let recovery = recoveryReadinessScore

        return """
        BioPulse Weekly Summary
        ───────────────────
        Recovery Score: \(recovery)/100 (\(recoveryLabel))
        Avg Sleep: \(avgDur)
        Avg Score: \(score)
        Efficiency: \(eff)%
        Sleep Debt: \(String(format: "%.1f", sleepDebtHours))h
        Chronotype: \(chronotype)
        """
    }

    // MARK: - Existing Computed Data

    private var avgSleepDuration7: TimeInterval {
        guard !last7Nights.isEmpty else { return 0 }
        let total = last7Nights.reduce(0.0) { $0 + $1.sleepDuration }
        return total / Double(last7Nights.count)
    }

    private var avgSleepScore7: Double {
        guard !last7Nights.isEmpty else { return 0 }
        let total = last7Nights.reduce(0) { $0 + $1.sleepScore }
        return Double(total) / Double(last7Nights.count)
    }

    private var bedtimeConsistencyMinutes14: Double {
        guard last14Nights.count >= 2 else { return 0 }
        let bedtimeMinutes = last14Nights.map { minuteOfDay(from: $0.sleepStartTime) }
        let mean = bedtimeMinutes.reduce(0, +) / Double(bedtimeMinutes.count)
        let variance = bedtimeMinutes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(bedtimeMinutes.count)
        return sqrt(variance)
    }

    private var bedtimeConsistencyMinutes7: Double {
        guard last7Nights.count >= 2 else { return 0 }
        let bedtimeMinutes = last7Nights.map { minuteOfDay(from: $0.sleepStartTime) }
        let mean = bedtimeMinutes.reduce(0, +) / Double(bedtimeMinutes.count)
        let variance = bedtimeMinutes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(bedtimeMinutes.count)
        return sqrt(variance)
    }

    private func minuteOfDay(from date: Date) -> Double {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        var totalMinutes = Double(hour * 60 + minute)
        if hour < 12 {
            totalMinutes += 24 * 60
        }
        return totalMinutes
    }

    private var sleepDebtHours: Double {
        guard !last14Nights.isEmpty else { return 0 }
        let goalSeconds = Double(sleepGoalMinutes) * 60
        let totalDeficit = last14Nights.reduce(0.0) { acc, night in
            acc + max(0, goalSeconds - night.sleepDuration)
        }
        // Capped at 20h per sleep debt recovery research (Kitamura et al. 2016)
        return min(20.0, totalDeficit / 3600.0)
    }

    // MARK: - Trend Helpers

    private enum TrendDirection {
        case improving, stable, declining

        var symbolName: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }

        var color: Color {
            switch self {
            case .improving: return .green
            case .stable: return .secondary
            case .declining: return .red
            }
        }

        var label: String {
            switch self {
            case .improving: return "Improving"
            case .stable: return "Stable"
            case .declining: return "Declining"
            }
        }
    }

    private func trend(current: Double, previous: Double, higherIsBetter: Bool, threshold: Double = 0.05) -> TrendDirection {
        guard previous > 0 else { return .stable }
        let change = (current - previous) / previous
        if abs(change) < threshold { return .stable }
        if higherIsBetter {
            return change > 0 ? .improving : .declining
        } else {
            return change < 0 ? .improving : .declining
        }
    }

    private var sleepScoreTrend: TrendDirection {
        let currentAvg = last7Nights.isEmpty ? 0.0 : Double(last7Nights.reduce(0) { $0 + $1.sleepScore }) / Double(last7Nights.count)
        let priorAvg = prior7Nights.isEmpty ? 0.0 : Double(prior7Nights.reduce(0) { $0 + $1.sleepScore }) / Double(prior7Nights.count)
        return trend(current: currentAvg, previous: priorAvg, higherIsBetter: true)
    }

    private var hrvTrend: TrendDirection {
        let currentVals = last7Nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        let priorVals = prior7Nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        let currentAvg = currentVals.isEmpty ? 0.0 : currentVals.reduce(0, +) / Double(currentVals.count)
        let priorAvg = priorVals.isEmpty ? 0.0 : priorVals.reduce(0, +) / Double(priorVals.count)
        return trend(current: currentAvg, previous: priorAvg, higherIsBetter: true)
    }

    private var rhrTrend: TrendDirection {
        let currentVals = last7Nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        let priorVals = prior7Nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        let currentAvg = currentVals.isEmpty ? 0.0 : currentVals.reduce(0, +) / Double(currentVals.count)
        let priorAvg = priorVals.isEmpty ? 0.0 : priorVals.reduce(0, +) / Double(priorVals.count)
        return trend(current: currentAvg, previous: priorAvg, higherIsBetter: false)
    }

    // MARK: - Enhanced Tips

    private var tips: [String] {
        var result: [String] = []

        // Recovery-based
        let recovery = recoveryReadinessScore
        if recovery < 34 {
            result.append("Your recovery is strained. Prioritize rest today - avoid intense exercise and consider a power nap (20 min) before 2 PM.")
        } else if recovery < 67 {
            result.append("Moderate recovery. Light to moderate activity is fine, but listen to your body and avoid pushing limits.")
        }

        // Sleep debt
        if sleepDebtHours > 5 {
            result.append("Severe sleep debt detected (\(String(format: "%.0f", sleepDebtHours))h). Research shows you can't fully \"catch up\" in one night. Add 30-60 min per night over the next week.")
        } else if sleepDebtHours > 2 {
            result.append("Moderate sleep debt. Try going to bed 20-30 min earlier for the next few nights.")
        }

        // Autonomic balance (using ABI)
        if autonomicBalanceIndex > 0 && autonomicBalanceIndex < 0.85 {
            result.append("Your Autonomic Balance Index is \(String(format: "%.2f", autonomicBalanceIndex)) — your HRV is below baseline relative to RHR. Try 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s before bed.")
        }

        // Social jet lag
        if socialJetLagMinutes > 90 {
            result.append("Your weekend-weekday sleep shift is \(Int(socialJetLagMinutes)) min. This \"social jet lag\" disrupts circadian alignment. Try keeping wake time within 1h of your weekday schedule.")
        }

        // Sleep efficiency
        let eff = avgSleepEfficiency7
        if eff < 75 {
            result.append("Sleep efficiency is \(Int(eff))%. Avoid screen time 1h before bed, keep your bedroom at 65-68°F (18-20°C), and use the bed only for sleep.")
        } else if eff >= 95 {
            result.append("Sleep efficiency is very high (\(Int(eff))%). While this sounds good, it may indicate insufficient sleep opportunity. Consider extending your sleep window.")
        }

        // HRV variability
        if hrvCV > 20 {
            result.append("Your HRV shows high day-to-day variability (CV: \(Int(hrvCV))%). Establish consistent sleep and wake times to stabilize your autonomic nervous system.")
        }

        // Bedtime consistency
        if bedtimeConsistencyMinutes14 > 60 {
            result.append("Your bedtime varies by over 1 hour. Irregular sleep timing weakens circadian entrainment and reduces sleep quality (Lunsford-Avery et al., 2018).")
        }

        // HRV trend
        if case .declining = hrvTrend {
            result.append("Declining HRV trend may signal accumulated stress or early illness. Focus on recovery: limit alcohol, stay hydrated, and avoid late-night meals.")
        }

        // RHR trend
        if case .declining = rhrTrend {
            result.append("Rising resting heart rate often precedes illness by 1-2 days. Monitor closely and consider extra rest.")
        }

        // Sleep regularity
        if sleepRegularityScore > 0 && sleepRegularityScore < 50 {
            result.append("Your Sleep Regularity score is low (\(Int(sleepRegularityScore))). The most regular sleepers have 30% lower all-cause mortality (Windred et al., 2024). Keep bed/wake times within 30 min daily.")
        }

        // Optimal sleep window
        if let window = optimalBedtimeWindow {
            result.append("Your data shows best recovery when you go to bed between \(window.start)-\(window.end). Try to hit this window consistently.")
        }

        // Awake time
        let avgAwake = last7Nights.isEmpty ? 0.0 : last7Nights.reduce(0.0) { $0 + $1.totalAwakeTime } / Double(last7Nights.count)
        if avgAwake > 45 * 60 {
            result.append("Excessive wake-after-sleep-onset (\(Int(avgAwake / 60)) min avg). If you can't fall back asleep in 20 min, get up and do something calming until sleepy.")
        }

        if result.isEmpty {
            result.append("Your sleep metrics are looking strong. Maintain your current routine and stay consistent.")
        }

        return Array(result.prefix(5))
    }

    // MARK: - Card Views

    private var recoveryReadinessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Recovery Readiness")
                    .font(.headline)
            } icon: {
                Image(systemName: "heart.circle.fill")
                    .foregroundColor(recoveryColor)
            }

            Text("Composite: HRV (35%) + RHR (25%) + Duration (25%) + Debt (15%)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recoveryLabel)
                        .font(.system(.title3, design: .rounded))
                        .bold()
                        .foregroundColor(recoveryColor)
                    if let lastNight = nights.first {
                        Text("Based on last night's data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("HRV").font(.caption2).foregroundColor(.secondary)
                                Text("\(Int(lastNight.hrv)) ms").font(.caption).bold()
                            }
                            VStack(alignment: .leading) {
                                Text("RHR").font(.caption2).foregroundColor(.secondary)
                                Text("\(Int(lastNight.restingHeartRate)) bpm").font(.caption).bold()
                            }
                        }
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(recoveryReadinessScore) / 100.0)
                        .stroke(recoveryColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    Text("\(recoveryReadinessScore)")
                        .font(.system(.title2, design: .rounded))
                        .bold()
                }
                .accessibilityLabel("Recovery score \(recoveryReadinessScore) out of 100, \(recoveryLabel)")
            }

            let confidence = recoveryConfidence
            if confidence.sd > 0 {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "waveform.path")
                        .font(.caption)
                        .foregroundColor(confidence.color)
                    Text("\(confidence.label) (\u{00B1}\(String(format: "%.0f", confidence.sd)))")
                        .font(.caption)
                        .bold()
                        .foregroundColor(confidence.color)
                    Spacer()
                    Text("Based on 7-day recovery variability")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Weekly Summary")
                    .font(.headline)
            } icon: {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
            }

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("Avg Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(avgSleepDuration7))
                        .font(.system(.title3, design: .rounded))
                        .bold()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Avg Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(avgSleepScore7))")
                        .font(.system(.title3, design: .rounded))
                        .bold()
                        .foregroundColor(scoreColor(Int(avgSleepScore7)))
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Efficiency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", avgSleepEfficiency7))
                        .font(.system(.title3, design: .rounded))
                        .bold()
                        .foregroundColor(sleepEfficiencyColor)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var trendIndicatorsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("7-Day Trends")
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
            }

            Text("Last 7 days vs prior 7 days")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 0) {
                trendItem(title: "Sleep Score", direction: sleepScoreTrend)
                    .frame(maxWidth: .infinity)
                trendItem(title: "HRV", direction: hrvTrend)
                    .frame(maxWidth: .infinity)
                trendItem(title: "RHR", direction: rhrTrend)
                    .frame(maxWidth: .infinity)
            }

            Text(hrvPatternDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(cardBackground)
    }

    private func trendItem(title: String, direction: TrendDirection) -> some View {
        VStack(spacing: 6) {
            Image(systemName: direction.symbolName)
                .font(.title2)
                .foregroundColor(direction.color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(direction.label)
                .font(.caption2)
                .foregroundColor(direction.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) trend: \(direction.label)")
    }

    private var autonomicBalanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Autonomic Balance")
                    .font(.headline)
            } icon: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.cyan)
            }

            Text("Normalized ANS index using personal baselines")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if autonomicBalanceIndex > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", autonomicBalanceIndex))
                                .font(.system(.title2, design: .rounded))
                                .bold()
                                .foregroundColor(abiColor)
                            Text("ABI")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(abiLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Raw HRV:RHR \(String(format: "%.2f", autonomicBalanceRatio))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("14-day avg ratio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f", avgAutonomicBalance))
                            .font(.system(.body, design: .rounded))
                            .bold()
                        if hrvCV > 0 {
                            Text("HRV CV: \(Int(hrvCV))%")
                                .font(.caption)
                                .foregroundColor(hrvCV > 15 ? .orange : .green)
                        }
                    }
                }
            } else {
                Text("Insufficient HRV/RHR data")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var sleepEfficiencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Sleep Efficiency")
                    .font(.headline)
            } icon: {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .foregroundColor(.teal)
            }

            Text("Time asleep / time in bed (AASM: 85-95% optimal)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", avgSleepEfficiency7))
                            .font(.system(.title2, design: .rounded))
                            .bold()
                            .foregroundColor(sleepEfficiencyColor)
                        Text("%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(sleepEfficiencyLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Efficiency bar
                VStack(alignment: .trailing, spacing: 4) {
                    Text("7-night avg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let avgAwake = last7Nights.isEmpty ? 0.0 : last7Nights.reduce(0.0) { $0 + $1.totalAwakeTime } / Double(last7Nights.count)
                    Text("Avg awake: \(Int(avgAwake / 60)) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var sleepDebtCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Sleep Debt")
                    .font(.headline)
            } icon: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
            }

            Text("Rolling 14-day deficit vs \(sleepGoalMinutes / 60)h \(sleepGoalMinutes % 60)m goal")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f hours", sleepDebtHours))
                        .font(.system(.title2, design: .rounded))
                        .bold()
                        .foregroundColor(debtColor)
                    Text(debtDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if sleepDebtHours >= 20.0 {
                        Text("Capped at 20h per sleep debt recovery research (Kitamura et al. 2016)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(1.0, CGFloat(sleepDebtHours) / 20.0))
                        .stroke(debtColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var debtColor: Color {
        if sleepDebtHours < 1 { return .green }
        if sleepDebtHours < 3 { return .yellow }
        return .red
    }

    private var debtDescription: String {
        if sleepDebtHours < 1 { return "Well rested" }
        if sleepDebtHours < 3 { return "Moderate debt" }
        if sleepDebtHours < 5 { return "Significant debt" }
        return "Severe debt - recovery priority"
    }

    private var chronotypeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Chronotype")
                    .font(.headline)
            } icon: {
                Image(systemName: chronotypeIcon)
                    .foregroundColor(.orange)
            }

            Text("Based on sleep midpoint (Roenneberg MCTQ method)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chronotype)
                        .font(.system(.title3, design: .rounded))
                        .bold()
                    let midpoint = sleepMidpointMinutes
                    var normalizedMid = midpoint
                    let _ = { if normalizedMid >= 24 * 60 { normalizedMid -= 24 * 60 } }()
                    let midHour = Int(normalizedMid) / 60
                    let midMin = Int(normalizedMid) % 60
                    Text("Avg sleep midpoint: \(String(format: "%02d:%02d", midHour, midMin))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var bedtimeConsistencyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Bedtime Consistency")
                    .font(.headline)
            } icon: {
                Image(systemName: "clock.fill")
                    .foregroundColor(.mint)
            }

            Text("Standard deviation over 14 nights")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(bedtimeConsistencyMinutes14))")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                            .foregroundColor(consistencyColor(bedtimeConsistencyMinutes14))
                        Text("min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(consistencyDescription(bedtimeConsistencyMinutes14))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !nights.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Avg Bedtime")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(averageBedtimeString)
                            .font(.system(.body, design: .rounded))
                            .bold()
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var socialJetLagCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Social Jet Lag")
                    .font(.headline)
            } icon: {
                Image(systemName: "airplane.departure")
                    .foregroundColor(.pink)
            }

            Text("Rest day vs work day sleep midpoint shift")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(socialJetLagMinutes))")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                            .foregroundColor(socialJetLagColor)
                        Text("min")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(socialJetLagLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Target: < 60 min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if socialJetLagMinutes > 60 {
                        Text("Health risk")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var sleepRegularityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Sleep Regularity")
                    .font(.headline)
            } icon: {
                Image(systemName: "metronome.fill")
                    .foregroundColor(.indigo)
            }

            Text("Consistency predicts health better than duration (Windred 2024)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(sleepRegularityScore))")
                            .font(.system(.title2, design: .rounded))
                            .bold()
                            .foregroundColor(regularityColor)
                        Text("/ 100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(regularityLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing) {
                            Text("Bedtime")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("±\(Int(bedtimeConsistencyMinutes14))m")
                                .font(.caption)
                                .bold()
                        }
                        VStack(alignment: .trailing) {
                            Text("Wake")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("±\(Int(wakeTimeVariabilityMinutes))m")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var optimalSleepWindowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Optimal Sleep Window")
                    .font(.headline)
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
            }

            Text("Based on nights with your best HRV recovery")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            if let window = optimalBedtimeWindow {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(window.start) – \(window.end)")
                                .font(.system(.title3, design: .rounded))
                                .bold()
                        }
                        Text("Bedtime window for best recovery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bed.double.fill")
                        .font(.title2)
                        .foregroundColor(.yellow.opacity(0.7))
                }
            } else {
                Text("Need 14+ nights of data to calculate")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var personalizedTipsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Recommendations")
                    .font(.headline)
            } icon: {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundColor(.purple)
            }

            Divider()

            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.purple))
                    Text(tip)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var correlationInsightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Pattern Detection")
                    .font(.headline)
            } icon: {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.cyan)
            }

            Text("Correlations found in your sleep data")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ForEach(Array(correlationInsights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(insight)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var historicalComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Week over Week")
                    .font(.headline)
            } icon: {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.blue)
            }

            Divider()

            if let comparison = weekOverWeekComparison {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(comparison.thisWeek.avgScore))")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                        Text("score")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("")
                            .font(.caption)
                        let diff = comparison.thisWeek.avgScore - comparison.lastWeek.avgScore
                        Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.title3)
                            .foregroundColor(diff >= 0 ? .green : .red)
                        Text(String(format: "%+.0f", diff))
                            .font(.caption)
                            .foregroundColor(diff >= 0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("Last Week")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(comparison.lastWeek.avgScore))")
                            .font(.system(.title3, design: .rounded))
                            .bold()
                        Text("score")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 0) {
                    weekComparisonItem(
                        label: "Duration",
                        current: formatDuration(comparison.thisWeek.avgDuration),
                        change: (comparison.thisWeek.avgDuration - comparison.lastWeek.avgDuration) / comparison.lastWeek.avgDuration * 100,
                        higherIsBetter: true
                    )
                    weekComparisonItem(
                        label: "HRV",
                        current: "\(Int(comparison.thisWeek.avgHRV))ms",
                        change: comparison.lastWeek.avgHRV > 0 ? (comparison.thisWeek.avgHRV - comparison.lastWeek.avgHRV) / comparison.lastWeek.avgHRV * 100 : 0,
                        higherIsBetter: true
                    )
                }
            } else {
                Text("Need 14+ nights for week-over-week comparison")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private func weekComparisonItem(label: String, current: String, change: Double, higherIsBetter: Bool) -> some View {
        let isBetter = higherIsBetter ? change >= 0 : change <= 0
        return VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(current)
                .font(.system(.body, design: .rounded))
                .bold()
            Text(String(format: "%+.1f%%", change))
                .font(.caption)
                .foregroundColor(isBetter ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }

    private var dataActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Data & Sharing")
                    .font(.headline)
            } icon: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    exportURL = exportCSV()
                    if exportURL != nil {
                        showingExportSheet = true
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                        Text("Export CSV")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingShareSheet = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.title2)
                        Text("Share Summary")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingReportSheet = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.richtext")
                            .font(.title2)
                        Text("Share Report")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(cardBackground)
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [weeklySummaryText()])
        }
        .sheet(isPresented: $showingReportSheet) {
            ShareSheet(items: [generateReport()])
        }
    }

    // MARK: - Sleep Architecture Card

    private var sleepArchitectureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Sleep Architecture")
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.indigo)
            }

            Text("Ranges based on Ohayon et al. (2004), Carskadon & Dement (2011)")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            if let lastNight = nights.first,
               lastNight.sleepDuration > 0,
               let stages = sleepStagePercentages(for: lastNight),
               (stages.deep + stages.rem + stages.core) > 0 {

                sleepStageBar(deepPct: stages.deep, remPct: stages.rem, corePct: stages.core)

                VStack(alignment: .leading, spacing: 6) {
                    sleepStageRow(label: "Deep", pct: stages.deep, minPct: 13, maxPct: 23, color: .indigo)
                    sleepStageRow(label: "REM", pct: stages.rem, minPct: 20, maxPct: 25, color: .cyan)
                    sleepStageRow(label: "Light", pct: stages.core, minPct: 50, maxPct: 60, color: .blue.opacity(0.5))
                }

                Text("Deep: 13-23% | REM: 20-25% | Light: 50-60%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sleep stage data unavailable")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Sleep stage breakdown requires Apple Watch sleep tracking with detailed stage data (Deep, REM, Core).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private func sleepStageBar(deepPct: Double, remPct: Double, corePct: Double) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                Rectangle()
                    .fill(Color.indigo)
                    .frame(width: geometry.size.width * CGFloat(deepPct / 100))
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: geometry.size.width * CGFloat(remPct / 100))
                Rectangle()
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: geometry.size.width * CGFloat(corePct / 100))
            }
            .cornerRadius(4)
        }
        .frame(height: 20)
    }

    private func sleepStageRow(label: String, pct: Double, minPct: Double, maxPct: Double, color: Color) -> some View {
        let status: (text: String, color: Color) = {
            if pct >= minPct && pct <= maxPct {
                return ("In range", .green)
            } else if pct >= minPct - 5 && pct <= maxPct + 5 {
                return ("Slightly outside", .yellow)
            } else {
                return ("Outside range", .red)
            }
        }()

        return HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .frame(width: 40, alignment: .leading)
            Text(String(format: "%.0f%%", pct))
                .font(.caption)
                .bold()
                .frame(width: 36, alignment: .trailing)
            Text(status.text)
                .font(.caption2)
                .foregroundColor(status.color)
            Spacer()
        }
    }

    // MARK: - Report Generation

    private func generateReport() -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        let today = df.string(from: Date())

        var report = """
        ====================================
         BioPulse Sleep & Recovery Report
         Generated: \(today)
        ====================================

        --- RECOVERY SCORE ---
        Score: \(recoveryReadinessScore)/100 (\(recoveryLabel))
        """

        let confidence = recoveryConfidence
        if confidence.sd > 0 {
            report += "\nConfidence: \(confidence.label) (\u{00B1}\(String(format: "%.0f", confidence.sd)))"
        }

        report += """

        Components: HRV (35%) + RHR (25%) + Duration (25%) + Debt (15%)

        --- SLEEP ARCHITECTURE ---
        """

        if let lastNight = nights.first,
           let stages = sleepStagePercentages(for: lastNight) {
            report += """

            Deep: \(String(format: "%.0f%%", stages.deep)) (target: 13-23%)
            REM: \(String(format: "%.0f%%", stages.rem)) (target: 20-25%)
            Light: \(String(format: "%.0f%%", stages.core)) (target: 50-60%)
            """
        } else {
            report += "\nSleep stage data not available"
        }

        // HRV/RHR trends
        let hrvVals7 = last7Nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        let rhrVals7 = last7Nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        let hrvAvg7 = hrvVals7.isEmpty ? 0.0 : hrvVals7.reduce(0, +) / Double(hrvVals7.count)
        let rhrAvg7 = rhrVals7.isEmpty ? 0.0 : rhrVals7.reduce(0, +) / Double(rhrVals7.count)

        let hrvVals30 = nights.compactMap { $0.hrv > 0 ? $0.hrv : nil }
        let rhrVals30 = nights.compactMap { $0.restingHeartRate > 0 ? $0.restingHeartRate : nil }
        let hrvAvg30 = hrvVals30.isEmpty ? 0.0 : hrvVals30.reduce(0, +) / Double(hrvVals30.count)
        let rhrAvg30 = rhrVals30.isEmpty ? 0.0 : rhrVals30.reduce(0, +) / Double(rhrVals30.count)

        report += """


        --- HRV & RHR TRENDS ---
        HRV  7-day avg: \(String(format: "%.0f", hrvAvg7)) ms (\(hrvTrend.label))
        HRV 30-day avg: \(String(format: "%.0f", hrvAvg30)) ms
        RHR  7-day avg: \(String(format: "%.0f", rhrAvg7)) bpm (\(rhrTrend.label))
        RHR 30-day avg: \(String(format: "%.0f", rhrAvg30)) bpm

        --- SLEEP DEBT ---
        Current debt: \(String(format: "%.1f", sleepDebtHours)) hours (\(debtDescription))
        Goal: \(sleepGoalMinutes / 60)h \(sleepGoalMinutes % 60)m per night

        --- WEEKLY SUMMARY ---
        Avg Duration: \(formatDuration(avgSleepDuration7))
        Avg Score: \(Int(avgSleepScore7))
        Efficiency: \(String(format: "%.0f%%", avgSleepEfficiency7)) (\(sleepEfficiencyLabel))
        Chronotype: \(chronotype)
        Social Jet Lag: \(Int(socialJetLagMinutes)) min (\(socialJetLagLabel))
        Sleep Regularity: \(Int(sleepRegularityScore))/100 (\(regularityLabel))

        --- RECOMMENDATIONS ---
        """

        for (i, tip) in tips.enumerated() {
            report += "\n\(i + 1). \(tip)"
        }

        report += """


        ====================================
        Report generated by BioPulse
        ====================================
        """

        return report
    }

    // MARK: - Sleep Stage Helpers

    private func sleepStagePercentages(for night: HealthDataManager.NightData) -> (deep: Double, rem: Double, core: Double)? {
        // Use Mirror to check if NightData has sleep stage fields
        let mirror = Mirror(reflecting: night)
        var deep: TimeInterval?
        var rem: TimeInterval?
        var core: TimeInterval?
        for child in mirror.children {
            if child.label == "deepSleepDuration", let val = child.value as? TimeInterval, val > 0 { deep = val }
            if child.label == "remSleepDuration", let val = child.value as? TimeInterval, val > 0 { rem = val }
            if child.label == "coreSleepDuration", let val = child.value as? TimeInterval, val > 0 { core = val }
        }
        guard let d = deep, let r = rem, let c = core, night.sleepDuration > 0 else { return nil }
        let total = night.sleepDuration
        return ((d / total) * 100, (r / total) * 100, (c / total) * 100)
    }

    // MARK: - Helpers

    private var averageBedtimeString: String {
        guard !last14Nights.isEmpty else { return "--:--" }
        let avgMinute = last14Nights.map { minuteOfDay(from: $0.sleepStartTime) }.reduce(0, +) / Double(last14Nights.count)
        var normalizedMinutes = avgMinute
        if normalizedMinutes >= 24 * 60 {
            normalizedMinutes -= 24 * 60
        }
        let hour = Int(normalizedMinutes) / 60
        let minute = Int(normalizedMinutes) % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 5)
    }

    private func formatDuration(_ dur: TimeInterval) -> String {
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }

    private func consistencyColor(_ minutes: Double) -> Color {
        if minutes < 30 { return .green }
        if minutes < 60 { return .yellow }
        return .red
    }

    private func consistencyDescription(_ minutes: Double) -> String {
        if minutes < 30 { return "Very consistent schedule" }
        if minutes < 60 { return "Moderately consistent" }
        return "Highly variable schedule"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
