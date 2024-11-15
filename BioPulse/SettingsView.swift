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
    @State private var dragOffset: CGFloat = 0.0 // Total offset applied to the items
    @State private var lastDragValue: CGFloat = 0.0

    private let sleepGoals = Array(stride(from: 5 * 60, through: 12 * 60, by: 15)) // 15-minute intervals from 5 to 12 hours
    private let itemWidth: CGFloat = 100 // Width of each item
    private let itemSpacing: CGFloat = 20 // Spacing between items
    private var totalItemWidth: CGFloat { itemWidth + itemSpacing } // Total width per item including spacing

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
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: itemWidth, height: 50)

                    // ScrollView with sleep options
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSpacing) {
                            ForEach(sleepGoals, id: \.self) { goal in
                                Text(formattedSleepGoal(minutes: goal))
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(width: itemWidth, height: 50)
                                    .background(Color.clear)
                                    .cornerRadius(10)
                            }
                        }
                        .offset(x: dragOffset) // Apply total offset
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = lastDragValue + value.translation.width
                                }
                                .onEnded { value in
                                    lastDragValue += value.translation.width

                                    let centerX = UIScreen.main.bounds.width / 2
                                    let index = round((centerX - itemWidth / 2 - dragOffset) / totalItemWidth)
                                    let clampedIndex = max(0, min(sleepGoals.count - 1, Int(index)))

                                    selectedSleepGoal = sleepGoals[clampedIndex]
                                    UserDefaults.standard.set(selectedSleepGoal, forKey: "sleepGoal")

                                    // Animate snapping to center the closest goal
                                    withAnimation {
                                        dragOffset = centerX - itemWidth / 2 - CGFloat(clampedIndex) * totalItemWidth
                                        lastDragValue = dragOffset
                                    }
                                }
                        )
                    }
                }
                .frame(height: 80)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss() // Dismiss the view
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.blue)
                    }
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
            // Set initial dragOffset based on selectedSleepGoal
            if let initialIndex = sleepGoals.firstIndex(of: selectedSleepGoal) {
                let centerX = UIScreen.main.bounds.width / 2
                dragOffset = centerX - itemWidth / 2 - CGFloat(initialIndex) * totalItemWidth
                lastDragValue = dragOffset
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
