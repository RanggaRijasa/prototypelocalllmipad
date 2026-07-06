//
//  PrototypeC3A02App.swift
//  PrototypeC3A02
//
//  Created by Rangga Rijasa on 04/07/26.
//

import SwiftUI
import SwiftData

@main
struct PrototypeC3A02App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: StoryEvent.self)
    }
}
