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

// A tile/card that displays one milestone
struct MilestoneCardView: View {
    let milestone: Milestone
    let colorOpacity: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(
                    "\(timeString(milestone.start)) - \(timeString(milestone.end))"
                )
                .font(.headline)
                Spacer()
                Text(milestone.title)
                    .font(.headline)
            }
            // You can add more detail here if needed
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(colorOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            // Future: navigate to detail, or show an alert, etc.
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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if milestones.isEmpty {
                    Text("No energy milestones to display")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(
                                Array(milestones.enumerated()), id: \.offset
                            ) { (index, m) in
                                MilestoneCardView(
                                    milestone: m,
                                    colorOpacity: 0.1 + 0.1 * Double(index)
                                )
                                .padding(.horizontal)
                                // Could add .id(m.start) if you want unique IDs
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Energy")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        debugPrint("[ENERGY] Info button tapped")
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        debugPrint("[ENERGY] Settings button tapped")
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
                debugPrint("[ENERGY] onAppear called")
                loadNightData()
            }
        }
    }

    // The day’s start is the user’s latest wake time
    private var dayStart: Date {
        guard
            let latestNight = nights.sorted(by: {
                $0.sleepEndTime > $1.sleepEndTime
            }).first
        else {
            debugPrint("[ENERGY] No nights found, using defaultMorning()")
            return defaultMorning()
        }
        debugPrint(
            "[ENERGY] dayStart from last wake:", latestNight.sleepEndTime)
        return latestNight.sleepEndTime
    }

    // 16 hours after dayStart
    private var dayEnd: Date {
        let d =
            Calendar.current.date(byAdding: .hour, value: 16, to: dayStart)
            ?? defaultNight()
        debugPrint("[ENERGY] dayEnd (dayStart +16h):", d)
        return d
    }

    // Example milestones (non-overlapping)
    private var milestones: [Milestone] {
        // If dayStart >= dayEnd, no intervals
        guard dayStart < dayEnd else {
            debugPrint("[ENERGY] dayStart >= dayEnd, no milestones.")
            return []
        }
        let c = Calendar.current
        // You can adjust these time offsets or logic as needed
        let inertiaEnd =
            c.date(byAdding: .hour, value: 1, to: dayStart) ?? dayStart
        let morningPeak =
            c.date(byAdding: .hour, value: 2, to: dayStart) ?? dayStart
        let morningPeakEnd =
            c.date(byAdding: .hour, value: 3, to: dayStart) ?? dayStart
        let afternoonDip =
            c.date(byAdding: .hour, value: 7, to: dayStart) ?? dayStart
        let afternoonDipEnd =
            c.date(byAdding: .hour, value: 9, to: dayStart) ?? dayStart
        let eveningPeak =
            c.date(byAdding: .hour, value: 10, to: dayStart) ?? dayStart
        let eveningPeakEnd =
            c.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart
        let windDown =
            c.date(byAdding: .hour, value: 14, to: dayStart) ?? dayStart

        let raw: [Milestone] = [
            Milestone(title: "Sleep Inertia", start: dayStart, end: inertiaEnd),
            Milestone(
                title: "Morning Peak", start: morningPeak, end: morningPeakEnd),
            Milestone(
                title: "Afternoon Dip", start: afternoonDip,
                end: afternoonDipEnd),
            Milestone(
                title: "Evening Peak", start: eveningPeak, end: eveningPeakEnd),
            Milestone(title: "Wind-down", start: eveningPeakEnd, end: windDown),
            Milestone(title: "Melatonin Window", start: windDown, end: dayEnd),
        ]
        // Filter out anything that starts after dayEnd
        let filtered = raw.filter { $0.start < dayEnd }
        // Sort by actual start times
        let sorted = filtered.sorted { $0.start < $1.start }
        debugPrint("[ENERGY] Built \(sorted.count) milestones:")
        for m in sorted {
            debugPrint("   \(m.title): \(m.start) -> \(m.end)")
        }
        return sorted
    }

    private func loadNightData() {
        guard !isLoading else {
            debugPrint("[ENERGY] Already loading nights, returning.")
            return
        }
        debugPrint("[ENERGY] loadNightData called")
        isLoading = true
        healthDataManager.fetchNightsOverLastNDays(3, sleepGoalMinutes: 480) {
            fetched in
            debugPrint(
                "[ENERGY] fetchNightsOverLastNDays returned \(fetched.count) nights"
            )
            nights = fetched
            isLoading = false
        }
    }

    private func defaultMorning() -> Date {
        let d =
            Calendar.current.date(
                bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        debugPrint("[ENERGY] defaultMorning:", d)
        return d
    }

    private func defaultNight() -> Date {
        let d =
            Calendar.current.date(
                bySettingHour: 23, minute: 0, second: 0, of: Date())
            ?? Date().addingTimeInterval(57600)
        debugPrint("[ENERGY] defaultNight:", d)
        return d
    }
}
