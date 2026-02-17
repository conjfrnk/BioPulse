//
//  SharedDefaults.swift
//  BioPulse
//
//  Created by Connor Frank on 2/16/26.
//

import Foundation

struct SharedDefaults {
    static let appGroupID = "group.com.conjfrnk.BioPulse"

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // Keys
    static let recoveryScore = "widget_recoveryScore"
    static let recoveryLabel = "widget_recoveryLabel"
    static let sleepDebtHours = "widget_sleepDebtHours"
    static let optimalBedtime = "widget_optimalBedtime"
    static let lastHRV = "widget_lastHRV"
    static let lastRHR = "widget_lastRHR"
    static let lastSleepDuration = "widget_lastSleepDuration"
    static let lastUpdated = "widget_lastUpdated"

    static func writeWidgetData(
        recoveryScore: Int,
        recoveryLabel: String,
        sleepDebtHours: Double,
        optimalBedtime: String?,
        lastHRV: Double,
        lastRHR: Double,
        lastSleepDuration: TimeInterval
    ) {
        let defaults = shared
        defaults.set(recoveryScore, forKey: self.recoveryScore)
        defaults.set(recoveryLabel, forKey: self.recoveryLabel)
        defaults.set(sleepDebtHours, forKey: self.sleepDebtHours)
        defaults.set(optimalBedtime, forKey: self.optimalBedtime)
        defaults.set(lastHRV, forKey: self.lastHRV)
        defaults.set(lastRHR, forKey: self.lastRHR)
        defaults.set(lastSleepDuration, forKey: self.lastSleepDuration)
        defaults.set(Date().timeIntervalSince1970, forKey: self.lastUpdated)
    }
}
