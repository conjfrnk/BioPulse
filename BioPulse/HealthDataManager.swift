//
//  HealthDataManager.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import HealthKit
import SwiftUI

public class HealthDataManager: ObservableObject {
    private let healthStore = HKHealthStore()

    private let sleepType = HKObjectType.categoryType(
        forIdentifier: .sleepAnalysis)!
    private let hrvType = HKObjectType.quantityType(
        forIdentifier: .heartRateVariabilitySDNN)!
    private let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let stepsType = HKObjectType.quantityType(
        forIdentifier: .stepCount)!

    public struct NightData: Identifiable, Hashable {
        public var id: Date { date }

        public let date: Date
        public let sleepScore: Int
        public let hrv: Double
        public let restingHeartRate: Double
        public let sleepDuration: TimeInterval
        public let sleepStartTime: Date
        public let sleepEndTime: Date
        public let totalAwakeTime: TimeInterval

        public func hash(into hasher: inout Hasher) {
            hasher.combine(date)
        }

        public static func == (lhs: NightData, rhs: NightData) -> Bool {
            lhs.date == rhs.date
        }

        public init(
            date: Date,
            sleepScore: Int,
            hrv: Double,
            restingHeartRate: Double,
            sleepDuration: TimeInterval,
            sleepStartTime: Date,
            sleepEndTime: Date,
            totalAwakeTime: TimeInterval
        ) {
            self.date = date
            self.sleepScore = sleepScore
            self.hrv = hrv
            self.restingHeartRate = restingHeartRate
            self.sleepDuration = sleepDuration
            self.sleepStartTime = sleepStartTime
            self.sleepEndTime = sleepEndTime
            self.totalAwakeTime = totalAwakeTime
        }
    }

