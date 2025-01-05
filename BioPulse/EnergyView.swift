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
                    "\(timeString(milestone.start)) - \(timeString(milestone.end))"
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
    @State private var userSleepGoal: Int = 0
    @State private var dailyDebtDelta: [Date: Double] = [:]
    @State private var totalDebt: TimeInterval = 0
    @State private var averageHRV: Double = 0

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

                    // 1) Draw "perfect readiness" line (grey, behind)
                    let idealAnchors = anchorPoints(
                        for: layout,
                        in: geo.size,
                        readiness: 1.0
                    )
                    Path { path in
                        guard idealAnchors.count > 1 else { return }
                        catmullRomPath(path: &path, anchors: idealAnchors)
                    }
                    .stroke(
                        Color.gray.opacity(0.25),
                        style: StrokeStyle(
                            lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .zIndex(0)

                    // 2) Draw user's readiness line (purple, front)
                    let userAnchors = anchorPoints(
                        for: layout,
                        in: geo.size,
                        readiness: readinessFactor()
                    )
                    Path { path in
                        guard userAnchors.count > 1 else { return }
                        catmullRomPath(path: &path, anchors: userAnchors)
                    }
                    .stroke(
                        Color.purple.opacity(0.75),
                        style: StrokeStyle(
                            lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .zIndex(1)

                    // 3) Place milestones
                    ForEach(layout) { lm in
                        MilestoneTileView(
                            milestone: lm.milestone,
                            height: lm.height
                        )
                        .padding(.horizontal, sidePadding)
                        .offset(y: lm.offset)
                    }

                    // 4) Red line for current time
                    if let nowOffset = offsetForTime(
                        currentTime, layout: layout)
                    {
                        Rectangle()
                            .fill(Color.red.opacity(0.6))
                            .frame(width: geo.size.width, height: 2)
                            .offset(y: nowOffset - 1)
                        let currentTimeString = timeString(currentTime)
                        Text(currentTimeString)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.6))
                            .offset(x: 8, y: nowOffset + 4)
                    }

                    // 5) Dashed green line for goal bedtime
                    if let bedtimeOffset = offsetForGoalBedtime(
                        layout: layout, width: geo.size.width)
                    {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: bedtimeOffset))
                            p.addLine(
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
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    },
                    trailing: Button {
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
                    loadUserGoal()
                    loadNightData()
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

    private func loadUserGoal() {
        userSleepGoal = UserDefaults.standard.integer(forKey: "sleepGoal")
        if userSleepGoal <= 0 {
            userSleepGoal = 480
        }
    }

    private func loadNightData() {
        guard !isLoading else { return }
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(
            logsDays, sleepGoalMinutes: userSleepGoal
        ) { fetched in
            nights = fetched
            computeDebtData()
            healthDataManager.fetchAverageHRV(lastNDays: 7) { val in
                averageHRV = val ?? 60
                isLoading = false
                let mismatch = computeCircadianMismatch(fetched)
                milestoneFractions = buildDynamicFractions(mismatch: mismatch)
            }
        }
    }

    private func computeDebtData() {
        dailyDebtDelta.removeAll()
        totalDebt = 0
        let goalSec = Double(userSleepGoal) * 60
        let recent = nights.suffix(7)
        for n in recent {
            let diff = goalSec - n.sleepDuration
            let dayKey = Calendar.current.startOfDay(for: n.date)
            dailyDebtDelta[dayKey] = (dailyDebtDelta[dayKey] ?? 0) + diff
        }
        totalDebt = dailyDebtDelta.values.reduce(0, +)
    }

    private func computeCircadianMismatch(_ arr: [HealthDataManager.NightData])
        -> Double
    {
        guard !arr.isEmpty else { return 0 }
        let c = Calendar.current
        let idealWake = c.date(
            bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let wakes = arr.map { $0.sleepEndTime }
        let avgWake = Date(
            timeIntervalSince1970: wakes.map { $0.timeIntervalSince1970 }
                .reduce(0, +) / Double(wakes.count))
        return avgWake.timeIntervalSince(idealWake) / 3600.0
    }

    private func buildDynamicFractions(mismatch: Double) -> [(
        title: String, fraction: Double
    )] {
        var frac = baseFractions
        if mismatch < -1 {
            frac["Sleep Inertia", default: 0] += 0.05
            frac["Morning Peak", default: 0] += 0.05
            frac["Afternoon Dip", default: 0] -= 0.05
            frac["Evening Peak", default: 0] -= 0.05
        }
        if (totalDebt / 3600.0) > 5 {
            frac["Wind-down", default: 0] += 0.05
            frac["Melatonin Window", default: 0] += 0.05
            frac["Afternoon Dip", default: 0] -= 0.05
            frac["Evening Peak", default: 0] -= 0.05
        }
        if averageHRV < 50 {
            frac["Sleep Inertia", default: 0] += 0.03
            frac["Wind-down", default: 0] += 0.02
            frac["Afternoon Dip", default: 0] -= 0.02
            frac["Evening Peak", default: 0] -= 0.03
        }
        let s = frac.values.reduce(0, +)
        if s != 0 {
            for k in frac.keys {
                frac[k]! = max(0, frac[k]! / s)
            }
        }
        for k in frac.keys {
            if frac[k]! < 0 { frac[k]! = 0 }
        }
        let s2 = frac.values.reduce(0, +)
        if s2 != 0 {
            for k in frac.keys {
                frac[k]! /= s2
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
        let length = Double(24) - (Double(userSleepGoal) / 60.0)
        return Calendar.current.date(
            byAdding: .hour, value: Int(length), to: dayStart)
            ?? defaultNight()
    }

    private var chainedMilestones: [Milestone] {
        let sf = milestoneFractions.reduce(0) { $0 + $1.fraction }
        guard sf > 0 else { return [] }
        let dur = dayEnd.timeIntervalSince(dayStart)
        guard dur > 0 else { return [] }
        var res: [Milestone] = []
        var st = 0.0
        for (title, frac) in milestoneFractions {
            let e = st + frac
            let sSec = (st / sf) * dur
            let eSec = (e / sf) * dur
            let msS = dayStart.addingTimeInterval(sSec)
            let msE = dayStart.addingTimeInterval(eSec)
            if msE > msS {
                res.append(Milestone(title: title, start: msS, end: msE))
            }
            st = e
        }
        return res
    }

    private func layoutItems(for size: CGSize) -> [LayoutMilestone] {
        let mils = chainedMilestones
        guard !mils.isEmpty else { return [] }
        let total = dayEnd.timeIntervalSince(dayStart)
        let scount = max(0, mils.count - 1)
        let tSpacing = CGFloat(scount) * cardSpacing + topMargin + bottomMargin
        let avail = size.height - tSpacing
        var out: [LayoutMilestone] = []
        var runY: CGFloat = topMargin
        for (i, m) in mils.enumerated() {
            let d = m.end.timeIntervalSince(m.start)
            let f = d / total
            let h = f * avail
            out.append(LayoutMilestone(milestone: m, offset: runY, height: h))
            runY += h
            if i < mils.count - 1 {
                runY += cardSpacing
            }
        }
        return out
    }

    private func anchorPoints(
        for layout: [LayoutMilestone],
        in size: CGSize,
        readiness: CGFloat
    ) -> [CGPoint] {
        if layout.isEmpty { return [] }
        let wMin = size.width * 0.15
        let wMax = size.width * 0.75
        let xMap: [String: CGFloat] = [
            "Sleep Inertia": 0.15,
            "Morning Peak": 1.0,
            "Afternoon Dip": 0.65,
            "Evening Peak": 0.85,
            "Wind-down": 0.45,
            "Melatonin Window": 0.15,
        ]
        let out: [CGPoint] = layout.map {
            let my = $0.offset + $0.height * 0.5
            let baseFrac = xMap[$0.milestone.title] ?? 0.15
            let d = baseFrac - 0.15
            let scaled = d * readiness
            let finalFrac = 0.15 + scaled
            let xv = wMin + finalFrac * (wMax - wMin)
            return CGPoint(x: xv, y: my)
        }
        return out
    }

    private func readinessFactor() -> CGFloat {
        let lastScore = nights.last?.sleepScore ?? 100
        let rf = CGFloat(lastScore) / 100.0
        let dh = compute14DaySleepDebt(nights) / 3600.0
        let c = min(dh, 6.0)
        let df = 1.0 - (c * 0.05)
        let raw = rf * CGFloat(df)
        return max(0, min(1, raw))
    }

    private func catmullRomPath(path: inout Path, anchors: [CGPoint]) {
        let p = [anchors[0]] + anchors + [anchors.last!]
        path.move(to: p[1])
        for i in 1..<p.count - 2 {
            let p0 = p[i - 1]
            let p1 = p[i]
            let p2 = p[i + 1]
            let p3 = p[i + 2]
            let t: CGFloat = 0.85
            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * t / 6,
                y: p1.y + (p2.y - p0.y) * t / 6
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * t / 6,
                y: p2.y - (p3.y - p1.y) * t / 6
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
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
        var e: TimeInterval = 0
        for lm in layout {
            let msDur = lm.milestone.end.timeIntervalSince(lm.milestone.start)
            if dt >= e && dt <= e + msDur {
                let f = (dt - e) / msDur
                return lm.offset + CGFloat(f) * lm.height
            }
            e += msDur
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
        else { return nil }
        let s = mel.milestone.start
        let e = mel.milestone.end
        if e <= s { return nil }
        let rawBed = computeRawGoalBedtime()
        let cb = min(max(rawBed, s), e)
        return offsetForTime(cb, layout: layout)
    }

    private func computeRawGoalBedtime() -> Date {
        let dh = compute14DaySleepDebt(nights)
        let shiftSec = min(3600, dh * 600)
        let normalBed =
            Calendar.current.date(byAdding: .hour, value: -1, to: dayEnd)
            ?? dayEnd
        return normalBed.addingTimeInterval(-shiftSec)
    }

    private func compute14DaySleepDebt(_ nights: [HealthDataManager.NightData])
        -> Double
    {
        let recent = nights.suffix(14)
        guard !recent.isEmpty else { return 0 }
        let goalSec = Double(userSleepGoal) * 60
        var total: Double = 0
        for n in recent {
            let diff = goalSec - n.sleepDuration
            if diff > 0 {
                total += diff
            }
        }
        return total
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func textWidth(_ text: String, font: Font) -> CGFloat {
        let uiFont: UIFont
        switch font {
        case .caption: uiFont = UIFont.preferredFont(forTextStyle: .caption1)
        case .footnote: uiFont = UIFont.preferredFont(forTextStyle: .footnote)
        default: uiFont = UIFont.preferredFont(forTextStyle: .body)
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: uiFont]
        return (text as NSString).size(withAttributes: attrs).width
    }

    private func defaultMorning() -> Date {
        Calendar.current.date(
            bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func defaultNight() -> Date {
        Calendar.current.date(
            bySettingHour: 23, minute: 0, second: 0, of: Date())
            ?? Date().addingTimeInterval(57600)
    }
}
