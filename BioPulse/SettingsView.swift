//
//  SettingsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var healthDataManager = HealthDataManager()
    @State private var authorizationStatus: String = "Not Requested"
    @State private var dataStatus: String = "No Data Fetched"

    var body: some View {
        NavigationView {
            VStack {
                Text("Settings Page")
                    .font(.largeTitle)
                    .padding()

                Spacer()
                
                Text("Authorization Status: \(authorizationStatus)")
                    .padding(.bottom)
                
                Text("Data Status: \(dataStatus)")
                    .padding(.bottom)

                Spacer()
                
                Button("Request Access") {
                    healthDataManager.requestAuthorization { success, error in
                        DispatchQueue.main.async {
                            authorizationStatus = success ? "Access Granted" : "Access Denied"
                            if let error = error {
                                dataStatus = "Authorization Error: \(error.localizedDescription)"
                            }
                        }
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Fetch Data") {
                    fetchData()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.blue)
            })
        }
    }

    private func fetchData() {
        healthDataManager.fetchStepCount { steps, error in
            DispatchQueue.main.async {
                if let steps = steps {
                    dataStatus = "Steps: \(Int(steps))"
                } else if let error = error {
                    dataStatus = "Error: \(error.localizedDescription)"
                } else {
                    dataStatus = "Unknown error occurred"
                }
            }
        }
    }
}
