//
//  TrendView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct TrendView: View {
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            VStack {
                Text("Trends")
                    .font(.largeTitle)
                    .padding()
            }
            .navigationTitle("Trends")
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
