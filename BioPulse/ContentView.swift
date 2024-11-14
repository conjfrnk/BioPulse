//
//  ContentView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct ContentView: View {
    @State private var steps: Double = 0.0
    @State private var isAuthorized = false
    private let healthDataManager = HealthDataManager()
    
    var body: some View {
        VStack {
            Text("Steps Today: \(Int(steps))")
                .font(.largeTitle)
                .padding()
            
            if !isAuthorized {
                Button("Request HealthKit Access") {
                    healthDataManager.requestAuthorization { success, error in
                        if success {
                            isAuthorized = true
                        }
                    }
                }
                .padding()
            } else {
                Button("Fetch Step Count") {
                    healthDataManager.fetchStepCount { steps, error in
                        if let steps = steps {
                            DispatchQueue.main.async {
                                self.steps = steps
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}
