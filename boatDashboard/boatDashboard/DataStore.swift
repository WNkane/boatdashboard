import Foundation

class DataStore: ObservableObject {
    @Published var workouts: [WorkoutPlan] = []
    @Published var records: [TrainingRecord] = []

    let locationManager = LocationManager()

    private let workoutsKey = "savedWorkouts_v3"   // HR-based intervals
    private let recordsKey  = "savedRecords_v2"    // HR fields added

    init() {
        loadWorkouts()
        loadRecords()
        if workouts.isEmpty { seedDefaultWorkouts() }
    }

    // MARK: - Workouts

    func saveWorkout(_ plan: WorkoutPlan) {
        if let idx = workouts.firstIndex(where: { $0.id == plan.id }) {
            workouts[idx] = plan
        } else {
            workouts.append(plan)
        }
        persist(workouts, key: workoutsKey)
    }

    func deleteWorkout(_ plan: WorkoutPlan) {
        workouts.removeAll { $0.id == plan.id }
        persist(workouts, key: workoutsKey)
    }

    // MARK: - Records

    func saveRecord(_ record: TrainingRecord) {
        records.insert(record, at: 0)
        persist(records, key: recordsKey)
    }

    // MARK: - Persistence

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadWorkouts() {
        guard let data = UserDefaults.standard.data(forKey: workoutsKey),
              let decoded = try? JSONDecoder().decode([WorkoutPlan].self, from: data)
        else { return }
        workouts = decoded
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let decoded = try? JSONDecoder().decode([TrainingRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func seedDefaultWorkouts() {
        workouts = [
            // ── 200m 衝刺 (3組) ─────────────────────────────────────────
            // Z1 暖身 → Z5 衝刺30s × 3（中間 Z1 恢復）→ Z1 緩和
            WorkoutPlan(name: "200m 衝刺 (3組)", intervals: [
                WorkoutInterval(durationSeconds: 300, targetHeartRate: 110), // 暖身 5min  Z1
                WorkoutInterval(durationSeconds:  30, targetHeartRate: 178), // 衝刺 #1   Z5
                WorkoutInterval(durationSeconds: 120, targetHeartRate: 100), // 恢復 2min  Z1
                WorkoutInterval(durationSeconds:  30, targetHeartRate: 178), // 衝刺 #2   Z5
                WorkoutInterval(durationSeconds: 120, targetHeartRate: 100), // 恢復 2min  Z1
                WorkoutInterval(durationSeconds:  30, targetHeartRate: 178), // 衝刺 #3   Z5
                WorkoutInterval(durationSeconds: 300, targetHeartRate: 108), // 緩和 5min  Z1
            ]),

            // ── 1000m 耐力划 ────────────────────────────────────────────
            // Z1 暖身 → Z3 穩定有氧 → Z4 衝刺收尾 → Z1 緩和
            WorkoutPlan(name: "1000m 耐力划", intervals: [
                WorkoutInterval(durationSeconds: 300,  targetHeartRate: 110), // 暖身 5min   Z1
                WorkoutInterval(durationSeconds: 1200, targetHeartRate: 148), // 穩定 20min  Z3
                WorkoutInterval(durationSeconds: 300,  targetHeartRate: 163), // 收尾 5min   Z4
                WorkoutInterval(durationSeconds: 300,  targetHeartRate: 108), // 緩和 5min   Z1
            ]),

            // ── 3-2-1 金字塔訓練 ────────────────────────────────────────
            // 強度逐步上升再下降，訓練乳酸耐受力
            WorkoutPlan(name: "3-2-1 金字塔訓練", intervals: [
                WorkoutInterval(durationSeconds: 300, targetHeartRate: 110), // 暖身 5min  Z1
                WorkoutInterval(durationSeconds: 180, targetHeartRate: 158), // 3min       Z4
                WorkoutInterval(durationSeconds:  60, targetHeartRate:  95), // 休息 1min
                WorkoutInterval(durationSeconds: 120, targetHeartRate: 168), // 2min       Z4/5
                WorkoutInterval(durationSeconds:  60, targetHeartRate:  95), // 休息 1min
                WorkoutInterval(durationSeconds:  60, targetHeartRate: 180), // 1min 衝刺  Z5
                WorkoutInterval(durationSeconds:  60, targetHeartRate:  95), // 休息 1min
                WorkoutInterval(durationSeconds: 120, targetHeartRate: 168), // 2min       Z4/5
                WorkoutInterval(durationSeconds:  60, targetHeartRate:  95), // 休息 1min
                WorkoutInterval(durationSeconds: 180, targetHeartRate: 158), // 3min       Z4
                WorkoutInterval(durationSeconds: 300, targetHeartRate: 108), // 緩和 5min  Z1
            ]),
        ]
        persist(workouts, key: workoutsKey)
    }
}
