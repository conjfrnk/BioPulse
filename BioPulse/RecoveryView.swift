//
//  RecoveryView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI
import HealthKit

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

struct NightCardView: View {
    let nightData: NightData
    
    init(nightData: NightData) {
        self.nightData = nightData
    }
    
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
            HStack {
                Text(dateFormatter.string(from: nightData.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(nightData.sleepScore) / 100)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(nightData.sleepScore)")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            HStack {
                Text("\(timeFormatter.string(from: nightData.sleepStartTime)) - \(timeFormatter.string(from: nightData.sleepEndTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 20) {
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
                }
                
                Spacer()
                
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
                }
                
                Spacer()
                
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
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

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
    }
}

struct NightsList: View {
    let nights: [NightData]
    let loadMore: () -> Void
    let isLoading: Bool
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(nights.sorted(by: { $0.date > $1.date })) { night in
                NightCardView(nightData: night)
                    .padding(.horizontal)
                    .id(night.id)
            }
            
            if !nights.isEmpty && !isLoading {
                Color.clear
                    .frame(height: 20)
                    .onAppear {
                        print("[PAGINATION] Reached bottom of list")
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

struct MainScrollView: View {
    let nights: [NightData]
    let loadMore: () -> Void
    let isLoading: Bool
    @Binding var showScrollToTop: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                NightsList(nights: nights, loadMore: loadMore, isLoading: isLoading)
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
            .onChange(of: showScrollToTop) { oldValue, newValue in
                if !newValue {
                    withAnimation {
                        proxy.scrollTo(nights.first?.id, anchor: .top)
                    }
                }
            }
        }
    }
}

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
    
