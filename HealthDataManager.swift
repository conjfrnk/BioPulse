//
//  HealthDataManager.swift
//  BioPulse
//
//  Created by Connor Frank on 11/13/24.
//

import HealthKit
import Combine

class HealthDataManager: ObservableObject {  // Conform to ObservableObject
    let healthStore = HKHealthStore()
    
    // Request authorization for HealthKit data
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            completion(false, NSError(domain: "HealthKit not available", code: -1, userInfo: nil))
            return
        }
        
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let restingHRType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        
        let typesToRead: Set = [stepType, sleepType, hrvType, restingHRType]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { (success, error) in
            if success {
                print("Authorization granted.")
            } else {
                print("Authorization denied or not determined: \(error?.localizedDescription ?? "Unknown error")")
            }
            completion(success, error)
        }
    }
    
    // Fetch step count for the past week, returning a dictionary of dates and step counts
    func fetchWeeklySteps(from startDate: Date, completion: @escaping ([Date: Double]?, Error?) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                completion(nil, error)
                return
            }
            
            var stepData = [Date: Double]()
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                stepData[statistics.startDate] = steps
            }
            completion(stepData, nil)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch HRV for a specific date
    func fetchHRV(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: date),
            end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)),
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: hrvType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, statistics, error in
            let hrv = statistics?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
            completion(hrv, error)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch resting heart rate for a specific date
    func fetchRestingHeartRate(for date: Date, completion: @escaping (Double?, Error?) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: date),
            end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date)),
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, statistics, error in
            let heartRate = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            completion(heartRate, error)
        }
        
        healthStore.execute(query)
    }
    
    // Fetch sleep data for a specific date
    func fetchSleepData(for date: Date, completion: @escaping ([(stage: String, startDate: Date, endDate: Date)]?, Error?) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Get 2 PM of previous day to 2 PM of the specified date
        let calendar = Calendar.current
        let twoPM = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date)!
        let previousDay2PM = calendar.date(byAdding: .day, value: -1, to: twoPM)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: previousDay2PM,
            end: twoPM,
            options: .strictStartDate
        )
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            guard let samples = samples else {
                completion(nil, error)
                return
            }
            
            var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
            let validSources = ["com.apple.health", "com.apple.health.preview"]
            
            for sample in samples {
                if let sample = sample as? HKCategorySample,
                   validSources.contains(sample.sourceRevision.source.bundleIdentifier) {
                    let stage: String
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        stage = "Awake"
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        stage = "REM"
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        stage = "Core"
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        stage = "Deep"
                    default:
                        continue
                    }
                    sleepData.append((stage: stage, startDate: sample.startDate, endDate: sample.endDate))
                }
            }
            completion(sleepData, nil)
        }
        
        healthStore.execute(query)
    }
}
