// HealthKitManager.swift

import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    func requestAuthorization() {
        let types: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        healthStore.requestAuthorization(toShare: [], read: types) { _, _ in }
    }

    func fetchStepsAndDistance(start: Date, end: Date, completion: @escaping (Int, Double) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            let distanceQuery = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let distance = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                DispatchQueue.main.async {
                    completion(steps, distance)
                }
            }
            self.healthStore.execute(distanceQuery)
        }
        healthStore.execute(stepQuery)
    }
}
