//
//  ContentView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct ContentView: View {
    @State private var healthDataManager = HealthDataManager()
    @State private var authorizationStatus = "Not Requested"
    
    var body: some View {
        TabView {
            DataView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                    Text("Data")
                }
            
            TrendView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Trends")
                }
            
            EnergyView()
                .tabItem {
                    Image(systemName: "bolt.heart.fill")
                    Text("Energy")
                }
            
            RecoveryView()
                .tabItem {
                    Image(systemName: "bed.double")
                    Text("Recovery")
                }
            
            InsightsView()
                .tabItem {
                    Image(systemName: "chart.line.text.clipboard.fill")
                    Text("Insights")
                }
        }
        .onAppear {
            requestHealthAuthorization()
        }
    }
    
    private func requestHealthAuthorization() {
        healthDataManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                authorizationStatus = success ? "Access Granted" : "Access Denied"
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
