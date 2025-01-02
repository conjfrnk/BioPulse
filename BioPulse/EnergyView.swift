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
                        .offset(y: lm.offset)
                    }

                    // Red line for current time
                    if let nowOffset = offsetForCurrentTime(items: layout) {
                        // The line itself
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width, height: 2)
                            .offset(y: nowOffset - 1)

                        // The text for current time (left edge, below line)
                        let currentTimeString = timeString(Date())
                        Text(currentTimeString)
                            .font(.caption)
                            .foregroundColor(.red)
                            // We place it near the left edge, slightly below the line
                            .offset(x: 8, y: nowOffset + 4)
                    }

                    // Dashed green line for goal bedtime (always in Melatonin Window)
                    if let bedtimeOffset = offsetForGoalBedtime(
                        in: layout, containerWidth: geo.size.width)
                    {
                        // The dashed line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: bedtimeOffset))
                            path.addLine(
                                to: CGPoint(x: geo.size.width, y: bedtimeOffset)
                            )
                        }
                        .stroke(
                            style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                        )
                        .foregroundColor(.green)

                        // The text for goal bedtime (centered below line)
                        let bedtimeString = timeString(computeGoalBedtime())
                        Text(bedtimeString)
                            .font(.caption)
                            .foregroundColor(.green)
                            // Place it centered horizontally, below the line
                            .offset(
                                x: geo.size.width / 2
                                    - textWidth(bedtimeString, font: .caption)
                                    / 2,
                                y: bedtimeOffset + 4
                            )
                    }
                }
                .navigationBarTitle("Energy", displayMode: .inline)
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

    // If no nights, default to 7AM..11PM
    private var dayStart: Date {
        guard
            let latestNight = nights.max(by: {
                $0.sleepEndTime < $1.sleepEndTime
            })
        else {
            return defaultMorning()
        }
        return latestNight.sleepEndTime
    }

    private var dayEnd: Date {
        Calendar.current.date(byAdding: .hour, value: 16, to: dayStart)
            ?? defaultNight()
    }

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
        return intervals.filter { $0.start < $0.end }
    }

    // MARK: - Layout

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

    // Convert "now" → offset, skipping tile gaps
    private func offsetForCurrentTime(items: [LayoutMilestone]) -> CGFloat? {
        offsetForTime(Date(), items: items)
    }

    private func offsetForTime(_ date: Date, items: [LayoutMilestone])
        -> CGFloat?
    {
        // if date < dayStart => topMargin
        if date <= dayStart {
            return topMargin
        }
        // if date > dayEnd => offset of last tile's bottom
        if date >= dayEnd, let last = items.last {
            return last.offset + last.height
        }

        let total = dayEnd.timeIntervalSince(dayStart)
        let dt = date.timeIntervalSince(dayStart)
        guard total > 0, dt >= 0 else { return nil }

        var elapsed: TimeInterval = 0

        for (i, lm) in items.enumerated() {
            let msDur = lm.milestone.end.timeIntervalSince(lm.milestone.start)
            if dt >= elapsed && dt <= (elapsed + msDur) {
                let fraction = (dt - elapsed) / msDur
                let offsetInTile = fraction * lm.height
                return lm.offset + offsetInTile
            }
            elapsed += msDur
            // we do not add 'cardSpacing' to 'elapsed' because spacing is purely UI
        }
        return items.last.map { $0.offset + $0.height }
    }

    // MARK: - Goal Bedtime in Melatonin Window

    /**
     We compute a "goal bedtime" then clamp it to the melatonin window. If that window doesn't exist or is zero-length, we won't show the line.
     Return the offset for that bedtime line in [Melatonin Window].
     */
    private func offsetForGoalBedtime(
        in items: [LayoutMilestone], containerWidth: CGFloat
    ) -> CGFloat? {
        // 1) find melatonin window
        guard let melatoninLayout = items.last,
            melatoninLayout.milestone.title == "Melatonin Window"
        else {
            return nil
        }
        let mStart = melatoninLayout.milestone.start
        let mEnd = melatoninLayout.milestone.end
        guard mEnd > mStart else { return nil }

        // 2) compute raw bedtime
        let rawBedtime = computeGoalBedtime()
        // 3) clamp bedtime to [mStart..mEnd]
        let clampedBedtime = min(max(rawBedtime, mStart), mEnd)

        // 4) convert to offset
        return offsetForTime(clampedBedtime, items: items)
    }

    /**
     Example logic for "goal bedtime" => 1 hr before dayEnd
     In a real scenario, we'd factor in sleep debt, user preference, etc.
     */
    private func computeGoalBedtime() -> Date {
        // e.g. 1 hour before dayEnd
        return Calendar.current.date(byAdding: .hour, value: -1, to: dayEnd)
            ?? dayEnd
    }

    // MARK: - Time String + measure

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /**
     Quick measure for text width if you want to center text under a line.
     We create a SwiftUI invisible label & measure in a UIHostingController or
     use the NSString approach. For simplicity, let's do an NSString measure.
     */
    private func textWidth(_ text: String, font: Font) -> CGFloat {
        // We'll approximate by converting Font to a UIFont
        let uiFont: UIFont
        switch font {
        case .caption: uiFont = UIFont.preferredFont(forTextStyle: .caption1)
        case .footnote: uiFont = UIFont.preferredFont(forTextStyle: .footnote)
        default: uiFont = UIFont.preferredFont(forTextStyle: .body)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: uiFont
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
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
