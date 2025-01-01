//
//  RecoveryView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import HealthKit
import SwiftUI

// MARK: - Model for each "night" of data
struct NightData: Identifiable {
    let id = UUID()
    let date: Date
    let sleepScore: Int
    let hrv: Double
    let restingHeartRate: Double
    let sleepDuration: TimeInterval
    let sleepStartTime: Date
    let sleepEndTime: Date
}

// MARK: - NightCardView (One "card" for a given night's data)
struct NightCardView: View {
    let nightData: NightData
    let sleepBaseline: Double  // average nightly sleep, in seconds
    let hrvBaseline: Double  // average HRV (ms)
    let rhrBaseline: Double  // average RHR (bpm)

    // Explicitly declare an init so Swift doesn’t generate a private memberwise init
    init(
        nightData: NightData,
        sleepBaseline: Double,
        hrvBaseline: Double,
        rhrBaseline: Double
    ) {
        self.nightData = nightData
        self.sleepBaseline = sleepBaseline
        self.hrvBaseline = hrvBaseline
        self.rhrBaseline = rhrBaseline
    }

    @Environment(\.colorScheme) var colorScheme

    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 16) {
            // Header row
            HStack {
                Text(dateFormatter.string(from: nightData.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: CGFloat(nightData.sleepScore) / 100)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Text("\(nightData.sleepScore)")
                        .font(.system(size: 14, weight: .bold))
                }
            }

            // Sleep time range
            HStack {
                Text(
                    "\(timeFormatter.string(from: nightData.sleepStartTime)) - \(timeFormatter.string(from: nightData.sleepEndTime))"
                )
                .font(.caption)
                .foregroundColor(.secondary)
                Spacer()
            }

            // Metrics
            HStack(spacing: 20) {
                // Sleep Duration
                VStack(alignment: .leading) {
                    Label {
                        Text("Sleep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "bed.double.fill")
                            .foregroundColor(.blue)
                    }
                    Text(formatDuration(nightData.sleepDuration))
                        .font(.system(.body, design: .rounded))
                        .bold()

                    if sleepBaseline > 0 {
                        let deviation =
                            (nightData.sleepDuration - sleepBaseline)
                            / sleepBaseline * 100
                        Text(String(format: "%+.1f%%", deviation))
                            .font(.caption)
                            .foregroundColor(deviation >= 0 ? .green : .red)
                    }
                }

                Spacer()

                // HRV
                VStack(alignment: .leading) {
                    Label {
                        Text("HRV")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(.green)
                    }
                    Text("\(Int(nightData.hrv)) ms")
                        .font(.system(.body, design: .rounded))
                        .bold()

                    if hrvBaseline > 0 {
                        let deviation =
                            (nightData.hrv - hrvBaseline) / hrvBaseline * 100
                        Text(String(format: "%+.1f%%", deviation))
                            .font(.caption)
                            .foregroundColor(deviation >= 0 ? .green : .red)
                    }
                }

                Spacer()

                // RHR
                VStack(alignment: .leading) {
                    Label {
                        Text("RHR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } icon: {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                    Text("\(Int(nightData.restingHeartRate)) bpm")
                        .font(.system(.body, design: .rounded))
                        .bold()

                    if rhrBaseline > 0 {
                        let deviation =
                            (nightData.restingHeartRate - rhrBaseline)
                            / rhrBaseline * 100
                        // For RHR, lower is generally better => negative = green
                        Text(String(format: "%+.1f%%", deviation))
                            .font(.caption)
                            .foregroundColor(deviation <= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    colorScheme == .dark
                        ? Color(.systemGray6)
                        : Color(.systemBackground)
                )
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.gray.opacity(0.2),
                    radius: 5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    colorScheme == .dark
                        ? Color.gray.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

// MARK: - ScrollToTopButton
struct ScrollToTopButton: View {
    let action: () -> Void
    @Binding var isVisible: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

// MARK: - NightsList (the main list of nights, triggers loadMore)
struct NightsList: View {
    let nights: [NightData]
    let loadMore: () -> Void
    let isLoading: Bool

    // 90-day baselines
    let sleepBaseline: Double
    let hrvBaseline: Double
    let rhrBaseline: Double

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(nights.sorted(by: { $0.date > $1.date })) { night in
                NightCardView(
                    nightData: night,
                    sleepBaseline: sleepBaseline,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline
                )
                .padding(.horizontal)
                .id(night.id)
            }
            // Infinite scroll trigger
            if !nights.isEmpty && !isLoading {
                Color.clear
                    .frame(height: 20)
                    .onAppear {
                        loadMore()
                    }
            }
            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .padding(.vertical)
    }
}

// MARK: - MainScrollView (wrapping NightsList + 'scroll to top' logic)
struct MainScrollView: View {
    let nights: [NightData]
    let loadMore: () -> Void
    let isLoading: Bool
    @Binding var showScrollToTop: Bool

    // 90-day baselines
    let sleepBaseline: Double
    let hrvBaseline: Double
    let rhrBaseline: Double

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                NightsList(
                    nights: nights,
                    loadMore: loadMore,
                    isLoading: isLoading,
                    sleepBaseline: sleepBaseline,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline
                )
            }
            .scrollDismissesKeyboard(.immediately)
            .coordinateSpace(name: "scroll")
            .overlay(
                GeometryReader { geometry -> Color in
                    let offset = geometry.frame(in: .named("scroll")).minY
                    if offset < -200 && !showScrollToTop {
                        DispatchQueue.main.async {
                            showScrollToTop = true
                        }
                    } else if offset >= -200 && showScrollToTop {
                        DispatchQueue.main.async {
                            showScrollToTop = false
                        }
                    }
                    return Color.clear
                }
            )
            // If user taps "ScrollToTopButton"
            .onChange(of: showScrollToTop) { _, newValue in
                if !newValue {
                    withAnimation {
                        proxy.scrollTo(nights.first?.id, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - The main RecoveryView
struct RecoveryView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var nights: [NightData] = []
    @State private var isLoading = false
    @State private var showScrollToTop = false
    @State private var lastLoadedDate: Date = Date()
    @State private var loadedDates: Set<String> = []
    @State private var isAuthorized = false
    @State private var isLoadingMore = false

    // 90-day baselines
    @State private var sleepBaseline: Double = 0  // average nightly sleep (seconds)
    @State private var hrvBaseline: Double = 0  // ms
    @State private var rhrBaseline: Double = 0  // bpm

    private let initialLoadCount = 10
    private let batchLoadCount = 7
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var isGoalNotSet: Bool {
        let storedSleepGoal = UserDefaults.standard.integer(forKey: "sleepGoal")
        let storedWakeTime = UserDefaults.standard.double(
            forKey: "goalWakeTime")
        return storedSleepGoal == 0 || storedWakeTime == 0
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                if nights.isEmpty && !isLoading {
                    VStack {
                        Text("No data available")
                            .foregroundColor(.secondary)
                    }
                } else {
                    MainScrollView(
                        nights: nights,
                        loadMore: loadMoreNights,
                        isLoading: isLoading,
                        showScrollToTop: $showScrollToTop,
                        sleepBaseline: sleepBaseline,
                        hrvBaseline: hrvBaseline,
                        rhrBaseline: rhrBaseline
                    )
                }

                ScrollToTopButton(
                    action: {
                        withAnimation {
                            showScrollToTop = false
                        }
                    },
                    isVisible: $showScrollToTop
                )
                .padding(.bottom, 30)
                .padding(.trailing, 20)
            }
            .navigationTitle("Recovery")
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
                requestHealthKitAuthorization()
            }
        }
    }

    private func requestHealthKitAuthorization() {
        healthDataManager.requestAuthorization { success, error in
            if success {
                isAuthorized = true
                if isGoalNotSet {
                    showingSettings = true
                } else {
                    // Load 90-day baselines
                    loadBaselines()
                    // Load the initial batch of nights
                    loadInitialNights()
                }
            } else {
                isAuthorized = false
            }
        }
    }

    private func loadBaselines() {
        // 90-day HRV
        healthDataManager.fetchDailyHRVOverLastNDays(90) { data, _ in
            if let data = data, !data.isEmpty {
                let avg = data.values.reduce(0, +) / Double(data.values.count)
                DispatchQueue.main.async {
                    self.hrvBaseline = avg
                }
            }
        }
        // 90-day RHR
        healthDataManager.fetchDailyRestingHROverLastNDays(90) { data, _ in
            if let data = data, !data.isEmpty {
                let avg = data.values.reduce(0, +) / Double(data.values.count)
                DispatchQueue.main.async {
                    self.rhrBaseline = avg
                }
            }
        }
        // 90-day Sleep
        healthDataManager.computeSleepBaselineOverNDays(90) { averageSleep in
            // averageSleep is in seconds
            DispatchQueue.main.async {
                self.sleepBaseline = averageSleep
            }
        }
    }

    private func loadInitialNights() {
        guard nights.isEmpty else {
            return
        }
        isLoading = true
        loadNights(count: initialLoadCount) { newNights in
            nights = newNights
            lastLoadedDate = newNights.last?.date ?? Date()
            isLoading = false
        }
    }

    private func loadMoreNights() {
        guard !isLoading else { return }
        isLoading = true
        loadNights(count: batchLoadCount, startingFrom: lastLoadedDate) {
            newNights in
            nights.append(contentsOf: newNights)
            lastLoadedDate = newNights.last?.date ?? lastLoadedDate
            isLoading = false
        }
    }

    private func loadNights(
        count: Int,
        startingFrom: Date = Date(),
        completion: @escaping ([NightData]) -> Void
    ) {
        let calendar = Calendar.current
        var newNights: [NightData] = []
        let group = DispatchGroup()
        var currentDate = startingFrom
        var datesProcessed = 0

        let sleepGoalMinutes = UserDefaults.standard.integer(
            forKey: "sleepGoal")

        while datesProcessed < count {
            let dateToProcess = calendar.startOfDay(for: currentDate)
            let dateString = dateFormatter.string(from: dateToProcess)
            if !loadedDates.contains(dateString) {
                group.enter()
                healthDataManager.fetchSleepData(for: dateToProcess) {
                    sleepData, _ in
                    if let sleepData = sleepData, !sleepData.isEmpty {
                        let sortedSleepData = sleepData.sorted {
                            $0.startDate < $1.startDate
                        }
                        var totalDuration: TimeInterval = 0
                        guard
                            let sleepStart = sortedSleepData.first?.startDate,
                            let sleepEnd = sortedSleepData.last?.endDate
                        else {
                            group.leave()
                            return
                        }
                        for (stage, start, end) in sortedSleepData {
                            if stage != "Awake" && stage != "InBed" {
                                let duration = end.timeIntervalSince(start)
                                totalDuration += duration
                            }
                        }
                        self.healthDataManager.fetchHRVDuringSleep(
                            sleepStart: sleepStart, sleepEnd: sleepEnd
                        ) { hrv, _ in
                            self.healthDataManager.fetchHeartRateDuringSleep(
                                sleepStart: sleepStart, sleepEnd: sleepEnd
                            ) { heartRate, _ in

                                let score = calculateSleepScore(
                                    sleepData: sleepData,
                                    hrv: hrv,
                                    rhr: heartRate,
                                    sleepGoalMinutes: sleepGoalMinutes
                                )
                                let nightData = NightData(
                                    date: dateToProcess,
                                    sleepScore: score,
                                    hrv: hrv ?? 0,
                                    restingHeartRate: heartRate ?? 0,
                                    sleepDuration: totalDuration,
                                    sleepStartTime: sleepStart,
                                    sleepEndTime: sleepEnd
                                )
                                DispatchQueue.main.async {
                                    loadedDates.insert(dateString)
                                    newNights.append(nightData)
                                }
                                group.leave()
                            }
                        }
                    } else {
                        group.leave()
                    }
                }
                datesProcessed += 1
            }
            // Move to previous day
            if let prevDay = calendar.date(
                byAdding: .day, value: -1, to: currentDate)
            {
                currentDate = prevDay
            } else {
                break
            }
        }

        group.notify(queue: .main) {
            let sortedNights = newNights.sorted { $0.date > $1.date }
            completion(sortedNights)
        }
    }

    // Simple example from your code: combine sleep, HRV, RHR data into a single integer score
    private func calculateSleepScore(
        sleepData: [(stage: String, startDate: Date, endDate: Date)],
        hrv: Double?,
        rhr: Double?,
        sleepGoalMinutes: Int
    ) -> Int {
        var score = 100
        let totalSleepDuration = sleepData.filter {
            $0.stage != "Awake" && $0.stage != "InBed"
        }.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let hoursSlept = totalSleepDuration / 3600

        var stageDurations: [String: TimeInterval] = [:]
        for stage in ["Deep", "REM", "Core", "Awake"] {
            let duration =
                sleepData
                .filter { $0.stage == stage }
                .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            stageDurations[stage] = duration
        }

        // Some simplistic logic
        if totalSleepDuration > 0 {
            let deepPct = (stageDurations["Deep"] ?? 0) / totalSleepDuration
            if deepPct < 0.13 { score -= 15 }

            let remPct = (stageDurations["REM"] ?? 0) / totalSleepDuration
            if remPct < 0.20 { score -= 15 }

            let corePct = (stageDurations["Core"] ?? 0) / totalSleepDuration
            if corePct < 0.45 { score -= 10 }
        }

        let totalTimeInBed = sleepData.reduce(0) {
            $0 + $1.endDate.timeIntervalSince($1.startDate)
        }
        if totalTimeInBed > 0 {
            let awakePct = (stageDurations["Awake"] ?? 0) / totalTimeInBed
            if awakePct > 0.10 { score -= 10 }
        }

        // Sleep duration vs goal
        let sleepGoalHours = Double(sleepGoalMinutes) / 60.0
        let durationScore = min(25, Int(25.0 * (hoursSlept / sleepGoalHours)))
        score = score - 25 + durationScore

        // HRV check
        if let hrv = hrv, hrv < 30 {
            score -= 5
        } else if hrv == nil {
            score -= 5
        }

        // RHR check
        if let rhr = rhr, rhr > 100 {
            score -= 5
        } else if rhr == nil {
            score -= 5
        }

        return max(0, min(100, score))
    }
}
