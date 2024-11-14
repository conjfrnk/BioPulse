//
//  ContentView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DataView()
                .tabItem {
                    Image(systemName: "list.dash")
                    Text("Data")
                }
            
            TrendView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Trends")
                }
            
            InsightsView()
                .tabItem {
                    Image(systemName: "lightbulb")
                    Text("Insights")
                }
        }
        .navigationTitle("Health Data")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Action for hamburger menu
                }) {
                    Image(systemName: "line.horizontal.3")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
