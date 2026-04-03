import SwiftUI

// MARK: - Route

enum AppRoute: Equatable {
    case dashboard
    case workout
    case records
    case live(WorkoutPlan?)
}

// MARK: - App Root

struct AppView: View {
    @StateObject private var dataStore = DataStore()
    @State private var currentRoute: AppRoute = .dashboard
    @State private var menuOpen = false

    var body: some View {
        ZStack {
            mainContent
                .disabled(menuOpen)
                .blur(radius: menuOpen ? 1.5 : 0)
                .animation(.easeInOut(duration: 0.2), value: menuOpen)

            if menuOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { menuOpen = false } }
                    .transition(.opacity)
            }

            SideMenuView(currentRoute: $currentRoute, menuOpen: $menuOpen)
        }
        .environmentObject(dataStore)
        .environmentObject(dataStore.locationManager)
        .preferredColorScheme(.dark)
    }

    private var isLive: Bool {
        if case .live = currentRoute { return true }
        return false
    }

    private var mainContent: some View {
        NavigationStack {
            routeView
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if !isLive {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    menuOpen.toggle()
                                }
                            }) {
                                Image(systemName: menuOpen ? "xmark" : "line.3.horizontal")
                                    .foregroundStyle(.orange)
                                    .font(.title3)
                                    .animation(.easeInOut(duration: 0.2), value: menuOpen)
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var routeView: some View {
        switch currentRoute {
        case .dashboard:
            DashboardHomeView()
        case .workout:
            WorkoutListView(currentRoute: $currentRoute)
        case .records:
            RecordsView()
        case .live(let plan):
            LiveDashboardView(currentRoute: $currentRoute, workoutPlan: plan)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Side Menu

struct SideMenuView: View {
    @Binding var currentRoute: AppRoute
    @Binding var menuOpen: Bool

    private struct MenuItem {
        let route: AppRoute
        let title: String
        let icon: String
    }

    private let items: [MenuItem] = [
        MenuItem(route: .dashboard, title: "首頁",     icon: "house.fill"),
        MenuItem(route: .workout,   title: "課表",     icon: "list.bullet.clipboard"),
        MenuItem(route: .records,   title: "訓練紀錄", icon: "chart.bar.fill"),
        MenuItem(route: .live(nil), title: "開始划槳", icon: "oar.2.crossed"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {

                // App header with DragonBoatIcon
                VStack(alignment: .leading, spacing: 6) {
                    DragonBoatIcon(size: 64, showLabel: false)
                    Text("龍舟儀表板")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Dragon Boat Pro")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding(.top, 64)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)

                Divider().background(Color.gray.opacity(0.2)).padding(.horizontal, 24)
                    .padding(.bottom, 8)

                // Menu items
                ForEach(items, id: \.title) { item in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { menuOpen = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                            currentRoute = item.route
                        }
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.body)
                                .frame(width: 24)
                                .foregroundStyle(isActive(item.route) ? .orange : .gray)

                            Text(item.title)
                                .font(.body.weight(isActive(item.route) ? .semibold : .regular))
                                .foregroundStyle(isActive(item.route) ? .white : .gray)

                            Spacer()

                            if isActive(item.route) {
                                Capsule()
                                    .fill(Color.orange)
                                    .frame(width: 4, height: 20)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            isActive(item.route)
                                ? Color.orange.opacity(0.1)
                                : Color.clear
                        )
                    }
                }

                Spacer()

                Text("v1.0  ·  Dragon Boat Pro")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .frame(width: 270)
            .background(Color(white: 0.07))
            .offset(x: menuOpen ? 0 : -270)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: menuOpen)

            Spacer()
        }
        .ignoresSafeArea()
    }

    private func isActive(_ route: AppRoute) -> Bool {
        switch (currentRoute, route) {
        case (.dashboard, .dashboard): return true
        case (.workout, .workout):     return true
        case (.records, .records):     return true
        case (.live, .live):           return true
        default:                       return false
        }
    }
}
