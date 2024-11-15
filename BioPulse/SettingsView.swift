//
//  SettingsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSleepGoal: Int = 8 * 60

    private let sleepGoals = Array(stride(from: 5 * 60, through: 12 * 60, by: 15))
    private let itemWidth: CGFloat = 100

    var body: some View {
        NavigationView {
            VStack {
                Text("Settings Page")
                    .font(.largeTitle)
                    .padding()

                Text("Sleep Goal: \(formattedSleepGoal(minutes: selectedSleepGoal))")
                    .font(.headline)

                ZStack {
                    // Center box for highlighting selection
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: itemWidth, height: 50)
                        .zIndex(1) // Ensure it stays above other views

                    TabView(selection: $selectedSleepGoal) {
                        ForEach(sleepGoals, id: \.self) { goal in
                            Text(formattedSleepGoal(minutes: goal))
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: itemWidth, height: 50)
                                .tag(goal)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 50)
                    .onChange(of: selectedSleepGoal) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "sleepGoal")
                    }
                }
                .frame(height: 80)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                let storedValue = UserDefaults.standard.integer(forKey: "sleepGoal")
                if storedValue != 0 {
                    selectedSleepGoal = storedValue
                } else {
                    selectedSleepGoal = 8 * 60 // Default to 8 hours if no goal is set
                }
            }
        }
    }

    // Format the sleep goal to display in hours and minutes
    private func formattedSleepGoal(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
