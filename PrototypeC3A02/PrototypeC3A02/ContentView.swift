//
//  ContentView.swift
//  PrototypeC3A02
//
//  Created by Rangga Rijasa on 04/07/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var modelLibrary = LocalModelLibrary()
    @StateObject private var runtimeSession = LocalLLMRuntimeSession()

    var body: some View {
        TabView {
            DataListView()
                .tabItem {
                    Label("Data", systemImage: "tray.full")
                }

            DashboardView(library: modelLibrary, runtimeSession: runtimeSession)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }

            ModelSelectionView(library: modelLibrary, runtimeSession: runtimeSession)
                .tabItem {
                    Label("Models", systemImage: "gearshape")
                }
        }
        .task {
            SampleDataSeeder.preloadIfNeeded(in: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: StoryEvent.self, inMemory: true)
}
