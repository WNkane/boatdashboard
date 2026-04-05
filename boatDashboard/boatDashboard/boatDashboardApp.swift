//
//  boatDashboardApp.swift
//  boatDashboard
//
//  Created by 王文楷 on 2026/3/15.
//

import SwiftUI
import SwiftData

@main
struct boatDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .modelContainer(for: [DragonBoatActivity.self, ActivityDataPoint.self])
    }
}
