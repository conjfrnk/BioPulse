//
//  TrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct TrendView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var sleepData:
        [(stage: String, startDate: Date, endDate: Date)]?
    @State private var isLoadingSleep = false
    @Environment(\.scenePhase) private var scenePhase

    // Get goal wake time from UserDefaults
    private var goalWakeTime: Date {
        let defaultWakeTime =
            Calendar.current.date(
                bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let timeInterval = UserDefaults.standard.double(forKey: "goalWakeTime")
        // If not set, fall back to 7:00 AM
        return timeInterval == 0
            ? defaultWakeTime : Date(timeIntervalSince1970: timeInterval)
    }

    // Get goal sleep duration from UserDefaults
    private var goalSleepMinutes: Int {
        UserDefaults.standard.integer(forKey: "sleepGoal")
    }

    // Helper to check if goals are not set
    private var isGoalNotSet: Bool {
        let storedSleepGoal = UserDefaults.standard.integer(forKey: "sleepGoal")
        let storedWakeTime = UserDefaults.standard.double(
            forKey: "goalWakeTime")
        return storedSleepGoal == 0 || storedWakeTime == 0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoadingSleep {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                    } else if let sleepData = sleepData, !sleepData.isEmpty {
                        SleepTrendView(
                            sleepData: sleepData,
                            goalSleepMinutes: goalSleepMinutes,
                            goalWakeTime: goalWakeTime
                        )
                    } else {
                        Text("No sleep data available")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }

                    // Add more trend views here as needed
                }
                .padding()
            }
            .navigationTitle("Trends")
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
                print("[TRENDS] View appeared")

                // If user has not set goals, force show Settings
                if isGoalNotSet {
                    showingSettings = true
                } else {
                    loadSleepData()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    print("[TRENDS] Scene became active")
                    // If goals are unset, present settings; else load data
                    if isGoalNotSet {
                        showingSettings = true
                    } else {
                        loadSleepData()
                    }
                }
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    print("[TRENDS] Settings sheet dismissed")
                    // If the user dismissed settings but still hasn't set their goals
                    // we could show it again or wait. For now, let's just re-check:
                    if isGoalNotSet {
                        showingSettings = true
                    } else {
                        loadSleepData()
                    }
                }
            }
            .refreshable {
                print("[TRENDS] Manual refresh triggered")
                await refreshData()
            }
        }
    }

    private func loadSleepData() {
        guard !isLoadingSleep else {
            print("[TRENDS] Already loading sleep data")
            return
        }

        print("[TRENDS] Loading sleep data")
        isLoadingSleep = true
        sleepData = nil  // Clear existing data

        // Load the last 7 days of sleep data
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        loadSleepDataForRange(startDate: startDate, endDate: endDate) { data in
            DispatchQueue.main.async {
                sleepData = data
                isLoadingSleep = false
            }
        }
    }

    private func loadSleepDataForRange(
        startDate: Date, endDate: Date,
        completion: @escaping (
            [(stage: String, startDate: Date, endDate: Date)]
        ) -> Void
    ) {
        var allData: [(stage: String, startDate: Date, endDate: Date)] = []
        let group = DispatchGroup()
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            group.enter()
            healthDataManager.fetchSleepData(for: currentDate) { data, error in
                if let data = data {
                    allData.append(contentsOf: data)
                }
                group.leave()
            }
            currentDate = calendar.date(
                byAdding: .day, value: 1, to: currentDate)!
        }

        group.notify(queue: .main) {
            completion(allData)
        }
    }

    @MainActor
    private func refreshData() async {
        loadSleepData()
    }
}
