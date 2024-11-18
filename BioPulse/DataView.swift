//
//  DataView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

// Create a proper type for sleep records
struct SleepRecord: Hashable, Identifiable {
    let id = UUID()
    let stage: String
    let startDate: Date
    let endDate: Date
    
    // Custom hash function to ensure uniqueness
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(stage)
        hasher.combine(startDate)
        hasher.combine(endDate)
    }
    
    // Custom equality check
    static func == (lhs: SleepRecord, rhs: SleepRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.stage == rhs.stage &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate
    }
}

struct DataView: View {
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var stepsData: [Date: Double] = [:]
    @State private var sleepData: [SleepRecord]?
    @State private var isLoadingSleep = false
    @State private var isLoadingSteps = false
    // Date for sleep data
    @State private var selectedDate: Date
    // Start date for steps data (start of week)
    @State private var startDate: Date
    
    init(date: Date = Date()) {
        // Initialize selectedDate with the provided date
        _selectedDate = State(initialValue: date)
        // Initialize startDate with the start of the week containing the provided date
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        _startDate = State(initialValue: startOfWeek)
    }
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Steps Chart View
                        VStack(alignment: .leading) {
                            if isLoadingSteps {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            } else {
                                StepsChartView(
                                    stepsData: $stepsData,
                                    startDate: $startDate,
                                    loadPreviousWeek: loadPreviousWeek,
                                    loadNextWeek: loadNextWeek
                                )
                            }
                        }
                        
                        Divider()
                        
                        // Sleep Stages Chart View
                        VStack(alignment: .leading) {
                            if isLoadingSleep {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                            } else if let sleepData = sleepData, !sleepData.isEmpty {
                                SleepStagesChartView(sleepData: sleepData.map { ($0.stage, $0.startDate, $0.endDate) })
                                    .id(sleepData.hashValue)
                            } else {
                                Text("No sleep data available")
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Data")
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
                print("[DATA] View appeared")
                loadAllData()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    print("[DATA] Scene became active")
                    loadAllData()
                }
            }
            .onChange(of: showingSettings) { wasShowing, isShowing in
                if !isShowing && wasShowing {
                    print("[DATA] Settings sheet dismissed")
                    loadAllData()
                }
            }
            .refreshable {
                print("[DATA] Manual refresh triggered")
                await refreshData()
            }
        }
    }
    
    private func loadAllData() {
        loadStepsData()
        loadSleepData()
    }
    
    @MainActor
    private func refreshData() async {
        loadAllData()
    }
    
    private func loadStepsData() {
        guard !isLoadingSteps else {
            print("[STEPS] Already loading steps data")
            return
        }
        
        print("[STEPS] Loading steps data for week starting \(startDate)")
        isLoadingSteps = true
        
        healthDataManager.fetchWeeklySteps(from: startDate) { data, error in
            if let error = error {
                print("[STEPS] Error loading steps data: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                if let data = data {
                    print("[STEPS] Loaded \(data.count) days of step data")
                    stepsData = data
                }
                isLoadingSteps = false
            }
        }
    }
    
    private func loadSleepData() {
        guard !isLoadingSleep else {
            print("[SLEEP] Already loading sleep data")
            return
        }
        
        print("[SLEEP] Loading sleep data")
        isLoadingSleep = true
        sleepData = nil  // Clear existing data
        
        let today = Date()
        healthDataManager.fetchSleepData(for: today) { data, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[SLEEP] Error loading sleep data: \(error.localizedDescription)")
                }
                
                if let data = data {
                    print("[SLEEP] Loaded \(data.count) sleep records")
                    // Convert tuple data to SleepRecord objects and sort
                    let records = data.map { SleepRecord(stage: $0.stage, startDate: $0.startDate, endDate: $0.endDate) }
                    sleepData = records.sorted { $0.startDate < $1.startDate }
                    
                    if let first = records.first?.startDate, let last = records.last?.endDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        print("[SLEEP] Sleep period: \(formatter.string(from: first)) to \(formatter.string(from: last))")
                    }
                } else {
                    print("[SLEEP] No sleep data received")
                }
                
                isLoadingSleep = false
            }
        }
    }
    
    private func loadPreviousWeek() {
        startDate = Calendar.current.date(byAdding: .day, value: -7, to: startDate)!
        loadStepsData()
    }
    
    private func loadNextWeek() {
        startDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        loadStepsData()
    }
}
