//
//  SettingsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var healthDataManager = HealthDataManager()
    @State private var authorizationStatus: String = "Not Requested"
    @State private var dataStatus: String = "No Data Fetched"

    var body: some View {
        NavigationView {
            VStack {
                Text("Settings Page")
                    .font(.largeTitle)
                    .padding()
            }
        }
    }
}
