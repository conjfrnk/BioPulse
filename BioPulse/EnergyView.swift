//
//  EnergyView.swift
//  BioPulse
//
//  Created by Connor Frank on 1/1/25.
//

import SwiftUI

struct Milestone {
    let title: String
    let start: Date
    let end: Date
}

struct LayoutMilestone: Identifiable {
    let id = UUID()
    let milestone: Milestone
    let offset: CGFloat
    let height: CGFloat
}

struct MilestoneTileView: View {
    let milestone: Milestone
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.15))

            // Time label on the left, Title on the right
            HStack {
                Text(
                    timeString(milestone.start) + " - "
                        + timeString(milestone.end)
                )
                .font(.caption)
                .foregroundColor(.secondary)
                Spacer()
                Text(milestone.title)
                    .font(.headline)
            }
            .padding(8)
        }
        .frame(height: height)
        .onTapGesture {
            debugPrint("[ENERGY] Tapped milestone:", milestone.title)
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct EnergyView: View {
    @StateObject private var healthDataManager = HealthDataManager()

    @State private var nights: [HealthDataManager.NightData] = []
    @State private var isLoading = false

    @State private var showingSettings = false
    @State private var showingInfo = false

    private let cardSpacing: CGFloat = 8
    private let sidePadding: CGFloat = 16
    private let topMargin: CGFloat = 20
    private let bottomMargin: CGFloat = 20

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    let layout = layoutItems(for: geo.size)

                    // Place each tile
                    ForEach(layout) { lm in
                        MilestoneTileView(
                            milestone: lm.milestone,
                            height: lm.height
                        )
                        .padding(.horizontal, sidePadding)
                        .offset(x: 0, y: lm.offset)
                    }

                    // Red line for current time
                    let nowOffset = offsetForCurrentTime(items: layout)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geo.size.width, height: 2)
                        .offset(x: 0, y: nowOffset - 1)
                }
                .navigationBarTitle("Energy", displayMode: .inline)
                //.toolbarBackground(Color.purple, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .navigationBarItems(
                    leading: Button(action: {
                        debugPrint("[ENERGY] Info tapped")
                        showingInfo = true
                    }) {
                        Image(systemName: "info.circle")
                    },
                    trailing: Button(action: {
                        debugPrint("[ENERGY] Settings tapped")
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                )
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showingInfo) {
                    InfoView()
                }
                .onAppear {
                    debugPrint("[ENERGY] onAppear - loadNightData")
                    loadNightData()
                }
            }
        }
    }

    // MARK: - Data

    private func loadNightData() {
        guard !isLoading else {
            debugPrint("[ENERGY] Already loading nights")
            return
        }
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(3, sleepGoalMinutes: 480) {
            fetched in
            debugPrint("[ENERGY] Fetched \(fetched.count) nights")
            nights = fetched
            isLoading = false
        }
    }

    private var dayStart: Date {
        guard
            let latestNight = nights.max(by: {
                $0.sleepEndTime < $1.sleepEndTime
            })
        else {
            debugPrint("[ENERGY] No nights, defaultMorning")
            return defaultMorning()
        }
        return latestNight.sleepEndTime
    }

    private var dayEnd: Date {
        Calendar.current.date(byAdding: .hour, value: 16, to: dayStart)
            ?? defaultNight()
    }

    // A chain from dayStart to dayEnd in segments
    private var chainedMilestones: [Milestone] {
        let c = Calendar.current

        let inertiaStart = dayStart
        let inertiaEnd =
            c.date(byAdding: .hour, value: 1, to: inertiaStart) ?? dayStart

        let morningPeakStart = inertiaEnd
        let morningPeakEnd =
            c.date(byAdding: .hour, value: 2, to: morningPeakStart)
            ?? morningPeakStart

        let afternoonDipStart = morningPeakEnd
        let afternoonDipEnd =
            c.date(byAdding: .hour, value: 4, to: afternoonDipStart)
            ?? afternoonDipStart

        let eveningPeakStart = afternoonDipEnd
        let eveningPeakEnd =
            c.date(byAdding: .hour, value: 2, to: eveningPeakStart)
            ?? eveningPeakStart

        let windDownStart = eveningPeakEnd
        let windDownEnd =
            c.date(byAdding: .hour, value: 2, to: windDownStart)
            ?? windDownStart

        let melatoninStart = windDownEnd
        let melatoninEnd = dayEnd

        let intervals: [Milestone] = [
            Milestone(
                title: "Sleep Inertia", start: inertiaStart,
                end: min(inertiaEnd, dayEnd)),
            Milestone(
                title: "Morning Peak", start: morningPeakStart,
                end: min(morningPeakEnd, dayEnd)),
            Milestone(
                title: "Afternoon Dip", start: afternoonDipStart,
                end: min(afternoonDipEnd, dayEnd)),
            Milestone(
                title: "Evening Peak", start: eveningPeakStart,
                end: min(eveningPeakEnd, dayEnd)),
            Milestone(
                title: "Wind-down", start: windDownStart,
                end: min(windDownEnd, dayEnd)),
            Milestone(
                title: "Melatonin Window", start: melatoninStart,
                end: melatoninEnd),
        ]
        let filtered = intervals.filter { $0.start < $0.end }
        debugPrint("[ENERGY] built chained intervals count:", filtered.count)
        for f in filtered {
            debugPrint("  \(f.title): \(f.start) -> \(f.end)")
        }
        return filtered
    }

    // MARK: - Layout

    private func layoutItems(for size: CGSize) -> [LayoutMilestone] {
        let mils = chainedMilestones
        guard !mils.isEmpty else { return [] }

        let totalDuration = max(0, dayEnd.timeIntervalSince(dayStart))

        // We'll add topMargin + bottomMargin + in-between cardSpacing
        let topMargin: CGFloat = 20
        let bottomMargin: CGFloat = 20
        let spacingCount = max(0, mils.count - 1)
        let totalSpacing =
            (CGFloat(spacingCount) * cardSpacing) + topMargin + bottomMargin
        let availableHeight = size.height - totalSpacing

        var result: [LayoutMilestone] = []
        var runningY: CGFloat = topMargin

        for (index, m) in mils.enumerated() {
            let duration = m.end.timeIntervalSince(m.start)
            let fraction = max(0, duration / totalDuration)
            let tileHeight = fraction * availableHeight

            let layout = LayoutMilestone(
                milestone: m,
                offset: runningY,
                height: tileHeight
            )
            result.append(layout)

            runningY += tileHeight
            if index < mils.count - 1 {
                runningY += cardSpacing
            }
        }
        return result
    }

    private func offsetForCurrentTime(items: [LayoutMilestone]) -> CGFloat {
        guard let lastItem = items.last else { return 20 }  // same as topMargin
        let now = Date()
        let totalDuration = dayEnd.timeIntervalSince(dayStart)
        guard totalDuration > 0 else { return 20 }

        let dt = now.timeIntervalSince(dayStart)
        let fraction = max(0, min(dt / totalDuration, 1))
        let lastBottom = lastItem.offset + lastItem.height
        // We'll place the line fractionally from topMargin..lastBottom
        let topMargin: CGFloat = 20
        let offset = topMargin + fraction * (lastBottom - topMargin)
        return offset
    }

    // MARK: - Defaults

    private func defaultMorning() -> Date {
        let d =
            Calendar.current.date(
                bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        debugPrint("[ENERGY] defaultMorning ->", d)
        return d
    }

    private func defaultNight() -> Date {
        let d =
            Calendar.current.date(
                bySettingHour: 23, minute: 0, second: 0, of: Date())
            ?? Date().addingTimeInterval(57600)
        debugPrint("[ENERGY] defaultNight ->", d)
        return d
    }
}
