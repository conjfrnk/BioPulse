//
//  InsightsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct InsightsView: View {
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Insights")
                    .font(.largeTitle)
                    .padding()
            }
            .navigationTitle("Insights")
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
}
