//
//  DataView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct DataView: View {
    @State private var steps: Double = 0.0
    @State private var sleepHours: Double = 0.0
    @State private var showingSettings = false
    private let healthDataManager = HealthDataManager()

    var body: some View {
        NavigationView {
            VStack {
                Text("Steps Today: \(Int(steps))")
                    .font(.title)
                    .padding()
                
                Text("Sleep Hours: \(sleepHours, specifier: "%.2f")")
                    .font(.title)
                    .padding()
            }
            .onAppear {
                loadData()
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
        }
    }

    private func loadData() {
        healthDataManager.fetchStepCount { steps, error in
            if let steps = steps {
                DispatchQueue.main.async {
                    self.steps = steps
                }
            }
        }
        healthDataManager.fetchSleepData { hours, error in
            if let hours = hours {
                DispatchQueue.main.async {
                    self.sleepHours = hours
                }
            }
        }
    }
}
