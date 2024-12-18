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
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)! // Changed from restingHeartRate
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
        
        // Sort by start date and source revision date
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true),
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        ]
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sortDescriptors
        ) { _, samples, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[SLEEP] Error fetching sleep data: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample] else {
                    print("[SLEEP] No sleep samples found")
                    completion([], nil)
                    return
                }
                
                // Group samples by source
                let groupedBySource = Dictionary(grouping: samples) { sample in
                    sample.sourceRevision.source.bundleIdentifier
                }
                
                print("[SLEEP] Found data from \(groupedBySource.count) sources")
                
                // Find the source with the most detailed data
                let bestSource = groupedBySource.max(by: { a, b in
                    let aHasStages = a.value.contains { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    let bHasStages = b.value.contains { $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    if aHasStages != bHasStages {
                        return !aHasStages
                    }
                    return a.value.count < b.value.count
                })?.value ?? []
                
                print("[SLEEP] Selected source with \(bestSource.count) samples")
                
                // Convert and merge overlapping intervals
                var sleepData: [(stage: String, startDate: Date, endDate: Date)] = []
                var currentStage: (stage: String, startDate: Date, endDate: Date)?
                
                for sample in bestSource.sorted(by: { $0.startDate < $1.startDate }) {
                    let stage: String
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        continue // Skip "InBed" stages
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        stage = "Core"
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        stage = "Deep"
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        stage = "REM"
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        stage = "Awake"
                    default:
                        print("[SLEEP] Unknown sleep stage: \(sample.value)")
                        continue
                    }
                    
                    if let current = currentStage {
                        if current.stage == stage && sample.startDate <= current.endDate {
                            // Extend current interval
                            currentStage?.endDate = max(current.endDate, sample.endDate)
                        } else {
                            // Add current interval and start new one
                            sleepData.append(current)
                            currentStage = (stage, sample.startDate, sample.endDate)
                        }
                    } else {
                        currentStage = (stage, sample.startDate, sample.endDate)
                    }
                }
                
                // Add the last interval
                if let last = currentStage {
                    sleepData.append(last)
                }
                
                // Sort final data chronologically
                let sortedSleepData = sleepData.sorted { $0.startDate < $1.startDate }
                
                print("[SLEEP] Processed \(sortedSleepData.count) intervals")
                for interval in sortedSleepData {
                    let duration = interval.endDate.timeIntervalSince(interval.startDate) / 3600.0
                    print("[SLEEP] \(interval.stage): \(String(format: "%.2f", duration))h (\(interval.startDate) to \(interval.endDate))")
                }
                
                completion(sortedSleepData, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHRVDuringSleep(
        sleepStart: Date,
        sleepEnd: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        print("[HRV] Fetching HRV between \(sleepStart) and \(sleepEnd)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
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
                    print("[HRV] Average HRV during sleep: \(hrv) ms")
                } else {
                    print("[HRV] No HRV data found during sleep period")
                }
                completion(hrv, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchHeartRateDuringSleep(
        sleepStart: Date,
        sleepEnd: Date,
        completion: @escaping (Double?, Error?) -> Void
    ) {
        print("[HR] Fetching heart rate between \(sleepStart) and \(sleepEnd)")
        
        let predicate = HKQuery.predicateForSamples(
            withStart: sleepStart,
            end: sleepEnd,
            options: .strictStartDate
        )
        
        // Use statistics collection query to get average heart rate over time
        let interval = DateComponents(minute: 5) // Group by 5-minute intervals
        let query = HKStatisticsCollectionQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage,
            anchorDate: sleepStart,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { query, results, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[HR] Error fetching heart rate: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let results = results else {
                    print("[HR] No results found")
                    completion(nil, nil)
                    return
                }
                
                var heartRates: [Double] = []
                results.enumerateStatistics(from: sleepStart, to: sleepEnd) { statistics, stop in
                    if let quantity = statistics.averageQuantity() {
                        let hr = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        // Only include reasonable heart rates (filter out potential errors)
                        if hr >= 30 && hr <= 120 {
                            heartRates.append(hr)
                        }
                    }
                }
                
                // Calculate the average of the lowest 10% of heart rates
                // This better approximates resting heart rate during sleep
                if !heartRates.isEmpty {
                    heartRates.sort()
                    let lowestCount = max(1, Int(Double(heartRates.count) * 0.1))
                    let lowestHeartRates = Array(heartRates.prefix(lowestCount))
                    let averageHR = lowestHeartRates.reduce(0, +) / Double(lowestHeartRates.count)
                    
                    print("[HR] Found \(heartRates.count) measurements")
                    print("[HR] Average of lowest 10% heart rates: \(averageHR) bpm")
                    completion(averageHR, nil)
                } else {
                    print("[HR] No valid heart rate measurements found")
                    completion(nil, nil)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
}
