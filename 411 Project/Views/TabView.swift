//
//  TabView.swift
//  411 Project
//
//  Created by Larry on 9/5/26.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CollectionsView()
            .tabItem {
                Label("Collection", systemImage: "square.stack.fill")
            }
            .tag(0)
            
            NavigationStack {
                Text("Expansions Page Placeholder")
                    .navigationTitle("Expansions")
            }
            .tabItem {
                Label("Sets", systemImage: "square.grid.2x2.fill")
            }
            .tag(1)

            ContentView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(2)

            SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
    }
}
