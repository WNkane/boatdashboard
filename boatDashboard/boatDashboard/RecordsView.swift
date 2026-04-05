import SwiftUI
import SwiftData
import Charts

// MARK: - Records List

struct RecordsView: View {
    @Query(sort: \DragonBoatActivity.startTime, order: .reverse)
    private var activities: [DragonBoatActivity]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedActivity: DragonBoatActivity? = nil

    var body: some View {
        Group {
            if activities.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 44)).foregroundStyle(.gray)
                    Text("尚無訓練紀錄")
                        .font(.headline).foregroundStyle(.white)
                    Text("完成第一次划槳後紀錄將出現在這裡")
                        .font(.caption).foregroundStyle(.gray).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            } else {
                List {
                    ForEach(activities) { activity in
                        ActivityRow(activity: activity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedActivity = activity }
                            .listRowBackground(Color(white: 0.1))
                            .listRowSeparatorTint(Color.gray.opacity(0.3))
                    }
                    .onDelete(perform: deleteActivities)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black.ignoresSafeArea())
            }
        }
        .navigationTitle("訓練紀錄")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedActivity) { activity in
            ActivityDetailView(activity: activity)
        }
    }

    private func deleteActivities(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(activities[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: DragonBoatActivity

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(activity.dateFormatted)
                        .font(.subheadline.bold()).foregroundStyle(.white)
                    if let name = activity.workoutName {
                        Text(name)
                            .font(.caption).foregroundStyle(.orange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 14) {
                    Label(String(format: "%.2f km", activity.distanceKm),
                          systemImage: "arrow.triangle.swap")
                        .font(.caption).foregroundStyle(.gray)
                    Label(String(format: "%.1f km/h", activity.averageSpeedKmh),
                          systemImage: "speedometer")
                        .font(.caption).foregroundStyle(.gray)
                    Label(activity.durationFormatted, systemImage: "timer")
                        .font(.caption).foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if activity.maxHeartRate > 0 {
                    let zone = HRZone.zone(for: activity.maxHeartRate)
                    Text("\(activity.maxHeartRate)")
                        .font(.headline.bold()).foregroundStyle(zone.color)
                    HStack(spacing: 4) {
                        Text(zone.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(zone.color))
                        Text("bpm").font(.caption2).foregroundStyle(.gray)
                    }
                } else {
                    Text("--").font(.headline.bold()).foregroundStyle(.gray)
                    Text("最高心率").font(.caption2).foregroundStyle(.gray)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
