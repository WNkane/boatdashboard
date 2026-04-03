import SwiftUI

// MARK: - Workout Editor

struct WorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var intervals: [WorkoutInterval]

    private let existingPlan: WorkoutPlan?
    var onSave: (WorkoutPlan) -> Void

    init(plan: WorkoutPlan?, onSave: @escaping (WorkoutPlan) -> Void) {
        self.existingPlan = plan
        self.onSave = onSave
        _name      = State(initialValue: plan?.name ?? "新課表")
        _intervals = State(initialValue: plan?.intervals ?? [WorkoutInterval(durationSeconds: 300, targetHeartRate: 130)])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("課表名稱", text: $name)
                        .foregroundStyle(.white)
                        .listRowBackground(Color(white: 0.15))
                } header: { Text("名稱").foregroundStyle(.gray) }

                Section {
                    ForEach($intervals) { $interval in
                        IntervalEditorRow(interval: $interval)
                            .listRowBackground(Color(white: 0.12))
                            .listRowSeparatorTint(Color.gray.opacity(0.3))
                    }
                    .onMove { intervals.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { intervals.remove(atOffsets: $0) }

                    Button(action: addInterval) {
                        Label("加入區間", systemImage: "plus.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color(white: 0.12))
                } header: {
                    HStack {
                        Text("訓練區間").foregroundStyle(.gray)
                        Spacer()
                        EditButton().font(.caption).foregroundStyle(.orange)
                    }
                }

                Section {
                    IntervalPreviewBar(intervals: intervals).frame(height: 44)
                        .listRowBackground(Color(white: 0.08))
                } header: { Text("課表預覽").foregroundStyle(.gray) }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(existingPlan == nil ? "新增課表" : "編輯課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }.foregroundStyle(.gray)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") {
                        onSave(WorkoutPlan(id: existingPlan?.id ?? UUID(), name: name, intervals: intervals))
                        dismiss()
                    }
                    .foregroundStyle(.orange)
                    .disabled(name.isEmpty || intervals.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func addInterval() {
        intervals.append(WorkoutInterval(durationSeconds: 180, targetHeartRate: 148))
    }
}

// MARK: - Interval Editor Row

struct IntervalEditorRow: View {
    @Binding var interval: WorkoutInterval

    var body: some View {
        VStack(spacing: 10) {
            // Duration
            HStack(spacing: 8) {
                Label("時間", systemImage: "timer")
                    .font(.caption).foregroundStyle(.gray).frame(width: 56, alignment: .leading)

                TextField("分", value: Binding(
                    get: { interval.durationSeconds / 60 },
                    set: { interval.durationSeconds = $0 * 60 + (interval.durationSeconds % 60) }
                ), format: .number)
                .keyboardType(.numberPad).frame(width: 40).multilineTextAlignment(.center).foregroundStyle(.white)

                Text("分").font(.caption).foregroundStyle(.gray)

                TextField("秒", value: Binding(
                    get: { interval.durationSeconds % 60 },
                    set: { interval.durationSeconds = (interval.durationSeconds / 60) * 60 + min(max($0, 0), 59) }
                ), format: .number)
                .keyboardType(.numberPad).frame(width: 40).multilineTextAlignment(.center).foregroundStyle(.white)

                Text("秒").font(.caption).foregroundStyle(.gray)
                Spacer()
                Text(interval.durationFormatted).font(.caption).foregroundStyle(.gray)
            }

            // Heart Rate slider
            HStack(spacing: 8) {
                Label("目標心率", systemImage: "heart.fill")
                    .font(.caption).foregroundStyle(.gray).frame(width: 56, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(interval.targetHeartRate) },
                        set: { interval.targetHeartRate = Int($0) }
                    ),
                    in: 80...195, step: 1
                )
                .tint(HRZone.zone(for: interval.targetHeartRate).color)

                Text("\(interval.targetHeartRate) bpm")
                    .font(.caption.bold())
                    .foregroundStyle(HRZone.zone(for: interval.targetHeartRate).color)
                    .frame(width: 60, alignment: .trailing)
            }

            // Zone indicator
            HStack {
                Spacer()
                let zone = HRZone.zone(for: interval.targetHeartRate)
                Text("\(zone.label) \(zone.name)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(zone.color))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Interval Preview Bar

struct IntervalPreviewBar: View {
    let intervals: [WorkoutInterval]
    private var total: Int { intervals.reduce(0) { $0 + $1.durationSeconds } }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(intervals) { interval in
                    let w = total > 0
                        ? geo.size.width * CGFloat(interval.durationSeconds) / CGFloat(total)
                        : 0
                    let zone = HRZone.zone(for: interval.targetHeartRate)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(hrGradient(zone.color))
                        .frame(width: max(w - 1, 0))
                        .overlay(alignment: .bottom) {
                            if w > 28 {
                                Text("\(interval.targetHeartRate)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.7))
                                    .padding(.bottom, 2)
                            }
                        }
                }
            }
        }
    }

    private func hrGradient(_ c: Color) -> LinearGradient {
        LinearGradient(colors: [c.opacity(0.7), c], startPoint: .bottom, endPoint: .top)
    }
}