    private let initialLoadCount = 10
    private let batchLoadCount = 7
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
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
                        showScrollToTop: $showScrollToTop
                    )
                }
                
                if showScrollToTop {
                    ScrollToTopButton(action: {
                        withAnimation {
                            showScrollToTop = false
                        }
                    }, isVisible: $showScrollToTop)
                    .padding(.bottom, 30)
                    .padding(.trailing, 20)
                }
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
                print("[LIFECYCLE] RecoveryView appeared")
                requestHealthKitAuthorization()
            }
        }
    }
    
    private func requestHealthKitAuthorization() {
        print("[AUTH] Requesting HealthKit authorization")
        healthDataManager.requestAuthorization { success, error in
            if success {
                print("[AUTH] HealthKit authorization granted")
                isAuthorized = true
                loadInitialNights()
            } else {
                print("[AUTH] HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                isAuthorized = false
            }
        }
    }
    
    private func loadInitialNights() {
        guard nights.isEmpty else {
            print("[LOAD] Initial nights already loaded")
            return
        }
        
        print("[LOAD] Loading initial nights")
        isLoading = true
        loadNights(count: initialLoadCount) { newNights in
            print("[LOAD] Loaded \(newNights.count) initial nights")
            nights = newNights
            lastLoadedDate = newNights.last?.date ?? Date()
            isLoading = false
        }
    }
    
    private func loadMoreNights() {
        guard !isLoading else {
            print("[LOAD] Already loading more nights, skipping")
            return
        }
        
        print("[LOAD] Loading more nights")
        isLoading = true
        
        loadNights(count: batchLoadCount, startingFrom: lastLoadedDate) { newNights in
            print("[LOAD] Loaded \(newNights.count) additional nights")
            nights.append(contentsOf: newNights)
            lastLoadedDate = newNights.last?.date ?? lastLoadedDate
            isLoading = false
        }
    }
    
    private func loadNights(count: Int, startingFrom: Date = Date(), completion: @escaping ([NightData]) -> Void) {
        print("[LOAD] Starting to load \(count) nights from \(dateFormatter.string(from: startingFrom))")
        let calendar = Calendar.current
        var newNights: [NightData] = []
        let group = DispatchGroup()
        
        var currentDate = startingFrom
        var datesProcessed = 0
        
        // Get the user's sleep goal
        let sleepGoalMinutes = UserDefaults.standard.integer(forKey: "sleepGoal")
        
        while datesProcessed < count {
            let dateToProcess = calendar.startOfDay(for: currentDate)
            let dateString = dateFormatter.string(from: dateToProcess)
            
            if !loadedDates.contains(dateString) {
                print("[LOAD] Processing date: \(dateString)")
                group.enter()
                
                healthDataManager.fetchSleepData(for: dateToProcess) { sleepData, error in
                    if let error = error {
                        print("[ERROR] Sleep data fetch failed for \(dateString): \(error.localizedDescription)")
                        group.leave()
                        return
                    }
                    
                    if let sleepData = sleepData, !sleepData.isEmpty {
                        print("[DATA] Found \(sleepData.count) sleep records for \(dateString)")
                        
                        let sortedSleepData = sleepData.sorted { $0.startDate < $1.startDate }
                        var totalDuration: TimeInterval = 0
                        
                        // Calculate sleep period
                        guard let sleepStart = sortedSleepData.first?.startDate,
                              let sleepEnd = sortedSleepData.last?.endDate else {
                            group.leave()
                            return
                        }
                        
                        // Calculate total sleep duration excluding gaps
                        for (stage, start, end) in sortedSleepData {
                            if stage != "Awake" && stage != "InBed" {
                                let duration = end.timeIntervalSince(start)
                                print("[DURATION] Adding \(duration/3600.0) hours from \(stage)")
                                totalDuration += duration
                            }
                        }
                        
                        // Fetch HRV and RHR specifically during the sleep period
                        healthDataManager.fetchHRVDuringSleep(sleepStart: sleepStart, sleepEnd: sleepEnd) { hrv, hrvError in
                            if let hrvError = hrvError {
                                print("[ERROR] HRV fetch failed: \(hrvError.localizedDescription)")
                            }
                            print("[DATA] HRV value during sleep: \(hrv ?? 0) for \(dateString)")
                            
                            healthDataManager.fetchHeartRateDuringSleep(sleepStart: sleepStart, sleepEnd: sleepEnd) { heartRate, hrError in
                                if let hrError = hrError {
                                    print("[ERROR] Heart rate fetch failed: \(hrError.localizedDescription)")
                                }
                                print("[DATA] Resting heart rate during sleep: \(heartRate ?? 0) for \(dateString)")
                                
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
                                    print("[DATA] Adding night data for \(dateString)")
                                    print("[DATA] Sleep duration: \(totalDuration/3600.0) hours")
                                    print("[DATA] Sleep period: \(sleepStart) to \(sleepEnd)")
                                    loadedDates.insert(dateString)
                                    newNights.append(nightData)
                                }
                                group.leave()
                            }
                        }
                    } else {
                        print("[DATA] No sleep data found for \(dateString)")
                        group.leave()
                    }
                }
                datesProcessed += 1
            } else {
                print("[LOAD] Date \(dateString) already loaded, skipping")
            }
            
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        group.notify(queue: .main) {
            let sortedNights = newNights.sorted { $0.date > $1.date }
            print("[LOAD] Completed loading with \(sortedNights.count) new nights")
            completion(sortedNights)
        }
    }
    
    private func calculateSleepScore(
        sleepData: [(stage: String, startDate: Date, endDate: Date)],
        hrv: Double?,
        rhr: Double?,
        sleepGoalMinutes: Int
    ) -> Int {
        // Initialize base score
        var score = 100
        
        // 1. Calculate total sleep and stage proportions
        let totalSleep = sleepData.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let hoursSlept = totalSleep / 3600
        print("[SCORE] Total sleep duration: \(hoursSlept) hours")
        
        // 2. Score sleep stages
        for stage in ["Deep", "REM", "Core", "Awake"] {
            let stageDuration = sleepData
                .filter { $0.stage == stage }
                .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let proportion = totalSleep > 0 ? stageDuration / totalSleep : 0
            
            switch stage {
            case "Deep":
                if proportion < 0.13 {
                    score -= 15
                    print("[SCORE] Deducting 15 points for insufficient deep sleep (\(Int(proportion * 100))%)")
                }
            case "REM":
                if proportion < 0.20 {
                    score -= 15
                    print("[SCORE] Deducting 15 points for insufficient REM sleep (\(Int(proportion * 100))%)")
                }
            case "Core":
                if proportion < 0.45 {
                    score -= 10
                    print("[SCORE] Deducting 10 points for insufficient core sleep (\(Int(proportion * 100))%)")
                }
            case "Awake":
                if proportion > 0.10 {
                    score -= 10
                    print("[SCORE] Deducting 10 points for excessive wake time (\(Int(proportion * 100))%)")
                }
            default:
                break
            }
        }
        
        // 3. Score total sleep duration relative to goal
        let sleepGoalHours = Double(sleepGoalMinutes) / 60.0
        let durationScore = min(25, Int(25.0 * (hoursSlept / sleepGoalHours)))
        score = score - 25 + durationScore
        print("[SCORE] Sleep duration score: \(durationScore)/25 (Goal: \(sleepGoalHours)h, Actual: \(hoursSlept)h)")
        
        // 4. Score HRV (if available)
        if let hrv = hrv {
            if hrv < 20 {
                score -= 10
                print("[SCORE] Deducting 10 points for very low HRV (\(Int(hrv)) ms)")
            } else if hrv < 30 {
                score -= 5
                print("[SCORE] Deducting 5 points for low HRV (\(Int(hrv)) ms)")
            }
        } else {
            score -= 5
            print("[SCORE] Deducting 5 points for missing HRV data")
        }
        
        // 5. Score RHR (if available)
        if let rhr = rhr {
            if rhr > 80 {
                score -= 10
                print("[SCORE] Deducting 10 points for high RHR (\(Int(rhr)) bpm)")
            } else if rhr > 70 {
                score -= 5
                print("[SCORE] Deducting 5 points for elevated RHR (\(Int(rhr)) bpm)")
            }
        } else {
            score -= 5
            print("[SCORE] Deducting 5 points for missing RHR data")
        }
        
        print("[SCORE] Final sleep score: \(max(0, min(100, score)))")
        return max(0, min(100, score))
    }
}
