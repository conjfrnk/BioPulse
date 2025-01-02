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

    private let logsDays = 14
    @State private var userSleepGoalHours: Double = 8

    @State private var averageHRV: Double = 60

    @State private var baseFractions: [String: Double] = [
        "Sleep Inertia": 0.05,
        "Morning Peak": 0.15,
        "Afternoon Dip": 0.25,
        "Evening Peak": 0.15,
        "Wind-down": 0.15,
        "Melatonin Window": 0.25,
    ]
    @State private var milestoneFractions: [(title: String, fraction: Double)] =
        []

    private let milestoneOrder = [
        "Sleep Inertia",
        "Morning Peak",
        "Afternoon Dip",
        "Evening Peak",
        "Wind-down",
        "Melatonin Window",
    ]

    private let cardSpacing: CGFloat = 8
    private let sidePadding: CGFloat = 16
    private let topMargin: CGFloat = 20
    private let bottomMargin: CGFloat = 20

    @State private var currentTime = Date()

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    let layout = layoutItems(for: geo.size)

                    ForEach(layout) { lm in
                        MilestoneTileView(
                            milestone: lm.milestone,
                            height: lm.height
                        )
                        .padding(.horizontal, sidePadding)
                        .offset(y: lm.offset)
                    }

                    if let nowOffset = offsetForTime(
                        currentTime, layout: layout)
                    {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width, height: 2)
                            .offset(y: nowOffset - 1)

                        let currentTimeString = timeString(currentTime)
                        Text(currentTimeString)
                            .font(.caption)
                            .foregroundColor(.red)
                            .offset(x: 8, y: nowOffset + 4)
                    }

                    if let bedtimeOffset = offsetForGoalBedtime(
                        layout: layout, width: geo.size.width)
                    {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: bedtimeOffset))
                            path.addLine(
                                to: CGPoint(x: geo.size.width, y: bedtimeOffset)
                            )
                        }
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .foregroundColor(.green)

                        let bedtimeString =
                            "Bedtime: " + timeString(computeRawGoalBedtime())
                        Text(bedtimeString)
                            .font(.caption)
                            .foregroundColor(.green)
                            .offset(
                                x: geo.size.width / 2 - textWidth(
                                    bedtimeString, font: .caption) / 2,
                                y: bedtimeOffset + 4
                            )
                    }
                }
                .navigationBarTitle("Energy", displayMode: .inline)
                .navigationBarItems(
                    leading: Button {
                        debugPrint("[ENERGY] Info tapped")
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    },
                    trailing: Button {
                        debugPrint("[ENERGY] Settings tapped")
                        showingSettings = true
                    } label: {
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
                    loadNightData()
                    loadAverageHRV()
                }
                .onReceive(
                    Timer.publish(every: 10, on: .main, in: .common)
                        .autoconnect()
                ) { _ in
                    currentTime = Date()
                }
            }
        }
    }

    private func loadNightData() {
        guard !isLoading else { return }
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            logsDays,
            sleepGoalMinutes: Int(userSleepGoalHours * 60)
        ) { fetched in
            nights = fetched
            isLoading = false

            let mismatch = computeCircadianMismatch(fetched)
            let debt = compute14DaySleepDebt(fetched)
            milestoneFractions = buildDynamicFractions(
                mismatch: mismatch, debt: debt)
        }
    }

    private func loadAverageHRV() {
        healthDataManager.fetchAverageHRV(lastNDays: 7) { val in
            guard let val = val else {
                averageHRV = 60
                return
            }
            averageHRV = val
        }
    }

    private func computeCircadianMismatch(
        _ nights: [HealthDataManager.NightData]
    ) -> Double {
        guard !nights.isEmpty else { return 0 }
        let c = Calendar.current
        let idealWake = c.date(
            bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let allWakes = nights.map { $0.sleepEndTime }
        let avgWake = Date(
            timeIntervalSince1970:
                allWakes.map { $0.timeIntervalSince1970 }.reduce(0, +)
                / Double(allWakes.count)
        )
        let diff = avgWake.timeIntervalSince(idealWake) / 3600.0
        return diff
    }

    private func compute14DaySleepDebt(_ nights: [HealthDataManager.NightData])
        -> Double
    {
        guard !nights.isEmpty else { return 0 }
        let goalSec = userSleepGoalHours * 3600
        var totalDebtSec = 0.0
        for n in nights {
            let deficit = goalSec - n.sleepDuration
            if deficit > 0 {
                totalDebtSec += deficit
            }
        }
        return totalDebtSec / 3600.0
    }

    private func buildDynamicFractions(mismatch: Double, debt: Double)
        -> [(title: String, fraction: Double)]
    {
        var frac = baseFractions

        if mismatch < -1 {
            frac["Sleep Inertia", default: 0] += 0.05
            frac["Morning Peak", default: 0] += 0.05
            frac["Afternoon Dip", default: 0] -= 0.05
            frac["Evening Peak", default: 0] -= 0.05
        }

        if debt > 5 {
            frac["Wind-down", default: 0] += 0.05
            frac["Melatonin Window", default: 0] += 0.05
            frac["Afternoon Dip", default: 0] -= 0.05
            frac["Evening Peak", default: 0] -= 0.05
        }

        // If average HRV < 50 => user might be fatigued => shift Sleep Inertia / Wind-down
        if averageHRV < 50 {
            frac["Sleep Inertia", default: 0] += 0.03
            frac["Wind-down", default: 0] += 0.02
            frac["Afternoon Dip", default: 0] -= 0.02
            frac["Evening Peak", default: 0] -= 0.03
        }

        let sum = frac.values.reduce(0, +)
        if sum != 0 {
            for k in frac.keys {
                frac[k]! = max(0, frac[k]! / sum)
            }
        }
        for k in frac.keys {
            if frac[k]! < 0 { frac[k]! = 0 }
        }
        let sum2 = frac.values.reduce(0, +)
        if sum2 != 0 {
            for k in frac.keys {
                frac[k]! /= sum2
            }
        }

        var result: [(String, Double)] = []
        for title in milestoneOrder {
            let f = frac[title, default: 0]
            result.append((title, f))
        }
        return result
    }

    private var dayStart: Date {
        guard let latest = nights.max(by: { $0.sleepEndTime < $1.sleepEndTime })
        else {
            return defaultMorning()
        }
        return latest.sleepEndTime
    }

    private var dayEnd: Date {
        let length = 24 - userSleepGoalHours
        return Calendar.current.date(
            byAdding: .hour, value: Int(length), to: dayStart)
            ?? defaultNight()
    }

    private var chainedMilestones: [Milestone] {
        let sumFrac = milestoneFractions.reduce(0) { $0 + $1.fraction }
        guard sumFrac > 0 else { return [] }
        let dayLenSec = dayEnd.timeIntervalSince(dayStart)
        guard dayLenSec > 0 else { return [] }

        var results: [Milestone] = []
        var startFrac = 0.0
        for (title, frac) in milestoneFractions {
            let endFrac = startFrac + frac
            let sSec = (startFrac / sumFrac) * dayLenSec
            let eSec = (endFrac / sumFrac) * dayLenSec
            let msStart = dayStart.addingTimeInterval(sSec)
            let msEnd = dayStart.addingTimeInterval(eSec)
            if msEnd > msStart {
                results.append(
                    Milestone(title: title, start: msStart, end: msEnd))
            }
            startFrac = endFrac
        }
        return results
    }

    private func layoutItems(for size: CGSize) -> [LayoutMilestone] {
        let mils = chainedMilestones
        guard !mils.isEmpty else { return [] }
        let totalDuration = max(0, dayEnd.timeIntervalSince(dayStart))
        let spacingCount = max(0, mils.count - 1)
        let totalSpacing =
            CGFloat(spacingCount) * cardSpacing + topMargin + bottomMargin
        let availableHeight = size.height - totalSpacing

        var result: [LayoutMilestone] = []
        var runningY: CGFloat = topMargin

        for (i, m) in mils.enumerated() {
            let dur = m.end.timeIntervalSince(m.start)
            let frac = dur / totalDuration
            let tileHeight = frac * availableHeight

            let lm = LayoutMilestone(
                milestone: m,
                offset: runningY,
                height: tileHeight
            )
            result.append(lm)
            runningY += tileHeight
            if i < mils.count - 1 {
                runningY += cardSpacing
            }
        }
        return result
    }

    private func offsetForTime(_ date: Date, layout: [LayoutMilestone])
        -> CGFloat?
    {
        if date <= dayStart { return topMargin }
        if date >= dayEnd, let last = layout.last {
            return last.offset + last.height
        }
        let total = dayEnd.timeIntervalSince(dayStart)
        let dt = date.timeIntervalSince(dayStart)
        guard dt >= 0, total > 0 else { return nil }

        var elapsed: TimeInterval = 0
        for lm in layout {
            let msDur = lm.milestone.end.timeIntervalSince(lm.milestone.start)
            if dt >= elapsed && dt <= elapsed + msDur {
                let fraction = (dt - elapsed) / msDur
                let offsetInTile = fraction * lm.height
                return lm.offset + offsetInTile
            }
            elapsed += msDur
        }
        return layout.last.map { $0.offset + $0.height }
    }

    private func offsetForGoalBedtime(layout: [LayoutMilestone], width: CGFloat)
        -> CGFloat?
    {
        guard
            let mel = layout.first(where: {
                $0.milestone.title == "Melatonin Window"
            })
        else {
            return nil
        }
        let s = mel.milestone.start
        let e = mel.milestone.end
        if e <= s { return nil }

        let rawBed = computeRawGoalBedtime()
        let clampBed = min(max(rawBed, s), e)
        return offsetForTime(clampBed, layout: layout)
    }

    private func computeRawGoalBedtime() -> Date {
        let debt = compute14DaySleepDebt(nights)
        let shiftSec = bedtimeShiftFromDebt(debt)
        let normalBed =
            Calendar.current.date(byAdding: .hour, value: -1, to: dayEnd)
            ?? dayEnd
        return normalBed.addingTimeInterval(-shiftSec)
    }

    private func bedtimeShiftFromDebt(_ debtHours: Double) -> TimeInterval {
        let shift = min(3600, debtHours * 600)
        return shift
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func textWidth(_ text: String, font: Font) -> CGFloat {
        let uiFont: UIFont
        switch font {
        case .caption:
            uiFont = UIFont.preferredFont(forTextStyle: .caption1)
        case .footnote:
            uiFont = UIFont.preferredFont(forTextStyle: .footnote)
        default:
            uiFont = UIFont.preferredFont(forTextStyle: .body)
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: uiFont]
        let size = (text as NSString).size(withAttributes: attrs)
        return size.width
    }

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
