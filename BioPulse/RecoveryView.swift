//
//  RecoveryView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI

struct RecoveryView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var nights: [HealthDataManager.NightData] = []
    @State private var isLoading = false
    @State private var showScrollToTop = false
    @State private var hrvBaseline: Double = 0
    @State private var rhrBaseline: Double = 0
    @State private var showingSettings = false
    @State private var showingInfo = false
    private let initialLoadCount = 10
    private let batchLoadCount = 7

    private var sleepGoalMinutes: Int {
        UserDefaults.standard.integer(forKey: "sleepGoal")
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
                        sleepGoalMinutes: sleepGoalMinutes,
                        hrvBaseline: hrvBaseline,
                        rhrBaseline: rhrBaseline
                    )
                }
                if showScrollToTop {
                    Button(action: {
                        withAnimation {
                            showScrollToTop = false
                        }
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
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
                loadBaselines()
                loadInitialNights()
            }
        }
        .onChange(of: showingSettings) { wasShowing, isShowing in
            if !isShowing && wasShowing {
                loadBaselines()
                loadInitialNights()
            }
        }
    }

    private func loadBaselines() {
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            90, sleepGoalMinutes: sleepGoalMinutes
        ) { fetched in
            let validHRV = fetched.filter { $0.hrv > 0 }.map { $0.hrv }
            if !validHRV.isEmpty {
                hrvBaseline = validHRV.reduce(0, +) / Double(validHRV.count)
            } else {
                hrvBaseline = 50
            }
            let validRHR = fetched.filter { $0.restingHeartRate > 0 }.map {
                $0.restingHeartRate
            }
            if !validRHR.isEmpty {
                rhrBaseline = validRHR.reduce(0, +) / Double(validRHR.count)
            } else {
                rhrBaseline = 60
            }
            isLoading = false
        }
    }

    private func loadInitialNights() {
        if !nights.isEmpty { return }
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            initialLoadCount, sleepGoalMinutes: sleepGoalMinutes
        ) { newNights in
            nights = newNights
            isLoading = false
        }
    }

    private func loadMoreNights() {
        if isLoading { return }
        isLoading = true
        let newTotal = nights.count + batchLoadCount
        healthDataManager.fetchNightsOverLastNDays(
            newTotal, sleepGoalMinutes: sleepGoalMinutes
        ) { newBatch in
            let merged = Set(nights + newBatch)
            nights = merged.sorted { $0.date > $1.date }
            isLoading = false
        }
    }
}

struct MainScrollView: View {
    let nights: [HealthDataManager.NightData]
    let loadMore: () -> Void
    let isLoading: Bool
    @Binding var showScrollToTop: Bool
    let sleepGoalMinutes: Int
    let hrvBaseline: Double
    let rhrBaseline: Double

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                NightsList(
                    nights: nights,
                    loadMore: loadMore,
                    isLoading: isLoading,
                    sleepGoalMinutes: sleepGoalMinutes,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline
                )
            }
            .coordinateSpace(name: "scroll")
            .overlay(
                GeometryReader { g -> Color in
                    let offset = g.frame(in: .named("scroll")).minY
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
            .onChange(of: showScrollToTop) { _, newVal in
                if !newVal {
                    withAnimation {
                        proxy.scrollTo(nights.first?.id, anchor: .top)
                    }
                }
            }
        }
    }
}

struct NightsList: View {
    let nights: [HealthDataManager.NightData]
    let loadMore: () -> Void
    let isLoading: Bool
    let sleepGoalMinutes: Int
    let hrvBaseline: Double
    let rhrBaseline: Double

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(nights) { night in
                NightCardView(
                    nightData: night,
                    sleepGoalMinutes: sleepGoalMinutes,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline
                )
                .padding(.horizontal)
                .id(night.id)
            }
            if !nights.isEmpty && !isLoading {
                Color.clear
                    .frame(height: 20)
                    .onAppear { loadMore() }
            }
            if isLoading {
                ProgressView()
                    .padding()
            }
        }
        .padding(.vertical)
    }
}

struct NightCardView: View {
    let nightData: HealthDataManager.NightData
    let sleepGoalMinutes: Int
    let hrvBaseline: Double
    let rhrBaseline: Double
    
    public init(
        nightData: HealthDataManager.NightData,
        sleepGoalMinutes: Int,
        hrvBaseline: Double,
        rhrBaseline: Double
    ) {
        self.nightData = nightData
        self.sleepGoalMinutes = sleepGoalMinutes
        self.hrvBaseline = hrvBaseline
        self.rhrBaseline = rhrBaseline
    }
    
    @Environment(\.colorScheme) var colorScheme

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
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
            HStack {
                Text(
                    "\(timeFormatter.string(from: nightData.sleepStartTime)) – \(timeFormatter.string(from: nightData.sleepEndTime))"
                )
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
                    if sleepGoalMinutes > 0 {
                        let goalSecs = Double(sleepGoalMinutes) * 60
                        let dev =
                            (nightData.sleepDuration - goalSecs) / goalSecs
                            * 100
                        Text(String(format: "%+.1f%%", dev))
                            .font(.caption)
                            .foregroundColor(dev >= 0 ? .green : .red)
                    }
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
                    if hrvBaseline > 0 {
                        let dev =
                            (nightData.hrv - hrvBaseline) / hrvBaseline * 100
                        Text(String(format: "%+.1f%%", dev))
                            .font(.caption)
                            .foregroundColor(dev >= 0 ? .green : .red)
                    }
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
                    if rhrBaseline > 0 {
                        let dev =
                            (nightData.restingHeartRate - rhrBaseline)
                            / rhrBaseline * 100
                        Text(String(format: "%+.1f%%", dev))
                            .font(.caption)
                            .foregroundColor(dev <= 0 ? .green : .red)
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
                .shadow(color: .gray.opacity(0.2), radius: 5)
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

    private func formatDuration(_ dur: TimeInterval) -> String {
        let h = Int(dur) / 3600
        let m = (Int(dur) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
}
