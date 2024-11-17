//
//  DataView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct DataView: View {
    @State private var showingSettings = false
    @State private var showingInfo = false
    @State private var stepsData: [Date: Double] = [:]
    @State private var startDate = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))! // Start of the current week
    @State private var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
    private let healthDataManager = HealthDataManager()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                ScrollView {
                    VStack(alignment: .leading) {
                        
                        // Steps Chart View
                        StepsChartView(
                            stepsData: $stepsData,
                            startDate: $startDate,
                            loadPreviousWeek: loadPreviousWeek,
                            loadNextWeek: loadNextWeek
                        )
                        
                        Divider()
                        
                        // Sleep Stages Chart View
                        SleepStagesChartView(sleepData: sleepData)
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
                loadStepsData()
                loadSleepData()
            }
        }
    }
    
    // Load steps data for the specified start date (7 days from startDate)
    private func loadStepsData() {
        healthDataManager.fetchWeeklySteps(from: startDate) { data, error in
            if let data = data {
                DispatchQueue.main.async {
                    stepsData = data
                }
            }
        }
    }

    // Load sleep data for the previous night
    private func loadSleepData() {
        // Get today's date for sleep data
        let today = Date()
        healthDataManager.fetchSleepData(for: today) { data, error in
            if let data = data {
                DispatchQueue.main.async {
                    sleepData = data
                }
            }
        }
    }

    // Navigate to the previous week by adjusting the startDate by -7 days
    private func loadPreviousWeek() {
        startDate = Calendar.current.date(byAdding: .day, value: -7, to: startDate)!
        loadStepsData()
    }

    // Navigate to the next week by adjusting the startDate by +7 days
    private func loadNextWeek() {
        startDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        loadStepsData()
    }
}
