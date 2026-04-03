import SwiftUI

// MARK: - Workout List

struct WorkoutListView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var currentRoute: AppRoute
    @State private var showEditor = false
    @State private var editingPlan: WorkoutPlan? = nil

    var body: some View {
        Group {
            if dataStore.workouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.largeTitle).foregroundStyle(.gray)
                    Text("尚無課表").font(.headline).foregroundStyle(.white)
                    Button(action: { editingPlan = nil; showEditor = true }) {
                        Label("新增課表", systemImage: "plus")
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            } else {
                List {
                    ForEach(dataStore.workouts) { plan in
                        WorkoutRow(plan: plan) {
                            currentRoute = .live(plan)
                        } onEdit: {
                            editingPlan = plan
                            showEditor = true
                        }
                        .listRowBackground(Color(white: 0.1))
                        .listRowSeparatorTint(Color.gray.opacity(0.3))
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { dataStore.deleteWorkout(dataStore.workouts[$0]) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black.ignoresSafeArea())
            }
        }
        .navigationTitle("課表")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { editingPlan = nil; showEditor = true }) {
                    Image(systemName: "plus").foregroundStyle(.orange)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            WorkoutEditorView(plan: editingPlan) { saved in
                dataStore.saveWorkout(saved)
            }
        }
    }
}

// MARK: - Workout Row

struct WorkoutRow: View {
    let plan: WorkoutPlan
    let onExecute: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.headline).foregroundStyle(.white)
                    Text("\(plan.intervals.count) 組  ·  \(plan.totalDurationFormatted)")
                        .font(.caption).foregroundStyle(.gray)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .foregroundStyle(.gray).font(.title3)
                }
                .buttonStyle(.plain)

                Button(action: onExecute) {
                    Label("執行", systemImage: "play.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Interval preview bar (HR zone colors)
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(plan.intervals) { interval in
                        let w = plan.totalDurationSeconds > 0
                            ? geo.size.width * CGFloat(interval.durationSeconds) / CGFloat(plan.totalDurationSeconds)
                            : 0
                        let zone = HRZone.zone(for: interval.targetHeartRate)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(
                                colors: [zone.color.opacity(0.7), zone.color],
                                startPoint: .bottom, endPoint: .top
                            ))
                            .frame(width: max(w - 1, 2))
                            .overlay(alignment: .bottom) {
                                if w > 32 {
                                    Text("\(interval.targetHeartRate)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.black.opacity(0.7))
                                        .padding(.bottom, 2)
                                }
                            }
                    }
                }
                .frame(height: 28)
            }
            .frame(height: 28)
        }
        .padding(.vertical, 10)
    }
}
