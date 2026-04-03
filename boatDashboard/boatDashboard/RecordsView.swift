import SwiftUI
import Charts

// MARK: - Records List

struct RecordsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedRecord: TrainingRecord? = nil

    var body: some View {
        Group {
            if dataStore.records.isEmpty {
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
                List(dataStore.records) { record in
                    RecordRow(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedRecord = record }
                        .listRowBackground(Color(white: 0.1))
                        .listRowSeparatorTint(Color.gray.opacity(0.3))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black.ignoresSafeArea())
            }
        }
        .navigationTitle("訓練紀錄")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $selectedRecord) { record in
            RecordSummaryView(record: record)
        }
    }
}

// MARK: - Record Row

struct RecordRow: View {
    let record: TrainingRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(record.dateFormatted)
                        .font(.subheadline.bold()).foregroundStyle(.white)
                    if let name = record.workoutName {
                        Text(name)
                            .font(.caption).foregroundStyle(.orange)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 14) {
                    Label(String(format: "%.2f km", record.distanceKm), systemImage: "arrow.triangle.swap")
                        .font(.caption).foregroundStyle(.gray)
                    Label(String(format: "%.1f km/h", record.averageSpeedKmh), systemImage: "speedometer")
                        .font(.caption).foregroundStyle(.gray)
                    Label(record.durationFormatted, systemImage: "timer")
                        .font(.caption).foregroundStyle(.gray)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if record.maxHeartRate > 0 {
                    let zone = HRZone.zone(for: record.maxHeartRate)
                    Text("\(record.maxHeartRate)")
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

// MARK: - Record Summary View

struct RecordSummaryView: View {
    let record: TrainingRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Stat grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCardDetail(label: "總距離",   value: String(format: "%.2f", record.distanceKm),         unit: "km",   color: .cyan,   icon: "road.lanes")
                        StatCardDetail(label: "時間",     value: record.durationFormatted,                          unit: "",     color: .white,  icon: "timer")
                        StatCardDetail(label: "均速",     value: String(format: "%.1f", record.averageSpeedKmh),    unit: "km/h", color: .orange, icon: "speedometer")
                        StatCardDetail(label: "最高時速", value: String(format: "%.1f", record.maxSpeedKmh),        unit: "km/h", color: .orange, icon: "gauge.with.needle")
                        StatCardDetail(label: "平均心率", value: record.averageHeartRate > 0 ? "\(record.averageHeartRate)" : "--", unit: "bpm",
                                       color: HRZone.zone(for: record.averageHeartRate).color, icon: "heart.fill")
                        StatCardDetail(label: "最高心率", value: record.maxHeartRate > 0 ? "\(record.maxHeartRate)" : "--",       unit: "bpm",
                                       color: HRZone.zone(for: record.maxHeartRate).color,     icon: "heart.circle.fill")
                    }
                    .padding(.horizontal)

                    // Speed history chart
                    if !record.speedHistory.isEmpty {
                        SpeedChart(speedHistory: record.speedHistory)
                            .frame(height: 180)
                            .padding(.horizontal)
                    }

                    // Cadence chart (Vaaka data)
                    if !record.cadenceHistory.isEmpty {
                        CadenceChart(
                            cadenceHistory: record.cadenceHistory,
                            average: record.averageCadence,
                            max: record.maxCadence
                        )
                        .frame(height: 160)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(record.dateFormatted)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Stat Card Detail

struct StatCardDetail: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption).foregroundStyle(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(.caption).foregroundStyle(.gray)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1)))
    }
}

// MARK: - Cadence Chart (Vaaka sensor data)

struct CadenceChart: View {
    let cadenceHistory: [Int]
    let average: Double
    let max: Int

    private var data: [(index: Int, rpm: Double)] {
        cadenceHistory.enumerated().map { (index: $0.offset, rpm: Double($0.element)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("槳頻 (Vaaka)", systemImage: "oar.2.crossed")
                    .font(.caption).foregroundStyle(.gray)
                Spacer()
                Text("均值 \(Int(average)) rpm · 最高 \(max) rpm")
                    .font(.caption2).foregroundStyle(.purple)
            }

            Chart(data, id: \.index) { item in
                AreaMark(
                    x: .value("樣本", item.index),
                    y: .value("槳頻", item.rpm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.45), Color.purple.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("樣本", item.index),
                    y: .value("槳頻", item.rpm)
                )
                .foregroundStyle(Color.purple)
                .lineStyle(StrokeStyle(lineWidth: 2))

                RuleMark(y: .value("均值", average))
                    .foregroundStyle(Color.purple.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                    AxisValueLabel().foregroundStyle(Color.gray)
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color(white: 0.08))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1)))
    }
}
