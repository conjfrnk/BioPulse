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
    @State private var scrollOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    
    private let sleepGoals = Array(stride(from: 5 * 60, through: 12 * 60, by: 15))
    private let itemWidth: CGFloat = 80
    private let itemSpacing: CGFloat = 20
    private var totalItemWidth: CGFloat { itemWidth + itemSpacing }
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Settings Page")
                    .font(.largeTitle)
                    .padding()
                
                Text("Sleep Goal: \(formattedSleepGoal(minutes: selectedSleepGoal))")
                    .font(.headline)
                    .padding(.bottom, 20)
                
                GeometryReader { geometry in
                    let center = geometry.size.width / 2
                    
                    ZStack {
                        // Center box for highlighting selection
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: itemWidth, height: 50)
                            .position(x: center, y: 50)
                        
                        HStack(spacing: itemSpacing) {
                            ForEach(sleepGoals.indices, id: \.self) { index in
                                let goal = sleepGoals[index]
                                
                                VStack {
                                    Text(formattedSleepGoal(minutes: goal))
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(width: itemWidth, height: 50)
                                        .background(Color.clear)
                                }
                                .frame(width: itemWidth, height: 50)
                                .scaleEffect(scaleEffectForItem(at: index, centerX: center))
                                .rotation3DEffect(
                                    rotationAngleForItem(at: index, centerX: center),
                                    axis: (x: 0, y: 1, z: 0),
                                    anchor: .center,
                                    perspective: 0.5
                                )
                                .opacity(opacityForItem(at: index, centerX: center))
                                .onTapGesture {
                                    selectItem(at: index)
                                }
                            }
                        }
                        .padding(.horizontal, (geometry.size.width - itemWidth) / 2)
                        .offset(x: scrollOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    scrollOffset = lastDragValue + value.translation.width
                                }
                                .onEnded { value in
                                    // Update lastDragValue
                                    lastDragValue = scrollOffset
                                    
                                    // Calculate which item is closest to the center
                                    let centerIndex = Int(round(-scrollOffset / totalItemWidth))
                                    let clampedIndex = max(0, min(centerIndex, sleepGoals.count - 1))
                                    
                                    // Disable implicit animations when updating selectedSleepGoal
                                    withTransaction(Transaction(animation: .none)) {
                                        selectedSleepGoal = sleepGoals[clampedIndex]
                                        UserDefaults.standard.set(selectedSleepGoal, forKey: "sleepGoal")
                                    }
                                    
                                    // Animate snapping to the selected item
                                    withAnimation(.easeOut) {
                                        let targetOffset = -CGFloat(clampedIndex) * totalItemWidth
                                        scrollOffset = targetOffset
                                        lastDragValue = scrollOffset
                                    }
                                }
                        )
                    }
                }
                .frame(height: 100)
                
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
                // Retrieve the saved sleep goal or default to 8 hours
                let storedValue = UserDefaults.standard.integer(forKey: "sleepGoal")
                if storedValue != 0, let initialIndex = sleepGoals.firstIndex(of: storedValue) {
                    selectedSleepGoal = storedValue
                    let targetOffset = -CGFloat(initialIndex) * totalItemWidth
                    scrollOffset = targetOffset
                    lastDragValue = scrollOffset
                } else if let initialIndex = sleepGoals.firstIndex(of: 8 * 60) {
                    selectedSleepGoal = 8 * 60
                    let targetOffset = -CGFloat(initialIndex) * totalItemWidth
                    scrollOffset = targetOffset
                    lastDragValue = scrollOffset
                }
            }
        }
    }
    
    // Helper function to format sleep goal
    private func formattedSleepGoal(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
    
    // Functions to calculate scale, rotation, and opacity based on item's position
    private func scaleEffectForItem(at index: Int, centerX: CGFloat) -> CGFloat {
        let itemPosition = CGFloat(index) * totalItemWidth + scrollOffset + ((UIScreen.main.bounds.width - itemWidth) / 2) + (itemWidth / 2)
        let distance = abs(itemPosition - centerX)
        let maxDistance = UIScreen.main.bounds.width / 2
        return max(0.7, 1 - (distance / maxDistance) * 0.3)
    }
    
    private func rotationAngleForItem(at index: Int, centerX: CGFloat) -> Angle {
        let itemPosition = CGFloat(index) * totalItemWidth + scrollOffset + ((UIScreen.main.bounds.width - itemWidth) / 2) + (itemWidth / 2)
        let angle = Double((itemPosition - centerX) / UIScreen.main.bounds.width) * 30
        return Angle(degrees: angle)
    }
    
    private func opacityForItem(at index: Int, centerX: CGFloat) -> Double {
        let itemPosition = CGFloat(index) * totalItemWidth + scrollOffset + ((UIScreen.main.bounds.width - itemWidth) / 2) + (itemWidth / 2)
        let distance = abs(itemPosition - centerX)
        let maxDistance = UIScreen.main.bounds.width / 2
        return Double(max(0.5, 1 - (distance / maxDistance)))
    }
    
    private func selectItem(at index: Int) {
        // Disable implicit animations when updating selectedSleepGoal
        withTransaction(Transaction(animation: .none)) {
            selectedSleepGoal = sleepGoals[index]
            UserDefaults.standard.set(selectedSleepGoal, forKey: "sleepGoal")
        }
        // Animate snapping to the selected item
        withAnimation(.easeOut) {
            let targetOffset = -CGFloat(index) * totalItemWidth
            scrollOffset = targetOffset
            lastDragValue = scrollOffset
        }
    }
}
