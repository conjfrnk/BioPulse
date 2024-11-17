//
//  HealthDataManager.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import HealthKit

class HealthDataManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    private let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let typesToRead: Set<HKObjectType> = [sleepType, hrvType, heartRateType, stepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
    
    func fetchWeeklySteps(
        from startDate: Date,
        completion: @escaping ([Date: Double]?, Error?) -> Void
    ) {
        // Ensure we start from the beginning of the day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endDate,
            options: .strictStartDate
        )
        
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
                    print("[ERROR] Failed to fetch step data: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil, error)
                    return
                }
                
                var stepData = [Date: Double]()
                results.enumerateStatistics(from: startOfDay, to: endDate) { statistics, _ in
                    if let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) {
                        print("[STEPS] Found \(Int(steps)) steps for \(statistics.startDate)")
                        stepData[statistics.startDate] = steps
                    } else {
                        print("[STEPS] No step data for \(statistics.startDate)")
                        stepData[statistics.startDate] = 0
                    }
                }
                
                print("[STEPS] Fetched data for \(stepData.count) days")
                completion(stepData, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchSleepData(
        for date: Date,
        completion: @escaping ([(stage: String, startDate: Date, endDate: Date)]?, Error?) -> Void
    ) {
        let calendar = Calendar.current
        let startTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let endTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date)!
        
        print("[SLEEP] Fetching sleep data between \(startTime) and \(endTime)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: endTime,
            options: .strictStartDate
        )
        
        // Create a descriptor to sort by source revision date (most recent first)
        let sortBySource = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortBySource]
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
                
                // Group samples by source and use only the most recent source
                let groupedBySource = Dictionary(grouping: samples) { sample in
                    sample.sourceRevision.source.bundleIdentifier
                }
                
                // Get the most recent source's data
                if let primarySourceData = groupedBySource.values.first {
                    let sleepData = primarySourceData.compactMap { sample -> (stage: String, startDate: Date, endDate: Date)? in
                        // Ensure the sample is within our time window
                        guard sample.startDate >= startTime && sample.endDate <= endTime else {
                            return nil
                        }
                        
                        let stage: String
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.inBed.rawValue:
                            stage = "InBed"
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                            stage = "Core"
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            stage = "Deep"
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            stage = "REM"
                        case HKCategoryValueSleepAnalysis.awake.rawValue:
                            stage = "Awake"
                        default:
                            stage = "Unknown"
                        }
                        
                        // Log the duration for debugging
                        let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                        print("[SLEEP] Found \(stage) period: \(duration) hours from \(sample.startDate) to \(sample.endDate)")
                        
                        return (stage, sample.startDate, sample.endDate)
                    }
                    
                    completion(sleepData, nil)
                } else {
                    completion([], nil)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHRV(
        for date: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let calendar = Calendar.current
        // Focus on the sleep period: 6PM to 10AM
        let startTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date)!
        
        print("[HRV] Fetching HRV between \(startTime) and \(endTime)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: endTime,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: hrvType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, statistics, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let hrv = statistics?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                if let hrv = hrv {
                    print("[HRV] Average HRV: \(hrv) ms")
                } else {
                    print("[HRV] No HRV data found")
                }
                completion(hrv, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchRestingHeartRate(
        for date: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        let calendar = Calendar.current
        // Focus on the sleep period: 6PM to 10AM
        let startTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: date)!)!
        let endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date)!
        
        print("[RHR] Fetching resting heart rate between \(startTime) and \(endTime)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: endTime,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, statistics, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                let heartRate = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                if let heartRate = heartRate {
                    print("[RHR] Average resting heart rate: \(heartRate) bpm")
                } else {
                    print("[RHR] No resting heart rate data found")
                }
                completion(heartRate, nil)
            }
        }
        
        healthStore.execute(query)
    }
}