    public func requestAuthorization(
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let toRead: Set<HKObjectType> = [
            sleepType, hrvType, hrType, stepsType,
        ]
        healthStore.requestAuthorization(toShare: nil, read: toRead) {
            success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    public func fetchSleepData(
        for date: Date,
        completion: @escaping (
            [(stage: String, startDate: Date, endDate: Date)]?, Error?
        ) -> Void
    ) {
        let c = Calendar.current
        let startTime =
            c.date(
                bySettingHour: 14,
                minute: 0,
                second: 0,
                of: c.date(byAdding: .day, value: -1, to: date) ?? date
            ) ?? date
        let endTime =
            c.date(
                bySettingHour: 14,
                minute: 0,
                second: 0,
                of: date
            ) ?? date
        self.fetchSleepData(
            startTime: startTime, endTime: endTime, completion: completion)
    }

    public func fetchNightsOverLastNDays(
        _ days: Int,
        sleepGoalMinutes: Int,
        completion: @escaping ([NightData]) -> Void
    ) {
        guard days > 0 else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        let group = DispatchGroup()
        var allNights: [NightData] = []
        let calendar = Calendar.current
        let now = Date()
        for i in 0..<days {
            group.enter()
            guard
                let dayStart = calendar.date(
                    byAdding: .day, value: -i, to: now),
                let nextDay = calendar.date(
                    byAdding: .day, value: 1, to: dayStart)
            else {
                group.leave()
                continue
            }
            let startTime = calendar.date(
                bySettingHour: 14, minute: 0, second: 0, of: dayStart)!
            let endTime = calendar.date(
                bySettingHour: 14, minute: 0, second: 0, of: nextDay)!
            fetchSleepData(startTime: startTime, endTime: endTime) {
                segments, err in
                guard let segments = segments, !segments.isEmpty else {
                    group.leave()
                    return
                }
                let sorted = segments.sorted { $0.startDate < $1.startDate }
                guard let earliest = sorted.first, let latest = sorted.last
                else {
                    group.leave()
                    return
                }
                let totalNonAwake =
                    sorted
                    .filter { $0.stage != "Awake" && $0.stage != "InBed" }
                    .reduce(0.0) {
                        $0 + $1.endDate.timeIntervalSince($1.startDate)
                    }
                let totalAwake =
                    sorted
                    .filter { $0.stage == "Awake" }
                    .reduce(0.0) {
                        $0 + $1.endDate.timeIntervalSince($1.startDate)
                    }
                let actualStart = earliest.startDate
                let actualEnd = latest.endDate
                self.fetchHRVDuringSleep(
                    sleepStart: actualStart, sleepEnd: actualEnd
                ) { hrvVal, _ in
                    self.fetchHeartRateDuringSleep(
                        sleepStart: actualStart, sleepEnd: actualEnd
                    ) { rhrVal, _ in
                        let score = self.calculateSleepScore(
                            sleepData: sorted,
                            hrv: hrvVal,
                            rhr: rhrVal,
                            sleepGoalMinutes: sleepGoalMinutes
                        )
                        let night = NightData(
                            date: endTime,
                            sleepScore: score,
                            hrv: hrvVal ?? 0,
                            restingHeartRate: rhrVal ?? 0,
                            sleepDuration: totalNonAwake,
                            sleepStartTime: actualStart,
                            sleepEndTime: actualEnd,
                            totalAwakeTime: totalAwake
                        )
                        allNights.append(night)
                        group.leave()
                    }
                }
            }
        }
        group.notify(queue: .main) {
            let sorted = allNights.sorted { $0.date > $1.date }
            completion(sorted)
        }
    }

    private func fetchSleepData(
        startTime: Date,
        endTime: Date,
        completion: @escaping (
            [(stage: String, startDate: Date, endDate: Date)]?, Error?
        ) -> Void
    ) {
        let pred = HKQuery.predicateForSamples(
            withStart: startTime, end: endTime, options: .strictStartDate)
        let sortDescs = [
            NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate, ascending: true),
            NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate, ascending: true),
        ]
        let q = HKSampleQuery(
            sampleType: sleepType, predicate: pred, limit: HKObjectQueryNoLimit,
            sortDescriptors: sortDescs
        ) { _, samples, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty
            else {
                DispatchQueue.main.async {
                    completion([], nil)
                }
                return
            }
            let grouped = Dictionary(grouping: samples) {
                $0.sourceRevision.source.bundleIdentifier
            }
            let bestSamples =
                grouped
                .max(by: { a, b in
                    let aHasStages = a.value.contains(where: {
                        $0.value
                            == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                            || $0.value
                                == HKCategoryValueSleepAnalysis.asleepDeep
                                .rawValue
                    })
                    let bHasStages = b.value.contains(where: {
                        $0.value
                            == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                            || $0.value
                                == HKCategoryValueSleepAnalysis.asleepDeep
                                .rawValue
                    })
                    if aHasStages != bHasStages { return !aHasStages }
                    return a.value.count < b.value.count
                })?.value ?? samples
            let combined = self.mergeSleepSegments(bestSamples)
            DispatchQueue.main.async {
                completion(combined, nil)
            }
        }
        healthStore.execute(q)
    }

    private func mergeSleepSegments(
        _ raw: [HKCategorySample]
    ) -> [(stage: String, startDate: Date, endDate: Date)] {
        let sorted = raw.sorted { $0.startDate < $1.startDate }
        var result: [(stage: String, startDate: Date, endDate: Date)] = []
        var current: (stage: String, start: Date, end: Date)?
        for s in sorted {
            let stageName: String
            switch s.value {
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                stageName = "InBed"
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stageName = "Core"
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stageName = "Deep"
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stageName = "REM"
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stageName = "Awake"
            default:
                stageName = "Other"
            }
            if let c = current {
                if c.stage == stageName && s.startDate <= c.end {
                    let newEnd = max(c.end, s.endDate)
                    current = (stageName, c.start, newEnd)
                } else {
                    result.append((c.stage, c.start, c.end))
                    current = (stageName, s.startDate, s.endDate)
                }
            } else {
                current = (stageName, s.startDate, s.endDate)
            }
        }
        if let final = current {
            result.append((final.stage, final.start, final.end))
        }
        return result
    }

    private func fetchHRVDuringSleep(
        sleepStart: Date,
        sleepEnd: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let pred = HKQuery.predicateForSamples(
            withStart: sleepStart, end: sleepEnd, options: .strictStartDate)
        let statsQ = HKStatisticsQuery(
            quantityType: hrvType,
            quantitySamplePredicate: pred,
            options: .discreteAverage
        ) { _, stats, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            let val = stats?.averageQuantity()?.doubleValue(
                for: .secondUnit(with: .milli))
            DispatchQueue.main.async {
                completion(val, nil)
            }
        }
        healthStore.execute(statsQ)
    }

