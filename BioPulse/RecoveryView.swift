//
//  RecoveryView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/14/24.
//

import SwiftUI

struct RecoveryView: View {
    @State private var showingSettings = false
    @State private var showingInfo = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Recovery")
                    .font(.largeTitle)
                    .padding()
            }
            .navigationTitle("Recovery")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingInfo = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
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
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
        }
    }
}
