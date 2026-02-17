//
//  NotificationManager.swift
//  BioPulse
//
//  Created by Connor Frank on 2/16/26.
//

import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted {
                    self.scheduleBedtimeReminder()
                }
            }
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func scheduleBedtimeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bedtimeReminder"])

        guard UserDefaults.standard.bool(forKey: "bedtimeNotificationsEnabled") else { return }

        let sleepGoal = UserDefaults.standard.integer(forKey: "sleepGoal")
        let wakeTimeInterval = UserDefaults.standard.double(forKey: "goalWakeTime")

        guard sleepGoal > 0, wakeTimeInterval > 0 else { return }

        let wakeTime = Date(timeIntervalSince1970: wakeTimeInterval)
        let calendar = Calendar.current
        let wakeComps = calendar.dateComponents([.hour, .minute], from: wakeTime)

        // Calculate bedtime: wake time minus sleep goal minus 30 min wind-down reminder
        let totalMinutesBefore = sleepGoal + 30
        var bedtimeHour = (wakeComps.hour ?? 7) * 60 + (wakeComps.minute ?? 0) - totalMinutesBefore
        if bedtimeHour < 0 { bedtimeHour += 24 * 60 }

        var dateComponents = DateComponents()
        dateComponents.hour = bedtimeHour / 60
        dateComponents.minute = bedtimeHour % 60

        let content = UNMutableNotificationContent()
        content.title = "Time to Wind Down"
        content.body = "Your optimal bedtime is in 30 minutes. Start your wind-down routine for better sleep quality."
        content.sound = .default
        content.categoryIdentifier = "BEDTIME_REMINDER"

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "bedtimeReminder", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelBedtimeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bedtimeReminder"])
    }
}
