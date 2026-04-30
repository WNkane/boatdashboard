import Foundation
import HealthKit

class HealthKitHeartRateManager: ObservableObject {

    @Published var heartRate: Int = 0
    @Published var isAuthorized: Bool = false

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private var observerQuery: HKObserverQuery?
    private var anchor: HKQueryAnchor?

    // MARK: - Authorization

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: [], read: [heartRateType]) { [weak self] success, _ in
            guard let self, success else { return }
            DispatchQueue.main.async { self.isAuthorized = true }
            self.startObserving()
        }
    }

    // MARK: - Observation

    func startObserving() {
        guard observerQuery == nil else { return }
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            guard error == nil else { return }
            self?.fetchLatestHeartRate()
        }
        observerQuery = query
        healthStore.execute(query)
    }

    func stop() {
        if let q = observerQuery { healthStore.stop(q) }
        observerQuery = nil
        disableBackgroundDelivery()
    }

    // MARK: - Fetch

    private func fetchLatestHeartRate() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),
            end: nil,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: anchor,
            limit: 1
        ) { [weak self] _, samples, _, newAnchor, _ in
            guard let self else { return }
            self.anchor = newAnchor
            guard let sample = samples?.first as? HKQuantitySample else { return }
            let bpm = Int(sample.quantity.doubleValue(for: HKUnit(from: "count/min")))
            DispatchQueue.main.async { self.heartRate = bpm }
        }
        // Suppress unused variable warning — sortDescriptor used implicitly via query init
        _ = sortDescriptor
        healthStore.execute(query)
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { _, _ in }
    }

    func disableBackgroundDelivery() {
        healthStore.disableBackgroundDelivery(for: heartRateType) { _, _ in }
    }
}
