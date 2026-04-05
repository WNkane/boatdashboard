import SwiftUI
import SwiftData
import Charts

// MARK: - Dashboard Home

struct DashboardHomeView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Query(sort: \DragonBoatActivity.startTime, order: .reverse)
    private var activities: [DragonBoatActivity]

    private var lastActivity: DragonBoatActivity? { activities.first }

    private var weeklyData: [(day: String, km: Double)] {
        let calendar = Calendar.current
        let now = Date()
        let weekdays = ["週一", "週二", "週三", "週四", "週五", "週六", "週日"]
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: now)!
            let weekdayIdx = (calendar.component(.weekday, from: date) + 5) % 7
            let km = activities
                .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
                .reduce(0) { $0 + $1.distanceKm }
            return (day: weekdays[weekdayIdx], km: km)
        }
    }

    private var weekTotalKm: Double { weeklyData.reduce(0) { $0 + $1.km } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                WeatherStatusRow(weather: locationManager.stationWeather)
                    .padding(.horizontal, 4)

                if let activity = lastActivity {
                    LastPerformanceCard(activity: activity)
                } else {
                    NoRideCard()
                }
                WeeklyMileageChart(data: weeklyData, totalKm: weekTotalKm)
                Spacer(minLength: 40)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("首頁")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Last Performance Card

struct LastPerformanceCard: View {
    let activity: DragonBoatActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("最近一次表現", systemImage: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text(activity.dateFormatted)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }

            Divider().background(Color.gray.opacity(0.3))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 14
            ) {
                SummaryMetric(label: "距離",    value: String(format: "%.2f", activity.distanceKm),       unit: "km",   color: .cyan)
                SummaryMetric(label: "均速",    value: String(format: "%.1f", activity.averageSpeedKmh),  unit: "km/h", color: .orange)
                SummaryMetric(label: "時間",    value: activity.durationFormatted,                        unit: "",     color: .white)
                SummaryMetric(label: "平均心率", value: activity.averageHeartRate > 0 ? "\(activity.averageHeartRate)" : "--",
                              unit: "bpm", color: HRZone.zone(for: activity.averageHeartRate).color)
                SummaryMetric(label: "最高心率", value: activity.maxHeartRate > 0 ? "\(activity.maxHeartRate)" : "--",
                              unit: "bpm", color: HRZone.zone(for: activity.maxHeartRate).color)
                SummaryMetric(label: "槳頻",    value: String(format: "%.0f", activity.averageCadence),  unit: "spm",  color: .purple)
            }

            if let name = activity.workoutName {
                Label(name, systemImage: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.1)))
    }
}

struct SummaryMetric: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 9)).foregroundStyle(.gray)
                }
            }
        }
    }
}

struct NoRideCard: View {
    var body: some View {
        VStack(spacing: 12) {
            DragonBoatIcon(size: 72, showLabel: false)
            Text("尚無划槳紀錄")
                .font(.headline).foregroundStyle(.white)
            Text("點擊選單的「開始划槳」開始你的第一趟訓練")
                .font(.caption).foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.1)))
    }
}

// MARK: - Weekly Mileage Chart

struct WeeklyMileageChart: View {
    let data: [(day: String, km: Double)]
    let totalKm: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("本週里程", systemImage: "road.lanes")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text(String(format: "%.1f km", totalKm))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            Chart(data, id: \.day) { item in
                BarMark(
                    x: .value("日期", item.day),
                    y: .value("里程", item.km)
                )
                .foregroundStyle(
                    item.km > 0
                        ? LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
                        : LinearGradient(colors: [Color(white: 0.2)], startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.gray)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel().foregroundStyle(Color.gray)
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color(white: 0.05))
            }
            .frame(height: 160)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(white: 0.1)))
    }
}
