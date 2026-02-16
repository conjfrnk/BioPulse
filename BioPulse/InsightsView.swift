//
//  InsightsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct InsightsView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var nights: [HealthDataManager.NightData] = []
    @State private var isLoading = false
    @State private var showingSettings = false
    @State private var showingInfo = false
    @Environment(\.colorScheme) var colorScheme

    private var sleepGoalMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "sleepGoal")
        return val > 0 ? val : 480
    }

    var body: some View {
        NavigationView {
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
                        trendIndicatorsCard
                        autonomicBalanceCard
                        sleepEfficiencyCard
                        sleepDebtCard
                        chronotypeCard
                        optimalSleepWindowCard
                        bedtimeConsistencyCard
                        sleepRegularityCard
                        socialJetLagCard
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
            nights = fetched.sorted { $0.date > $1.date }
            isLoading = false
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
                self.nights = fetched.sorted { $0.date > $1.date }
                self.isLoading = false
                continuation.resume()
            }
        }
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
        var weekdayMidpoints: [Double] = []
        var weekendMidpoints: [Double] = []

        for night in last14Nights {
            let weekday = cal.component(.weekday, from: night.sleepStartTime)
            let isWeekend = weekday == 1 || weekday == 6 || weekday == 7
            let start = minuteOfDay(from: night.sleepStartTime)
            let durationMin = night.sleepDuration / 60
            let midpoint = start + durationMin / 2

            if isWeekend {
                weekendMidpoints.append(midpoint)
            } else {
                weekdayMidpoints.append(midpoint)
            }
        }

        guard !weekdayMidpoints.isEmpty, !weekendMidpoints.isEmpty else { return 0 }
        let weekdayAvg = weekdayMidpoints.reduce(0, +) / Double(weekdayMidpoints.count)
        let weekendAvg = weekendMidpoints.reduce(0, +) / Double(weekendMidpoints.count)
        return abs(weekendAvg - weekdayAvg)
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
        return totalDeficit / 3600.0
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
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 50, height: 50)
                    Circle()
                        .trim(from: 0, to: min(1.0, CGFloat(sleepDebtHours) / 5.0))
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

            Text("Weekend vs weekday sleep midpoint shift")
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
