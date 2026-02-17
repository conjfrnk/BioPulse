//
//  RecoveryView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject var healthDataManager: HealthDataManager
    @Environment(\.colorScheme) var colorScheme
    @State private var nights: [HealthDataManager.NightData] = []
    @State private var isLoading = false
    @State private var showScrollToTop = false
    @State private var hrvBaseline: Double = 0
    @State private var rhrBaseline: Double = 0
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var expandedNight: HealthDataManager.NightData? = nil
    private let initialLoadCount = 10
    private let batchLoadCount = 7

    private var sleepGoalMinutes: Int {
        let val = UserDefaults.standard.integer(forKey: "sleepGoal")
        return val > 0 ? val : 480
    }

    var body: some View {
        NavigationStack {
            ZStack {
                contentView
                    .blur(radius: expandedNight == nil ? 0 : 5)
                if let night = expandedNight {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            expandedNight = nil
                        }
                    ExpandedNightView(nightData: night, last30Nights: Array(nights.prefix(30))) {
                        expandedNight = nil
                    }
                    .transition(.scale)
                    .zIndex(2)
                }
            }
            .navigationTitle("Recovery")
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
                loadBaselines()
                loadInitialNights()
            }
            .refreshable {
                await refreshData()
            }
        }
        .onChange(of: showingSettings) { wasShowing, isShowing in
            if !isShowing && wasShowing {
                loadBaselines()
                loadInitialNights()
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 5)
    }

    private var contentView: some View {
        ZStack(alignment: .bottomTrailing) {
            if nights.isEmpty && isLoading {
                ProgressView("Loading sleep data...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if nights.isEmpty && !isLoading {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                MainScrollView(
                    nights: nights,
                    loadMore: loadMoreNights,
                    isLoading: isLoading,
                    showScrollToTop: $showScrollToTop,
                    sleepGoalMinutes: sleepGoalMinutes,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline,
                    onNightTap: { expandedNight = $0 }
                )
            }
            if showScrollToTop {
                Button {
                    withAnimation {
                        showScrollToTop = false
                    }
                } label: {
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
    }

    private func loadBaselines() {
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            90, sleepGoalMinutes: sleepGoalMinutes
        ) { fetched in
            let validHRV = fetched.filter { $0.hrv > 0 }.map { $0.hrv }
            let validRHR = fetched.filter { $0.restingHeartRate > 0 }.map {
                $0.restingHeartRate
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                if !validHRV.isEmpty {
                    hrvBaseline = validHRV.reduce(0, +) / Double(validHRV.count)
                } else {
                    hrvBaseline = 50
                }
                if !validRHR.isEmpty {
                    rhrBaseline = validRHR.reduce(0, +) / Double(validRHR.count)
                } else {
                    rhrBaseline = 60
                }
                isLoading = false
            }
        }
    }

    private func loadInitialNights() {
        if !nights.isEmpty { return }
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            initialLoadCount, sleepGoalMinutes: sleepGoalMinutes
        ) { newNights in
            withAnimation(.easeInOut(duration: 0.3)) {
                nights = newNights
                isLoading = false
            }
        }
    }

    private func loadMoreNights() {
        if isLoading { return }
        isLoading = true
        let newTotal = nights.count + batchLoadCount
        healthDataManager.fetchNightsOverLastNDays(
            newTotal, sleepGoalMinutes: sleepGoalMinutes
        ) { newBatch in
            withAnimation(.easeInOut(duration: 0.3)) {
                let merged = Set(nights + newBatch)
                nights = merged.sorted { $0.date > $1.date }
                isLoading = false
            }
        }
    }

    @MainActor
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            isLoading = true
            nights = []
            healthDataManager.fetchNightsOverLastNDays(
                90, sleepGoalMinutes: sleepGoalMinutes
            ) { fetched in
                let validHRV = fetched.filter { $0.hrv > 0 }.map { $0.hrv }
                self.hrvBaseline = validHRV.isEmpty ? 50 : validHRV.reduce(0, +) / Double(validHRV.count)
                let validRHR = fetched.filter { $0.restingHeartRate > 0 }.map { $0.restingHeartRate }
                self.rhrBaseline = validRHR.isEmpty ? 60 : validRHR.reduce(0, +) / Double(validRHR.count)

                self.healthDataManager.fetchNightsOverLastNDays(
                    self.initialLoadCount, sleepGoalMinutes: self.sleepGoalMinutes
                ) { newNights in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.nights = newNights
                        self.isLoading = false
                    }
                    continuation.resume()
                }
            }
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
    let onNightTap: (HealthDataManager.NightData) -> Void
    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .shadow(color: .gray.opacity(0.2), radius: 5)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    baselinesCard
                    nightsSection
                }
                .padding(.horizontal)
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

    private var baselinesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Baselines")
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
            }

            Text("90-day rolling averages")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("HRV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(hrvBaseline)) ms")
                        .font(.system(.title3, design: .rounded))
                        .bold()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("RHR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(rhrBaseline)) bpm")
                        .font(.system(.title3, design: .rounded))
                        .bold()
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Sleep Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(sleepGoalMinutes / 60)h \(sleepGoalMinutes % 60)m")
                        .font(.system(.title3, design: .rounded))
                        .bold()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private var nightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Recent Nights")
                    .font(.headline)
            } icon: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(.indigo)
            }
            .padding(.horizontal, 4)

            NightsList(
                nights: nights,
                loadMore: loadMore,
                isLoading: isLoading,
                sleepGoalMinutes: sleepGoalMinutes,
                hrvBaseline: hrvBaseline,
                rhrBaseline: rhrBaseline,
                onNightTap: onNightTap
            )
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
    let onNightTap: (HealthDataManager.NightData) -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(nights) { night in
                NightCardView(
                    nightData: night,
                    sleepGoalMinutes: sleepGoalMinutes,
                    hrvBaseline: hrvBaseline,
                    rhrBaseline: rhrBaseline
                )
                .id(night.id)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .onTapGesture {
                    onNightTap(night)
                }
                .accessibilityHint("Double tap to view detailed breakdown")
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
                .accessibilityLabel("Sleep score \(nightData.sleepScore)")
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
