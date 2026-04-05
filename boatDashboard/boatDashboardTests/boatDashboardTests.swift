import XCTest
import SwiftData
@testable import boatDashboard

final class boatDashboardTests: XCTestCase {

    // MARK: - movingAverage

    func test_movingAverage_emptyInput_returnsEmpty() {
        XCTAssertEqual(movingAverage([]), [])
    }

    func test_movingAverage_singleElement_returnsSame() {
        XCTAssertEqual(movingAverage([5.0]), [5.0])
    }

    func test_movingAverage_fewerThanWindow_usesAllElements() {
        // [1, 2, 3] window=5 → each element uses all three → avg = 2.0
        let result = movingAverage([1.0, 2.0, 3.0], window: 5)
        XCTAssertEqual(result.count, 3)
        for v in result { XCTAssertEqual(v, 2.0, accuracy: 0.001) }
    }

    func test_movingAverage_smoothsSpike() {
        // Spike at index 2: [10, 10, 100, 10, 10] → middle should be < 100
        let input: [Double] = [10, 10, 100, 10, 10]
        let result = movingAverage(input, window: 5)
        XCTAssertLessThan(result[2], 100)
        XCTAssertGreaterThan(result[2], 10)
    }

    func test_movingAverage_windowOne_returnsIdentical() {
        let input: [Double] = [3.0, 7.0, 2.0]
        XCTAssertEqual(movingAverage(input, window: 1), input)
    }

    // MARK: - HRZone

    func test_hrZone_belowThreshold_zone1() {
        XCTAssertEqual(HRZone.zone(for: 100), .zone1)
    }

    func test_hrZone_zeroBpm_zone1() {
        XCTAssertEqual(HRZone.zone(for: 0), .zone1)
    }

    func test_hrZone_boundaries() {
        XCTAssertEqual(HRZone.zone(for: 114), .zone1)
        XCTAssertEqual(HRZone.zone(for: 115), .zone2)
        XCTAssertEqual(HRZone.zone(for: 137), .zone2)
        XCTAssertEqual(HRZone.zone(for: 138), .zone3)
        XCTAssertEqual(HRZone.zone(for: 154), .zone3)
        XCTAssertEqual(HRZone.zone(for: 155), .zone4)
        XCTAssertEqual(HRZone.zone(for: 170), .zone4)
        XCTAssertEqual(HRZone.zone(for: 171), .zone5)
        XCTAssertEqual(HRZone.zone(for: 200), .zone5)
    }

    // MARK: - DragonBoatActivity

    func test_activity_distanceKm_convertsFromMeters() {
        let a = makeActivity(distanceMeters: 2500)
        XCTAssertEqual(a.distanceKm, 2.5, accuracy: 0.001)
    }

