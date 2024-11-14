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
        let typesToRead: Set = [stepType, sleepType]
        
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

    // Fetch sleep stages from the previous night
    func fetchLastNightSleepData(topSourceOnly: Bool = false, completion: @escaping ([(stage: String, startDate: Date, endDate: Date)]?, Error?) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let now = Date()
        let startOfYesterday = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: now)!)
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
            guard let results = results else {
                completion(nil, error)
                return
            }

            var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
            let topSourceID = results.first?.sourceRevision.source.bundleIdentifier
            
            for sample in results {
                if let sample = sample as? HKCategorySample {
                    if topSourceOnly && sample.sourceRevision.source.bundleIdentifier != topSourceID {
                        continue // Skip samples from other sources if topSourceOnly is true
                    }

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
