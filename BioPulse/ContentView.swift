//
//  ContentView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 2  // Set Energy tab as default
    @State private var healthDataManager = HealthDataManager()
    @State private var authorizationStatus = "Not Requested"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DataView()
                .tabItem {
                    Label("Data", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(0)
            
            TrendView()
                .tabItem {
                    Label("Trends", systemImage: "chart.bar")
                }
                .tag(1)
            
            EnergyView()
                .tabItem {
                    Label("Energy", systemImage: "bolt.heart.fill")
                }
                .tag(2)
            
            RecoveryView()
                .tabItem {
                    Label("Recovery", systemImage: "bed.double")
                }
                .tag(3)
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.text.clipboard.fill")
                }
                .tag(4)
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