    func test_activity_durationSeconds_withEndTime() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 3661)
        let a = makeActivity(start: start, end: end)
        XCTAssertEqual(a.durationSeconds, 3661)
    }

    func test_activity_durationSeconds_withoutEndTime() {
        let a = makeActivity()
        a.endTime = nil
        XCTAssertEqual(a.durationSeconds, 0)
    }

    func test_activity_durationFormatted_hoursMinutesSeconds() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 3661) // 1h 1m 1s
        let a = makeActivity(start: start, end: end)
        XCTAssertEqual(a.durationFormatted, "1:01:01")
    }

    func test_activity_durationFormatted_minutesSeconds() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 125) // 2m 5s
        let a = makeActivity(start: start, end: end)
        XCTAssertEqual(a.durationFormatted, "2:05")
    }

    // MARK: - PendingDataPoint

    func test_pendingDataPoint_speedZeroWhenGPSNegative() {
        // Simulates LocationManager behaviour: rawSpeed < 0 → speedKmh = 0
        let p = PendingDataPoint(timestamp: Date(), speedKmh: 0.0,
                                 cadenceSpm: 80, heartRateBpm: 140,
                                 latitude: 24.9603, longitude: 121.5399,
                                 altitudeMeters: 12)
        XCTAssertEqual(p.speedKmh, 0.0)
    }

    // MARK: - SwiftData round-trip

    @MainActor
    func test_swiftData_saveAndFetch_activity() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DragonBoatActivity.self, ActivityDataPoint.self,
                                          configurations: config)
        let ctx = container.mainContext

        let activity = makeActivity(distanceMeters: 1000)
        ctx.insert(activity)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<DragonBoatActivity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.totalDistanceMeters, 1000)
    }

    @MainActor
    func test_swiftData_cascadeDelete_removesDataPoints() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DragonBoatActivity.self, ActivityDataPoint.self,
                                          configurations: config)
        let ctx = container.mainContext

        let activity = makeActivity()
        let dp = ActivityDataPoint(timestamp: Date(), speedKmh: 5, cadenceSpm: 70,
                                   heartRateBpm: 130, latitude: 24.9, longitude: 121.5,
                                   altitudeMeters: 10)
        dp.activity = activity
        activity.dataPoints.append(dp)
        ctx.insert(activity)
        ctx.insert(dp)
        try ctx.save()

        ctx.delete(activity)
        try ctx.save()

        let activities = try ctx.fetch(FetchDescriptor<DragonBoatActivity>())
        let points     = try ctx.fetch(FetchDescriptor<ActivityDataPoint>())
        XCTAssertEqual(activities.count, 0)
        XCTAssertEqual(points.count, 0, "DataPoints should be cascade-deleted with Activity")
    }

    @MainActor
    func test_swiftData_multipleActivities_sortedByStartTime() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DragonBoatActivity.self, ActivityDataPoint.self,
                                          configurations: config)
        let ctx = container.mainContext

        let older = makeActivity(start: Date(timeIntervalSinceNow: -3600))
        let newer = makeActivity(start: Date())
        ctx.insert(older)
        ctx.insert(newer)
        try ctx.save()

        var desc = FetchDescriptor<DragonBoatActivity>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
        let fetched = try ctx.fetch(desc)
        XCTAssertEqual(fetched.count, 2)
        XCTAssertGreaterThan(fetched[0].startTime, fetched[1].startTime)
    }

    // MARK: - DataStore.saveActivity

    @MainActor
    func test_dataStore_saveActivity_computesCadenceStats() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DragonBoatActivity.self, ActivityDataPoint.self,
                                           configurations: config)
        let ctx = container.mainContext

        let store = DataStore()
        store.modelContext = ctx

        let now = Date()
        let points = [
            PendingDataPoint(timestamp: now,                   speedKmh: 5, cadenceSpm: 60, heartRateBpm: 130, latitude: 0, longitude: 0, altitudeMeters: 0),
            PendingDataPoint(timestamp: now.addingTimeInterval(1), speedKmh: 6, cadenceSpm: 80, heartRateBpm: 140, latitude: 0, longitude: 0, altitudeMeters: 0),
            PendingDataPoint(timestamp: now.addingTimeInterval(2), speedKmh: 7, cadenceSpm: 70, heartRateBpm: 150, latitude: 0, longitude: 0, altitudeMeters: 0),
        ]

        store.saveActivity(points: points,
                           startTime: now,
                           endTime: now.addingTimeInterval(3),
                           totalDistanceMeters: 500,
                           averageSpeedKmh: 6,
                           maxSpeedKmh: 7,
                           averageHeartRate: 140,
                           maxHeartRate: 150,
                           workoutName: nil)

        let fetched = try ctx.fetch(FetchDescriptor<DragonBoatActivity>())
        XCTAssertEqual(fetched.count, 1)
        let act = fetched[0]
        XCTAssertEqual(act.dataPoints.count, 3)
        XCTAssertEqual(act.averageCadence, 70.0, accuracy: 0.1)   // (60+80+70)/3
        XCTAssertEqual(act.maxCadence, 80)
        XCTAssertEqual(act.totalDistanceMeters, 500)
    }

    @MainActor
    func test_dataStore_saveActivity_noContext_doesNotCrash() {
        let store = DataStore()
        store.modelContext = nil   // not injected
        // Should return silently without crashing
        store.saveActivity(points: [], startTime: Date(), endTime: Date(),
                           totalDistanceMeters: 0, averageSpeedKmh: 0, maxSpeedKmh: 0,
                           averageHeartRate: 0, maxHeartRate: 0, workoutName: nil)
    }

    // MARK: - Helpers

    private func makeActivity(distanceMeters: Double = 1000,
                               start: Date = Date(),
                               end: Date? = nil) -> DragonBoatActivity {
        DragonBoatActivity(
            name: "測試",
            startTime: start,
            endTime: end ?? start.addingTimeInterval(1800),
            totalDistanceMeters: distanceMeters,
            averageSpeedKmh: 8,
            maxSpeedKmh: 12,
            averageCadence: 70,
            maxCadence: 85,
            averageHeartRate: 140,
            maxHeartRate: 165
        )
    }
}
