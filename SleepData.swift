//
//  SleepData.swift
//  BioPulse
//
//  Created by Connor Frank on 11/15/24.
//

import Foundation

struct SleepData: Identifiable {
    let id = UUID()
    let date: Date
    let bedtime: Date
    let wakeUpTime: Date
}
