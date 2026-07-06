//
//  StoryEventPersistenceTests.swift
//  PrototypeC3A02Tests
//
//  Created by Codex on 04/07/26.
//

import SwiftData
import XCTest
@testable import PrototypeC3A02

@MainActor
final class StoryEventPersistenceTests: XCTestCase {
    func testInsertAndFetchStoryEvent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let event = StoryEvent(
            childName: "Leo",
            childAge: 4,
            childGender: "M",
            scene: .morning,
            place: .home,
            activity: "Breakfast",
            mood: .happy,
            reason: "Slept well",
            parentNote: "Woke up cheerfully",
            date: Date()
        )

        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<StoryEvent>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.childName, "Leo")
        XCTAssertEqual(fetched.first?.scene, .morning)
        XCTAssertEqual(fetched.first?.mood, .happy)
    }

    func testPreloadDataCreatesAWeekOfEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext

        SampleDataSeeder.preloadIfNeeded(in: context)

        let fetched = try context.fetch(FetchDescriptor<StoryEvent>())
        let uniqueDays = Set(fetched.map { Calendar.current.startOfDay(for: $0.date) })
        let eventsByDay = Dictionary(grouping: fetched) { Calendar.current.startOfDay(for: $0.date) }

        XCTAssertGreaterThanOrEqual(fetched.count, 35)
        XCTAssertGreaterThanOrEqual(uniqueDays.count, 7)
        XCTAssertTrue(eventsByDay.values.allSatisfy { (5...10).contains($0.count) })

        SampleDataSeeder.preloadIfNeeded(in: context)

        let fetchedAfterSecondPreload = try context.fetch(FetchDescriptor<StoryEvent>())
        XCTAssertEqual(fetchedAfterSecondPreload.count, fetched.count)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([StoryEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
