//
//  OnboardingView.swift
//  BioPulse
//
//  Created by Connor Frank on 2/16/26.
//

import SwiftUI
import HealthKit

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var selectedSleepGoal: Int = 8 * 60
    @State private var selectedWakeTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var healthKitAuthorized = false
    @State private var isAuthorizingHealthKit = false

    private let healthDataManager = HealthDataManager()

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            healthKitPage.tag(1)
            sleepGoalPage.tag(2)
            wakeTimePage.tag(3)
            readyPage.tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            Text("Welcome to BioPulse")
                .font(.largeTitle)
                .bold()

            Text("Science-backed sleep analytics\npowered by your Apple Watch")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 12) {
                featureRow(icon: "bed.double.fill", color: .blue, text: "Track sleep quality and stages")
                featureRow(icon: "heart.fill", color: .red, text: "Monitor HRV and resting heart rate")
                featureRow(icon: "chart.line.uptrend.xyaxis", color: .green, text: "Discover trends and patterns")
                featureRow(icon: "brain.head.profile.fill", color: .purple, text: "Get personalized recommendations")
            }
            .padding(.horizontal, 32)

            Spacer()

            nextButton(text: "Get Started", page: 1)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Page 2: HealthKit

    private var healthKitPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.pink)

            Text("Health Data Access")
                .font(.largeTitle)
                .bold()

            Text("BioPulse reads your sleep, heart rate, and HRV data from Apple Health to provide insights.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                dataRow(icon: "moon.fill", text: "Sleep Analysis")
                dataRow(icon: "waveform.path.ecg", text: "Heart Rate Variability")
                dataRow(icon: "heart.fill", text: "Heart Rate")
                dataRow(icon: "figure.walk", text: "Step Count")
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 16)

            Text("Your data stays on your device and is never shared.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if healthKitAuthorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Access Granted")
                        .foregroundColor(.green)
                }
                .font(.headline)

                nextButton(text: "Continue", page: 2)
                    .padding(.bottom, 40)
            } else {
                Button {
                    isAuthorizingHealthKit = true
                    healthDataManager.requestAuthorization { success, _ in
                        isAuthorizingHealthKit = false
                        healthKitAuthorized = success
                        if success {
                            withAnimation { currentPage = 2 }
                        }
                    }
                } label: {
                    HStack {
                        if isAuthorizingHealthKit {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Allow Health Access")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .disabled(isAuthorizingHealthKit)
            }
        }
    }

    // MARK: - Page 3: Sleep Goal

    private var sleepGoalPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(.indigo)

            Text("Sleep Goal")
                .font(.largeTitle)
                .bold()

            Text("How much sleep do you aim for?")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            Text(formatGoal(selectedSleepGoal))
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Stepper("", value: $selectedSleepGoal, in: 300...720, step: 15)
                .labelsHidden()
                .padding(.horizontal, 100)

            Text("Recommended: 7-9 hours")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            nextButton(text: "Continue", page: 3)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Page 4: Wake Time

    private var wakeTimePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sunrise.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Wake Time")
                .font(.largeTitle)
                .bold()

            Text("When do you usually want to wake up?")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            DatePicker("Wake Time", selection: $selectedWakeTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Spacer()

            nextButton(text: "Continue", page: 4)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Page 5: Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.largeTitle)
                .bold()

            Text("BioPulse will analyze your sleep data and provide personalized insights.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your settings:")
                    .font(.headline)
                Text("Sleep Goal: \(formatGoal(selectedSleepGoal))")
                    .foregroundColor(.secondary)
                Text("Wake Time: \(formatTime(selectedWakeTime))")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Spacer()

            Button {
                // Save settings
                UserDefaults.standard.set(selectedSleepGoal, forKey: "sleepGoal")
                UserDefaults.standard.set(selectedWakeTime.timeIntervalSince1970, forKey: "goalWakeTime")
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Start Using BioPulse")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            Text(text)
                .font(.body)
            Spacer()
        }
    }

    private func dataRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.pink)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }

    private func nextButton(text: String, page: Int) -> some View {
        Button {
            withAnimation { currentPage = page }
        } label: {
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(16)
        }
        .padding(.horizontal, 32)
    }

    private func formatGoal(_ minutes: Int) -> String {
        "\(minutes / 60)h \(minutes % 60)m"
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
