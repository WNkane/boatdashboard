import Foundation
import SwiftUI
import SwiftData
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - SwiftData Models

@Model
class ActivityDataPoint {
    var timestamp: Date
    var speedKmh: Double
    var cadenceSpm: Int
    var heartRateBpm: Int
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double
    var activity: DragonBoatActivity?

    init(timestamp: Date, speedKmh: Double, cadenceSpm: Int,
         heartRateBpm: Int, latitude: Double, longitude: Double,
         altitudeMeters: Double) {
        self.timestamp      = timestamp
        self.speedKmh       = speedKmh
        self.cadenceSpm     = cadenceSpm
        self.heartRateBpm   = heartRateBpm
        self.latitude       = latitude
        self.longitude      = longitude
        self.altitudeMeters = altitudeMeters
    }
}

@Model
class DragonBoatActivity {
    var id: UUID
    var name: String
    var startTime: Date
    var endTime: Date?
    var totalDistanceMeters: Double
    var averageSpeedKmh: Double
    var maxSpeedKmh: Double
    var averageCadence: Double
    var maxCadence: Int
    var averageHeartRate: Int
    var maxHeartRate: Int
    var workoutName: String?
    @Relationship(deleteRule: .cascade, inverse: \ActivityDataPoint.activity)
    var dataPoints: [ActivityDataPoint] = []

    init(id: UUID = UUID(), name: String, startTime: Date,
         endTime: Date? = nil, totalDistanceMeters: Double,
         averageSpeedKmh: Double, maxSpeedKmh: Double,
         averageCadence: Double, maxCadence: Int,
         averageHeartRate: Int, maxHeartRate: Int,
         workoutName: String? = nil) {
        self.id                   = id
        self.name                 = name
        self.startTime            = startTime
        self.endTime              = endTime
        self.totalDistanceMeters  = totalDistanceMeters
        self.averageSpeedKmh      = averageSpeedKmh
        self.maxSpeedKmh          = maxSpeedKmh
        self.averageCadence       = averageCadence
        self.maxCadence           = maxCadence
        self.averageHeartRate     = averageHeartRate
        self.maxHeartRate         = maxHeartRate
        self.workoutName          = workoutName
    }

    var distanceKm: Double { totalDistanceMeters / 1000 }

    var durationSeconds: Int {
        guard let end = endTime else { return 0 }
        return Int(end.timeIntervalSince(startTime))
    }

    var durationFormatted: String {
        let s = durationSeconds
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }

    var dateFormatted: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: "zh_TW")
        return fmt.string(from: startTime)
    }
}

// MARK: - Live Activity Attributes

#if canImport(ActivityKit)
struct DragonBoatActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var speedKmh: Double
        var heartRate: Int
        var hrZoneName: String
        var hrZoneColorHex: String   // hex string, e.g. "#FF3366"
        var cadenceSpm: Int
        var elapsedSeconds: Int
        var distanceKm: Double
        var intervalIndex: Int       // 0 = 無課表
        var totalIntervals: Int
        var intervalRemainingSeconds: Int
    }

    var workoutName: String?
    var startTime: Date
}
#endif

// MARK: - HRZone hex helper

extension HRZone {
    var colorHex: String {
        switch self {
        case .zone1: return "#999999"
        case .zone2: return "#3399FF"
        case .zone3: return "#33CC66"
        case .zone4: return "#FF8800"
        case .zone5: return "#FF2233"
        }
    }
}

// MARK: - Pending DataPoint (value type for in-memory accumulation)

struct PendingDataPoint {
    let timestamp: Date
    let speedKmh: Double
    let cadenceSpm: Int
    let heartRateBpm: Int
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double
}

// MARK: - Heart Rate Zone

enum HRZone: Int {
    case zone1 = 1, zone2, zone3, zone4, zone5

    static func zone(for bpm: Int) -> HRZone {
        guard bpm > 0 else { return .zone1 }
        switch bpm {
        case ..<115: return .zone1
        case ..<138: return .zone2
        case ..<155: return .zone3
        case ..<171: return .zone4
        default:     return .zone5
        }
    }

    var label: String { "Z\(rawValue)" }

    var name: String {
        switch self {
        case .zone1: return "恢復"
        case .zone2: return "有氧基礎"
        case .zone3: return "有氧"
        case .zone4: return "臨界"
        case .zone5: return "最大強度"
        }
    }

    var color: Color {
        switch self {
        case .zone1: return Color(white: 0.6)
        case .zone2: return .blue
        case .zone3: return .green
        case .zone4: return .orange
        case .zone5: return .red
        }
    }
}

// MARK: - Workout Models

struct WorkoutInterval: Identifiable, Codable, Equatable {
    var id = UUID()
    var durationSeconds: Int
    var targetHeartRate: Int   // bpm

    var durationFormatted: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return s == 0 ? "\(m)分" : "\(m):\(String(format: "%02d", s))"
    }
}

struct WorkoutPlan: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var intervals: [WorkoutInterval]

    static func == (lhs: WorkoutPlan, rhs: WorkoutPlan) -> Bool { lhs.id == rhs.id }

    var totalDurationSeconds: Int { intervals.reduce(0) { $0 + $1.durationSeconds } }

    var totalDurationFormatted: String {
        let total = totalDurationSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)min" : "\(m)min"
    }
}

// MARK: - Training Record

struct TrainingRecord: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var durationSeconds: Int
    var totalDistanceMeters: Double
    var averageSpeedKmh: Double
    var maxSpeedKmh: Double
    var totalElevationGain: Double
    var speedHistory: [Double]
    var cadenceHistory: [Int]
    var averageCadence: Double
    var maxCadence: Int
    var workoutName: String?
    var heartRateHistory: [Int]
    var averageHeartRate: Int
    var maxHeartRate: Int

    var distanceKm: Double { totalDistanceMeters / 1000 }

    var dateFormatted: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: "zh_TW")
        return fmt.string(from: date)
    }

    var durationFormatted: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
