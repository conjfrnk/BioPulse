//
//  DataView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI
import Charts

struct DataView: View {
    @State private var showingSettings = false
    @State private var stepsData: [Date: Double] = [:]
    @State private var startDate = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))! // Start of the current week
    @State private var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
    private let healthDataManager = HealthDataManager()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                ScrollView {
                    VStack(alignment: .leading) {
                        
                        // Steps Graph
                        Text("Weekly Steps")
                            .font(.headline)
                            .padding(.top)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(stepsData.keys.sorted(), id: \.self) { date in
                                LineMark(
                                    x: .value("Day", dayLabel(for: date)),
                                    y: .value("Steps", stepsData[date] ?? 0)
                                )
                                .symbol(.circle)
                            }
                        }
                        .chartYScale(domain: 0...(stepsData.values.max() ?? 10000))
                        .frame(height: 200)
                        .padding(.horizontal)
                        
                        HStack {
                            Button(action: loadPreviousWeek) {
                                Text("Previous Week")
                            }
                            Spacer()
                            Button(action: loadNextWeek) {
                                Text("Next Week")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        
                        Divider()
                        
                        // Sleep Stages Graph
                        Text("Last Night's Sleep Stages")
                            .font(.headline)
                            .padding(.top)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(sleepData, id: \.startDate) { data in
                                RectangleMark(
                                    xStart: .value("Start Time", data.startDate),
                                    xEnd: .value("End Time", data.endDate),
                                    y: .value("Stage", data.stage)
                                )
                                .foregroundStyle(by: .value("Stage", data.stage))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: ["Awake", "REM", "Core", "Deep"])
                        }
                        .chartForegroundStyleScale([
                            "Awake": .red,
                            "REM": .blue.opacity(0.5),
                            "Core": .blue,
                            "Deep": .purple
                        ])
                        .frame(height: 200)
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Data")
            .toolbar {
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

    // Load sleep data for the previous night, using only the top data source
    private func loadSleepData() {
        healthDataManager.fetchLastNightSleepData(topSourceOnly: true) { data, error in
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

    // Helper function to format the day label (S, M, T, W, etc.)
    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date).prefix(1).uppercased()
    }
}
