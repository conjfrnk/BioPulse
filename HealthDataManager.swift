//
//  HealthDataManager.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import HealthKit

class HealthDataManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(
        forIdentifier: .sleepAnalysis)!
    let hrvType = HKObjectType.quantityType(
        forIdentifier: .heartRateVariabilitySDNN)!
    let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let typesToRead: Set<HKObjectType> = [
            sleepType, hrvType, heartRateType, stepType,
        ]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) {
            success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    func fetchWeeklySteps(
        from startDate: Date,
        completion: @escaping ([Date: Double]?, Error?) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startOfDay,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, results, error in
            DispatchQueue.main.async {
                guard let results = results else {
                    completion(nil, error)
                    return
                }
                var stepData = [Date: Double]()
                results.enumerateStatistics(from: startOfDay, to: endDate) {
                    statistics, _ in
                    if let steps = statistics.sumQuantity()?.doubleValue(
                        for: HKUnit.count())
                    {
                        stepData[statistics.startDate] = steps
                    } else {
                        stepData[statistics.startDate] = 0
                    }
                }
                completion(stepData, nil)
            }
        }
        healthStore.execute(query)
    }

    func fetchSleepData(
        for date: Date,
        completion: @escaping (
            [(stage: String, startDate: Date, endDate: Date)]?, Error?
        ) -> Void
    ) {
        let calendar = Calendar.current
        let startTime = calendar.date(
            bySettingHour: 14, minute: 0, second: 0,
            of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let endTime = calendar.date(
            bySettingHour: 14, minute: 0, second: 0, of: date)!
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime, end: endTime, options: .strictStartDate)
        let sortDescriptors = [
            NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate, ascending: true),
            NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate, ascending: true),
        ]
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sortDescriptors
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                guard let samples = samples as? [HKCategorySample] else {
                    completion([], nil)
                    return
                }
                let groupedBySource = Dictionary(grouping: samples) { sample in
                    sample.sourceRevision.source.bundleIdentifier
                }
                let bestSource =
                    groupedBySource.max(by: { a, b in
                        let aHasStages = a.value.contains {
                            $0.value
                                == HKCategoryValueSleepAnalysis.asleepDeep
                                .rawValue
                                || $0.value
                                    == HKCategoryValueSleepAnalysis.asleepREM
                                    .rawValue
                        }
                        let bHasStages = b.value.contains {
                            $0.value
                                == HKCategoryValueSleepAnalysis.asleepDeep
                                .rawValue
                                || $0.value
                                    == HKCategoryValueSleepAnalysis.asleepREM
                                    .rawValue
                        }
                        if aHasStages != bHasStages {
                            return !aHasStages
                        }
                        return a.value.count < b.value.count
                    })?.value ?? []
                var sleepData:
                    [(stage: String, startDate: Date, endDate: Date)] = []
                var currentStage:
                    (stage: String, startDate: Date, endDate: Date)?
                for sample in bestSource.sorted(by: {
                    $0.startDate < $1.startDate
                }) {
                    let stage: String
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        continue
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        stage = "Core"
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        stage = "Deep"
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        stage = "REM"
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        stage = "Awake"
                    default:
                        continue
                    }
                    if let current = currentStage {
                        if current.stage == stage
                            && sample.startDate <= current.endDate
                        {
                            currentStage?.endDate = max(
                                current.endDate, sample.endDate)
                        } else {
                            sleepData.append(current)
                            currentStage = (
                                stage, sample.startDate, sample.endDate
                            )
                        }
                    } else {
                        currentStage = (stage, sample.startDate, sample.endDate)
                    }
                }
                if let last = currentStage {
                    sleepData.append(last)
                }
                let sortedSleepData = sleepData.sorted {
                    $0.startDate < $1.startDate
                }
                completion(sortedSleepData, nil)
            }
        }
        healthStore.execute(query)
    }

    func fetchHRVDuringSleep(
        sleepStart: Date, sleepEnd: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart, end: sleepEnd, options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: hrvType, quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, statistics, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                let hrv = statistics?.averageQuantity()?.doubleValue(
                    for: HKUnit.secondUnit(with: .milli))
                completion(hrv, nil)
            }
        }
        healthStore.execute(query)
    }

    func fetchHeartRateDuringSleep(
        sleepStart: Date, sleepEnd: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart, end: sleepEnd, options: .strictStartDate)
        let interval = DateComponents(minute: 5)
        let query = HKStatisticsCollectionQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: sleepStart,
            intervalComponents: interval
        )
        query.initialResultsHandler = { _, results, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                guard let results = results else {
                    completion(nil, nil)
                    return
                }
                var heartRates: [Double] = []
                results.enumerateStatistics(from: sleepStart, to: sleepEnd) {
                    statistics, _ in
                    if let quantity = statistics.averageQuantity() {
                        let hr = quantity.doubleValue(
                            for: HKUnit.count().unitDivided(by: .minute()))
                        if hr >= 30 && hr <= 120 {
                            heartRates.append(hr)
                        }
                    }
                }
                if !heartRates.isEmpty {
                    heartRates.sort()
                    let lowestCount = max(
                        1, Int(Double(heartRates.count) * 0.1))
                    let lowestHeartRates = Array(heartRates.prefix(lowestCount))
                    let averageHR =
                        lowestHeartRates.reduce(0, +)
                        / Double(lowestHeartRates.count)
                    completion(averageHR, nil)
                } else {
                    completion(nil, nil)
                }
            }
        }
        healthStore.execute(query)
    }

    func fetchDailyHRVOverLast30Days(
        completion: @escaping ([Date: Double]?, Error?) -> Void
    ) {
        let endDate = Date()
        guard
            let startDate = Calendar.current.date(
                byAdding: .day, value: -30, to: endDate)
        else {
            completion([:], nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: hrvType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, statsCollection, error in
            if let error = error {
                completion(nil, error)
                return
            }
            var dailyHRV: [Date: Double] = [:]
            statsCollection?.enumerateStatistics(from: startDate, to: endDate) {
                stats, _ in
                if let avg = stats.averageQuantity()?.doubleValue(
                    for: HKUnit.secondUnit(with: .milli))
                {
                    let dayKey = Calendar.current.startOfDay(
                        for: stats.startDate)
                    dailyHRV[dayKey] = avg
                }
            }
            completion(dailyHRV, nil)
        }
        healthStore.execute(query)
    }

    func fetchDailyRestingHROverLast30Days(
        completion: @escaping ([Date: Double]?, Error?) -> Void
    ) {
        let endDate = Date()
        guard
            let startDate = Calendar.current.date(
                byAdding: .day, value: -30, to: endDate)
        else {
            completion([:], nil)
            return
        }
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, statsCollection, error in
            if let error = error {
                completion(nil, error)
                return
            }
            var dailyRHR: [Date: Double] = [:]
            statsCollection?.enumerateStatistics(from: startDate, to: endDate) {
                stats, _ in
                if let avg = stats.averageQuantity()?.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute()))
                {
                    let dayKey = Calendar.current.startOfDay(
                        for: stats.startDate)
                    dailyRHR[dayKey] = avg
                }
            }
            completion(dailyRHR, nil)
        }
        healthStore.execute(query)
    }
}
