//
//  SettingsView.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSleepGoal: Int = 8 * 60
    @State private var selectedWakeTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var bedtimeNotificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "bedtimeNotificationsEnabled")
    @State private var restDays: Set<Int> = {
        if let stored = UserDefaults.standard.array(forKey: "restDays") as? [Int] {
            return Set(stored)
        }
        return [1, 7] // Sunday, Saturday
    }()
    @State private var sleepScrollOffset: CGFloat = 0
    @State private var wakeScrollOffset: CGFloat = 0
    @State private var lastSleepDragValue: CGFloat = 0
    @State private var lastWakeDragValue: CGFloat = 0
    
    private let sleepGoals = Array(stride(from: 5 * 60, through: 12 * 60, by: 15))
    private let wakeTimeOptions: [Date] = {
        var times: [Date] = []
        let calendar = Calendar.current
        let startTime = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: Date())!
        for minutes in stride(from: 0, through: 12 * 60, by: 15) {
            if let time = calendar.date(byAdding: .minute, value: minutes, to: startTime) {
                times.append(time)
            }
        }
        return times
    }()
    
    private let itemWidth: CGFloat = 80
    private let itemSpacing: CGFloat = 20
    private var totalItemWidth: CGFloat { itemWidth + itemSpacing }
    
    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 40) {
                Text("Settings")
                    .font(.largeTitle)
                    .padding()
                
                // Sleep Goal Section
                VStack(spacing: 16) {
                    Text("Sleep Goal: \(formattedSleepGoal(minutes: selectedSleepGoal))")
                        .font(.headline)
                    
                    GeometryReader { geometry in
                        let center = geometry.size.width / 2
                        ZStack {
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
                                    }
                                    .frame(width: itemWidth, height: 50)
                                    .scaleEffect(scaleEffectForItem(at: index, offset: sleepScrollOffset, centerX: center))
                                    .rotation3DEffect(
                                        rotationAngleForItem(at: index, offset: sleepScrollOffset, centerX: center),
                                        axis: (x: 0, y: 1, z: 0),
                                        anchor: .center,
                                        perspective: 0.5
                                    )
                                    .opacity(opacityForItem(at: index, offset: sleepScrollOffset, centerX: center))
                                    .onTapGesture {
                                        selectSleepGoal(at: index)
                                    }
                                }
                            }
                            .padding(.horizontal, (geometry.size.width - itemWidth) / 2)
                            .offset(x: sleepScrollOffset)
                            .gesture(createDragGesture(for: .sleep))
                        }
                    }
                    .frame(height: 100)
                }
                
                // Wake Time Section
                VStack(spacing: 16) {
                    Text("Goal Wake Time: \(formattedTime(selectedWakeTime))")
                        .font(.headline)
                    
                    GeometryReader { geometry in
                        let center = geometry.size.width / 2
                        ZStack {
                            Rectangle()
                                .stroke(Color.blue, lineWidth: 2)
                                .frame(width: itemWidth, height: 50)
                                .position(x: center, y: 50)
                            
                            HStack(spacing: itemSpacing) {
                                ForEach(wakeTimeOptions.indices, id: \.self) { index in
                                    let time = wakeTimeOptions[index]
                                    VStack {
                                        Text(formattedTime(time))
                                            .font(.system(size: 16, weight: .bold))
                                            .frame(width: itemWidth, height: 50)
                                    }
                                    .frame(width: itemWidth, height: 50)
                                    .scaleEffect(scaleEffectForItem(at: index, offset: wakeScrollOffset, centerX: center))
                                    .rotation3DEffect(
                                        rotationAngleForItem(at: index, offset: wakeScrollOffset, centerX: center),
                                        axis: (x: 0, y: 1, z: 0),
                                        anchor: .center,
                                        perspective: 0.5
                                    )
                                    .opacity(opacityForItem(at: index, offset: wakeScrollOffset, centerX: center))
                                    .onTapGesture {
                                        selectWakeTime(at: index)
                                    }
                                }
                            }
                            .padding(.horizontal, (geometry.size.width - itemWidth) / 2)
                            .offset(x: wakeScrollOffset)
                            .gesture(createDragGesture(for: .wake))
                        }
                    }
                    .frame(height: 100)
                }
                
                // Bedtime Reminder Section
                VStack(spacing: 16) {
                    Toggle(isOn: $bedtimeNotificationsEnabled) {
                        Label {
                            Text("Bedtime Reminder")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.purple)
                        }
                    }
                    .onChange(of: bedtimeNotificationsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "bedtimeNotificationsEnabled")
                        if newValue {
                            NotificationManager.shared.requestAuthorization()
                        } else {
                            NotificationManager.shared.cancelBedtimeReminder()
                        }
                    }

                    if bedtimeNotificationsEnabled {
                        Text("You'll be reminded 30 minutes before your optimal bedtime")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)

                // Rest Days Section
                VStack(spacing: 12) {
                    Text("Rest Days")
                        .font(.headline)
                    Text("Rest days are used to calculate social jet lag. Select the days you typically sleep in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    let weekdays: [(name: String, value: Int)] = [
                        ("Mon", 2), ("Tue", 3), ("Wed", 4), ("Thu", 5),
                        ("Fri", 6), ("Sat", 7), ("Sun", 1),
                    ]
                    HStack(spacing: 8) {
                        ForEach(weekdays, id: \.value) { day in
                            let isSelected = restDays.contains(day.value)
                            Button {
                                if isSelected {
                                    restDays.remove(day.value)
                                } else {
                                    restDays.insert(day.value)
                                }
                                UserDefaults.standard.set(Array(restDays), forKey: "restDays")
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(day.name)
                                    .font(.caption)
                                    .fontWeight(isSelected ? .bold : .regular)
                                    .frame(width: 40, height: 40)
                                    .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            } // ScrollView
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .onAppear {
                initializeSettings()
            }
        }
    }
    
    private enum ScrollType {
        case sleep
        case wake
    }
    
    private func createDragGesture(for type: ScrollType) -> some Gesture {
        DragGesture()
            .onChanged { value in
                switch type {
                case .sleep:
                    sleepScrollOffset = lastSleepDragValue + value.translation.width
                case .wake:
                    wakeScrollOffset = lastWakeDragValue + value.translation.width
                }
            }
            .onEnded { value in
                let totalTranslation = value.translation.width + (value.predictedEndTranslation.width - value.translation.width)
                
                switch type {
                case .sleep:
                    let predictedEndOffset = lastSleepDragValue + totalTranslation
                    var centerIndex = Int(round(-predictedEndOffset / totalItemWidth))
                    centerIndex = max(0, min(centerIndex, sleepGoals.count - 1))
                    
                    withTransaction(Transaction(animation: .none)) {
                        selectedSleepGoal = sleepGoals[centerIndex]
                        UserDefaults.standard.set(selectedSleepGoal, forKey: "sleepGoal")
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                        let targetOffset = -CGFloat(centerIndex) * totalItemWidth
                        sleepScrollOffset = targetOffset
                        lastSleepDragValue = sleepScrollOffset
                    }

                case .wake:
                    let predictedEndOffset = lastWakeDragValue + totalTranslation
                    var centerIndex = Int(round(-predictedEndOffset / totalItemWidth))
                    centerIndex = max(0, min(centerIndex, wakeTimeOptions.count - 1))
                    
                    withTransaction(Transaction(animation: .none)) {
                        selectedWakeTime = wakeTimeOptions[centerIndex]
                        UserDefaults.standard.set(selectedWakeTime.timeIntervalSince1970, forKey: "goalWakeTime")
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
                        let targetOffset = -CGFloat(centerIndex) * totalItemWidth
                        wakeScrollOffset = targetOffset
                        lastWakeDragValue = wakeScrollOffset
                    }
                }
            }
    }
    
    private func initializeSettings() {
        // Initialize sleep goal
        let storedSleepGoal = UserDefaults.standard.integer(forKey: "sleepGoal")
        if storedSleepGoal != 0, let initialIndex = sleepGoals.firstIndex(of: storedSleepGoal) {
            selectedSleepGoal = storedSleepGoal
            let targetOffset = -CGFloat(initialIndex) * totalItemWidth
            sleepScrollOffset = targetOffset
            lastSleepDragValue = sleepScrollOffset
        } else if let initialIndex = sleepGoals.firstIndex(of: 8 * 60) {
            selectedSleepGoal = 8 * 60
            let targetOffset = -CGFloat(initialIndex) * totalItemWidth
            sleepScrollOffset = targetOffset
            lastSleepDragValue = sleepScrollOffset
        }
        
        // Initialize wake time with 7:00 AM default
        let storedWakeTimeInterval = UserDefaults.standard.double(forKey: "goalWakeTime")
        let storedWakeTime: Date
        if storedWakeTimeInterval == 0 {
            // Set default 7:00 AM if not set
            storedWakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
            UserDefaults.standard.set(storedWakeTime.timeIntervalSince1970, forKey: "goalWakeTime")
        } else {
            storedWakeTime = Date(timeIntervalSince1970: storedWakeTimeInterval)
        }
        
        let initialIndex = findClosestWakeTimeIndex(for: storedWakeTime)
        selectedWakeTime = wakeTimeOptions[initialIndex]
        let targetOffset = -CGFloat(initialIndex) * totalItemWidth
        wakeScrollOffset = targetOffset
        lastWakeDragValue = wakeScrollOffset
    }
    
    private func findClosestWakeTimeIndex(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 7) * 60 + (components.minute ?? 0)

        if let exact = wakeTimeOptions.firstIndex(where: { option in
            let optionComponents = calendar.dateComponents([.hour, .minute], from: option)
            let optionMinutes = (optionComponents.hour ?? 0) * 60 + (optionComponents.minute ?? 0)
            return optionMinutes >= minutes
        }) {
            return exact
        }
        // Fall back to middle of array if no match found
        return wakeTimeOptions.count / 2
    }
    
    private func formattedSleepGoal(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func scaleEffectForItem(at index: Int, offset: CGFloat, centerX: CGFloat) -> CGFloat {
        let itemPosition = CGFloat(index) * totalItemWidth + offset + ((UIScreen.main.bounds.width - itemWidth) / 2) + (itemWidth / 2)
        let distance = abs(itemPosition - centerX)
        let maxDistance = UIScreen.main.bounds.width / 2
        return max(0.7, 1 - (distance / maxDistance) * 0.3)
    }
    
    private func rotationAngleForItem(at index: Int, offset: CGFloat, centerX: CGFloat) -> Angle {
        let itemPosition = CGFloat(index) * totalItemWidth + offset + ((UIScreen.main.bounds.width - itemWidth) / 2) + (itemWidth / 2)
        let angle = Double((itemPosition - centerX) / UIScreen.main.bounds.width) * 30
        return Angle(degrees: angle)
    }
    
    private func opacityForItem(at index: Int, offset: CGFloat, centerX: CGFloat) -> Double {
        let itemPosition = CGFloat(index) * totalItemWidth + offset + ((UIScreen.main.bounds.width - itemWidth) / 2) + (itemWidth / 2)
        let distance = abs(itemPosition - centerX)
        let maxDistance = UIScreen.main.bounds.width / 2
        return Double(max(0.5, 1 - (distance / maxDistance)))
    }
    
    private func selectSleepGoal(at index: Int) {
        withTransaction(Transaction(animation: .none)) {
            selectedSleepGoal = sleepGoals[index]
            UserDefaults.standard.set(selectedSleepGoal, forKey: "sleepGoal")
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut) {
            let targetOffset = -CGFloat(index) * totalItemWidth
            sleepScrollOffset = targetOffset
            lastSleepDragValue = sleepScrollOffset
        }
    }
    
    private func selectWakeTime(at index: Int) {
        withTransaction(Transaction(animation: .none)) {
            selectedWakeTime = wakeTimeOptions[index]
            UserDefaults.standard.set(selectedWakeTime.timeIntervalSince1970, forKey: "goalWakeTime")
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut) {
            let targetOffset = -CGFloat(index) * totalItemWidth
            wakeScrollOffset = targetOffset
            lastWakeDragValue = wakeScrollOffset
        }
    }
}
