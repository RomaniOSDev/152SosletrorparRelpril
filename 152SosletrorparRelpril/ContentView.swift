//
//  ContentView.swift
//  152SosletrorparRelpril
//
//  Created by Roman on 5/7/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var taskManager = TaskManager()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if hasSeenOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    hasSeenOnboarding = true
                }
            }
        }
        .environmentObject(taskManager)
        .preferredColorScheme(.dark)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "rectangle.grid.2x2")
            }

            NavigationStack {
                TimelineTabView()
            }
            .tabItem {
                Label("Timeline", systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                ReportsView()
            }
            .tabItem {
                Label("Reports", systemImage: "doc.text.magnifyingglass")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(.appPrimary)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
