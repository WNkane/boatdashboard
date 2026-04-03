import Foundation
import SwiftUI

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
