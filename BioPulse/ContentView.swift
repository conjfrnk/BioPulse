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
    @State private var tabViewID = UUID() // Unique identifier for TabView refresh
    
    // Define the colors for each tab
    private let tabColors: [UIColor] = [
        UIColor(red: 0.5, green: 0.4, blue: 1.0, alpha: 1.0),  // Data
        UIColor(Color.green),  // Trends
        UIColor(Color.red),    // Energy
        UIColor(Color.blue),   // Recovery
        UIColor(Color.orange)  // Insights
    ]
    
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
        .id(tabViewID) // Force TabView refresh
        .onAppear {
            updateTabBarAppearance(for: selectedTab)
            requestHealthAuthorization()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            updateTabBarAppearance(for: newValue)
            tabViewID = UUID() // Trigger TabView re-render
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
    
    private func updateTabBarAppearance(for selectedIndex: Int) {
        let appearance = UITabBarAppearance()
        appearance.stackedLayoutAppearance.selected.iconColor = tabColors[selectedIndex]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: tabColors[selectedIndex]]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
}
