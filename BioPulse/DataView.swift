//
//  DataView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct DataView: View {
    private let healthDataManager = HealthDataManager()
    
    @State private var steps: Double = 0.0
    @State private var sleepHours: Double = 0.0
    @State private var isAuthorized = false

    var body: some View {
        VStack {
            if isAuthorized {
                Text("Steps Today: \(Int(steps))")
                    .font(.title)
                    .padding()
                
                Text("Sleep Hours: \(sleepHours, specifier: "%.2f")")
                    .font(.title)
                    .padding()
            } else {
                Text("Requesting HealthKit Access…")
                    .onAppear {
                        healthDataManager.requestAuthorization { success, error in
                            if success {
                                isAuthorized = true
                                loadData()
                            } else {
                                print("HealthKit Authorization Failed")
                            }
                        }
                    }
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