    private func fetchHeartRateDuringSleep(
        sleepStart: Date,
        sleepEnd: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let pred = HKQuery.predicateForSamples(
            withStart: sleepStart, end: sleepEnd, options: .strictStartDate)
        let interval = DateComponents(minute: 5)
        let query = HKStatisticsCollectionQuery(
            quantityType: hrType,
            quantitySamplePredicate: pred,
            options: [.discreteAverage],
            anchorDate: sleepStart,
            intervalComponents: interval
        )
        query.initialResultsHandler = { _, results, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            guard let results = results else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
                return
            }
            var hrValues: [Double] = []
            results.enumerateStatistics(from: sleepStart, to: sleepEnd) {
                stats, _ in
                if let avgQ = stats.averageQuantity() {
                    let bpm = avgQ.doubleValue(
                        for: HKUnit.count().unitDivided(by: .minute()))
                    if bpm >= 30 && bpm <= 120 {
                        hrValues.append(bpm)
                    }
                }
            }
            guard !hrValues.isEmpty else {
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }
            hrValues.sort()
            let cutCount = max(1, Int(Double(hrValues.count) * 0.1))
            let lowest = Array(hrValues.prefix(cutCount))
            let avg = lowest.reduce(0, +) / Double(lowest.count)
            DispatchQueue.main.async {
                completion(avg, nil)
            }
        }
        healthStore.execute(query)
    }

    private func calculateSleepScore(
        sleepData: [(stage: String, startDate: Date, endDate: Date)],
        hrv: Double?,
        rhr: Double?,
        sleepGoalMinutes: Int
    ) -> Int {
        var score = 100
        let totalSlept =
            sleepData
            .filter { $0.stage != "Awake" && $0.stage != "InBed" }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let byStage = Dictionary(grouping: sleepData, by: { $0.stage })
            .mapValues { segs in
                segs.reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate)
                }
            }
        if totalSlept > 0 {
            let deep = byStage["Deep"] ?? 0
            let rem = byStage["REM"] ?? 0
            let awake = byStage["Awake"] ?? 0
            let inBed = byStage["InBed"] ?? 0
            if (deep / totalSlept) < 0.13 { score -= 15 }
            if (rem / totalSlept) < 0.20 { score -= 15 }
            let totalInBed = totalSlept + awake + inBed
            if totalInBed > 0 {
                if (awake / totalInBed) > 0.1 { score -= 10 }
            }
        }
        let goalSecs = Double(sleepGoalMinutes) * 60
        if goalSecs > 0 {
            let frac = min(1.0, totalSlept / goalSecs)
            let durScore = Int(25.0 * frac)
            score = score - 25 + durScore
        }
        if let h = hrv, h < 30 {
            score -= 5
        } else if hrv == nil {
            score -= 5
        }
        if let rr = rhr, rr > 100 {
            score -= 5
        } else if rhr == nil {
            score -= 5
        }
        return max(0, min(100, score))
    }

    public func fetchWeeklySteps(
        from startDate: Date,
        completion: @escaping ([Date: Double]?, Error?) -> Void
    ) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: startDate)
        guard let endDate = cal.date(byAdding: .day, value: 7, to: startOfDay)
        else {
            completion(nil, nil)
            return
        }
        let pred = HKQuery.predicateForSamples(
            withStart: startOfDay, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: pred,
            options: [.cumulativeSum],
            anchorDate: startOfDay,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, results, error in
            guard error == nil else {
                DispatchQueue.main.async { completion(nil, error) }
                return
            }
            guard let results = results else {
                DispatchQueue.main.async { completion([:], nil) }
                return
            }
            var stepMap: [Date: Double] = [:]
            results.enumerateStatistics(from: startOfDay, to: endDate) {
                stats, _ in
                let steps =
                    stats.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                stepMap[stats.startDate] = steps
            }
            DispatchQueue.main.async {
                completion(stepMap, nil)
            }
        }
        healthStore.execute(query)
    }
}
