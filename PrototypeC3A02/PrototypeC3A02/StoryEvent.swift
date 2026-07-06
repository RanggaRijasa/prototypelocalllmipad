//
//  StoryEvent.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import Foundation
import SwiftData

enum StoryScene: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .night: "Night"
        }
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy
    case sad
    case angry
    case tired
    case excited
    case scared

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy: "Happy"
        case .sad: "Sad"
        case .angry: "Angry"
        case .tired: "Tired"
        case .excited: "Excited"
        case .scared: "Scared"
        }
    }

    var numericScore: Double {
        switch self {
        case .sad: 1
        case .angry: 2
        case .scared: 2.5
        case .tired: 3
        case .happy: 5
        case .excited: 6
        }
    }

    var isChallenging: Bool {
        switch self {
        case .sad, .angry, .tired, .scared: true
        case .happy, .excited: false
        }
    }
}

enum Place: String, Codable, CaseIterable, Identifiable {
    case home
    case school
    case park
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: "Home"
        case .school: "School"
        case .park: "Park"
        case .other: "Other"
        }
    }
}

@Model
final class StoryEvent {
    @Attribute(.unique) var id: UUID
    var childName: String
    var childAge: Int
    var childGender: String
    var scene: StoryScene
    var place: Place
    var activity: String
    var mood: Mood
    var reason: String?
    var parentNote: String?
    var date: Date

    init(
        id: UUID = UUID(),
        childName: String,
        childAge: Int,
        childGender: String,
        scene: StoryScene,
        place: Place,
        activity: String,
        mood: Mood,
        reason: String? = nil,
        parentNote: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.childName = childName
        self.childAge = childAge
        self.childGender = childGender
        self.scene = scene
        self.place = place
        self.activity = activity
        self.mood = mood
        self.reason = reason
        self.parentNote = parentNote
        self.date = date
    }
}
