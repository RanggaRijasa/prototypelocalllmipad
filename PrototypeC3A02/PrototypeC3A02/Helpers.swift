//
//  Helpers.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import CoreML
import Foundation
import SwiftData

struct ChartBucket: Identifiable {
    let category: String
    let mood: Mood
    let count: Int

    var id: String { "\(category)-\(mood.rawValue)" }
}

struct DailyMoodPoint: Identifiable {
    let date: Date
    let averageScore: Double
    let eventCount: Int

    var id: Date { date }
}

struct DailyEventCountPoint: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

struct SceneChallengePoint: Identifiable {
    let scene: String
    let challengingCount: Int
    let totalCount: Int

    var id: String { scene }

    var challengingPercent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(challengingCount) / Double(totalCount) * 100
    }
}

struct ActivityCountPoint: Identifiable {
    let activity: String
    let count: Int

    var id: String { activity }
}

enum AnalysisEngine: String, CaseIterable, Identifiable {
    case simpleRules
    case coreMLClassifier
    case localLLM
    case llmSummariser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simpleRules: "Simple Rules"
        case .coreMLClassifier: "Core ML Classifier"
        case .localLLM: "Local LLM"
        case .llmSummariser: "LLM Summariser"
        }
    }

    var description: String {
        switch self {
        case .simpleRules:
            "Counts moods, scenes, places, and time trends on device. This is the default offline prototype engine."
        case .coreMLClassifier:
            "Loads a downloaded or bundled Core ML model and attempts mood classification from scene, place, and activity features."
        case .localLLM:
            "Loads a LiteRT-LM model on device to generate structured dashboard insights from local story data."
        case .llmSummariser:
            "Legacy placeholder for a future summariser. Use Local LLM for the new on-device model flow."
        }
    }

    var trainingInfo: String {
        switch self {
        case .simpleRules:
            "No training data. Uses deterministic Swift rules over locally stored events."
        case .coreMLClassifier:
            "Demo model slot. Train a small labelled classifier outside the app, then download a .mlmodel file here."
        case .localLLM:
            "Use `.litertlm` files from the curated Gemma catalog or Hugging Face import. The app loads the model into RAM only when requested."
        case .llmSummariser:
            "Superseded by the Local LLM flow."
        }
    }
}

struct MoodPrediction {
    let mood: Mood
    let confidence: Double
    let explanation: String
}

enum SampleDataSeeder {
    @MainActor
    static func preloadIfNeeded(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<StoryEvent>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let cleanup = removeDuplicateSampleActivities(from: existing, in: modelContext)
        let existingKeys = Set(cleanup.events.map(seedKey))
        let missingEvents = sampleEvents(relativeTo: Date()).filter { event in
            !existingKeys.contains(seedKey(for: event))
        }
        guard cleanup.didDelete || !missingEvents.isEmpty else { return }

        for event in missingEvents {
            modelContext.insert(event)
        }

        try? modelContext.save()
    }

    static func makeTestEvent(date: Date = Date()) -> StoryEvent {
        let samples = sampleEvents(relativeTo: date)
        return samples.randomElement() ?? StoryEvent(
            childName: "Leo",
            childAge: 4,
            childGender: "M",
            scene: .morning,
            place: .home,
            activity: "Breakfast",
            mood: .happy,
            reason: "Slept well",
            parentNote: "Woke up cheerfully",
            date: date
        )
    }

    static func sampleEvents(relativeTo referenceDate: Date) -> [StoryEvent] {
        let calendar = Calendar.current
        let dayStarts = (0..<7).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: referenceDate))
        }

        let dayPlans: [[DailySample]] = [
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Wake-up cuddle", mood: .happy, reason: "Slept well", parentNote: "Asked for a song before getting dressed"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .happy, reason: "Liked the fruit choice", parentNote: "Ate calmly and chatted"),
                DailySample(hour: 9, scene: .morning, place: .school, activity: "Drop-off", mood: .sad, reason: "Wanted one more hug", parentNote: "Recovered after teacher greeting"),
                DailySample(hour: 10, scene: .morning, place: .school, activity: "Story circle", mood: .excited, reason: "Shared a favorite character", parentNote: "Very talkative at pickup"),
                DailySample(hour: 12, scene: .afternoon, place: .school, activity: "Lunch", mood: .happy, reason: "Sat with a close friend", parentNote: "Finished most of the meal"),
                DailySample(hour: 15, scene: .afternoon, place: .park, activity: "Drawing animals", mood: .happy, reason: "Liked choosing colors", parentNote: "Focused for a long time"),
                DailySample(hour: 17, scene: .evening, place: .park, activity: "Playtime", mood: .tired, reason: "Long play session", parentNote: "Needed a calmer transition home"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Bedtime story", mood: .scared, reason: "Asked about shadows", parentNote: "Calmed down after a second story")
            ],
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Puzzle", mood: .excited, reason: "Finished a hard piece", parentNote: "Asked to repeat the puzzle"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .tired, reason: "Woke earlier than usual", parentNote: "Needed extra time before leaving"),
                DailySample(hour: 9, scene: .morning, place: .school, activity: "Drop-off", mood: .happy, reason: "Saw a friend at the gate", parentNote: "Walked in independently"),
                DailySample(hour: 10, scene: .morning, place: .school, activity: "Story circle", mood: .happy, reason: "Teacher picked a familiar story", parentNote: "Remembered details later"),
                DailySample(hour: 12, scene: .afternoon, place: .school, activity: "Lunch", mood: .sad, reason: "Preferred a different snack", parentNote: "Settled after water break"),
                DailySample(hour: 15, scene: .afternoon, place: .home, activity: "Quiet reading", mood: .tired, reason: "Skipped nap", parentNote: "Wanted to sit close"),
                DailySample(hour: 17, scene: .evening, place: .home, activity: "Clean-up", mood: .angry, reason: "Wanted more play time", parentNote: "Settled after choosing which toy first"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Bath time", mood: .happy, reason: "Played with bubbles", parentNote: "Relaxed before sleep")
            ],
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Getting dressed", mood: .sad, reason: "Wanted favorite shirt", parentNote: "Choice between socks helped"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .happy, reason: "Made toast together", parentNote: "Proud of helping"),
                DailySample(hour: 9, scene: .morning, place: .school, activity: "Drop-off", mood: .scared, reason: "New classroom helper", parentNote: "Needed reassurance about pickup"),
                DailySample(hour: 10, scene: .morning, place: .school, activity: "Music time", mood: .excited, reason: "Got to use the drum", parentNote: "Sang the song at home"),
                DailySample(hour: 12, scene: .afternoon, place: .school, activity: "Lunch", mood: .happy, reason: "Shared crackers", parentNote: "Reported feeling proud"),
                DailySample(hour: 15, scene: .afternoon, place: .other, activity: "Family visit", mood: .happy, reason: "Played with cousin", parentNote: "Warm and social"),
                DailySample(hour: 17, scene: .evening, place: .home, activity: "Screen-off transition", mood: .angry, reason: "Wanted another episode", parentNote: "Timer helped after a few minutes"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Bedtime story", mood: .tired, reason: "Busy afternoon", parentNote: "Fell asleep quickly")
            ],
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Wake-up cuddle", mood: .tired, reason: "Restless night", parentNote: "Stayed quiet during breakfast"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .sad, reason: "Spilled milk", parentNote: "Recovered after helping clean"),
                DailySample(hour: 9, scene: .morning, place: .school, activity: "Drop-off", mood: .happy, reason: "Teacher greeted with stickers", parentNote: "Quick goodbye"),
                DailySample(hour: 10, scene: .morning, place: .school, activity: "Story circle", mood: .excited, reason: "Acted out the story", parentNote: "Used big gestures"),
                DailySample(hour: 12, scene: .afternoon, place: .school, activity: "Lunch", mood: .tired, reason: "Noisy room", parentNote: "Asked for quiet corner"),
                DailySample(hour: 15, scene: .afternoon, place: .park, activity: "Sandbox play", mood: .happy, reason: "Built a tunnel", parentNote: "Cooperated with another child"),
                DailySample(hour: 17, scene: .evening, place: .home, activity: "Clean-up", mood: .happy, reason: "Made it a race", parentNote: "Finished faster with music"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Quiet reading", mood: .scared, reason: "Storm sounds outside", parentNote: "Wanted night light brighter")
            ],
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Puzzle", mood: .happy, reason: "Remembered yesterday's strategy", parentNote: "Stayed patient"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .excited, reason: "Weekend pancakes", parentNote: "Helped stir batter"),
                DailySample(hour: 9, scene: .morning, place: .park, activity: "Scooter ride", mood: .excited, reason: "Practiced turning", parentNote: "Asked to show progress"),
                DailySample(hour: 10, scene: .morning, place: .park, activity: "Playtime", mood: .happy, reason: "Met a kind child", parentNote: "Shared the slide"),
                DailySample(hour: 12, scene: .afternoon, place: .home, activity: "Lunch", mood: .tired, reason: "Lots of running", parentNote: "Needed quiet after eating"),
                DailySample(hour: 15, scene: .afternoon, place: .home, activity: "Drawing animals", mood: .happy, reason: "Drew a cat family", parentNote: "Talked about feelings through the drawing"),
                DailySample(hour: 17, scene: .evening, place: .other, activity: "Grocery trip", mood: .angry, reason: "Wanted candy", parentNote: "Calmed with helper job"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Bedtime story", mood: .happy, reason: "Chose the story", parentNote: "Asked for the same ending twice")
            ],
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Getting dressed", mood: .happy, reason: "Picked outfit independently", parentNote: "Proud smile"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .happy, reason: "Sang at the table", parentNote: "Ate without reminders"),
                DailySample(hour: 9, scene: .morning, place: .other, activity: "Car ride", mood: .scared, reason: "Loud motorcycle passed", parentNote: "Breathing game helped"),
                DailySample(hour: 10, scene: .morning, place: .other, activity: "Library story", mood: .excited, reason: "Puppet show", parentNote: "Asked questions afterward"),
                DailySample(hour: 12, scene: .afternoon, place: .other, activity: "Lunch", mood: .tired, reason: "Busy morning", parentNote: "Wanted to sit on parent's lap"),
                DailySample(hour: 15, scene: .afternoon, place: .home, activity: "Quiet reading", mood: .happy, reason: "Found a favorite page", parentNote: "Read independently for a while"),
                DailySample(hour: 17, scene: .evening, place: .home, activity: "Sibling sharing", mood: .angry, reason: "Wanted the same block", parentNote: "Turn-taking card helped"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Bath time", mood: .tired, reason: "Long day", parentNote: "Asked for pajamas early")
            ],
            [
                DailySample(hour: 7, scene: .morning, place: .home, activity: "Wake-up cuddle", mood: .happy, reason: "Weekend slow start", parentNote: "Wanted to tell a dream"),
                DailySample(hour: 8, scene: .morning, place: .home, activity: "Breakfast", mood: .excited, reason: "Family breakfast", parentNote: "Asked everyone questions"),
                DailySample(hour: 9, scene: .morning, place: .park, activity: "Nature walk", mood: .happy, reason: "Found leaves", parentNote: "Collected three favorites"),
                DailySample(hour: 10, scene: .morning, place: .park, activity: "Playtime", mood: .scared, reason: "Bigger child ran close", parentNote: "Returned to play after a break"),
                DailySample(hour: 12, scene: .afternoon, place: .home, activity: "Lunch", mood: .happy, reason: "Helped set table", parentNote: "Proud of the helper role"),
                DailySample(hour: 15, scene: .afternoon, place: .home, activity: "Pretend doctor", mood: .excited, reason: "Invented a story", parentNote: "Narrated feelings clearly"),
                DailySample(hour: 17, scene: .evening, place: .home, activity: "Clean-up", mood: .tired, reason: "Needed rest", parentNote: "Worked better with one-step prompts"),
                DailySample(hour: 20, scene: .night, place: .home, activity: "Bedtime story", mood: .happy, reason: "Picked a funny book", parentNote: "Ended the day relaxed")
            ]
        ]

        return dayStarts.enumerated().flatMap { dayIndex, dayStart in
            dayPlans[dayIndex % dayPlans.count].map { sample in
                makeEvent(from: sample, dayStart: dayStart)
            }
        }
    }

    private static func makeEvent(from sample: DailySample, dayStart: Date) -> StoryEvent {
        let date = Calendar.current.date(byAdding: .hour, value: sample.hour, to: dayStart) ?? dayStart

        return StoryEvent(
            childName: "Leo",
            childAge: 4,
            childGender: "M",
            scene: sample.scene,
            place: sample.place,
            activity: sample.activity,
            mood: sample.mood,
            reason: sample.reason,
            parentNote: sample.parentNote,
            date: date
        )
    }

    private static func seedKey(for event: StoryEvent) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: event.date)
        return [
            event.childName.lowercased(),
            "\(components.year ?? 0)",
            "\(components.month ?? 0)",
            "\(components.day ?? 0)",
            event.activity.lowercased()
        ].joined(separator: "-")
    }

    private static func removeDuplicateSampleActivities(
        from events: [StoryEvent],
        in modelContext: ModelContext
    ) -> (events: [StoryEvent], didDelete: Bool) {
        let grouped = Dictionary(grouping: events) { event in
            seedKey(for: event)
        }
        var retainedEvents: [StoryEvent] = []
        var didDelete = false

        for group in grouped.values {
            guard group.count > 1, group.allSatisfy({ $0.childName == "Leo" }) else {
                retainedEvents.append(contentsOf: group)
                continue
            }

            let sorted = group.sorted { $0.date > $1.date }
            if let newest = sorted.first {
                retainedEvents.append(newest)
            }

            for duplicate in sorted.dropFirst() {
                modelContext.delete(duplicate)
                didDelete = true
            }
        }

        return (retainedEvents, didDelete)
    }

    private struct DailySample {
        let hour: Int
        let scene: StoryScene
        let place: Place
        let activity: String
        let mood: Mood
        let reason: String
        let parentNote: String
    }
}

enum AnalyticsBuilder {
    static func moodBucketsByScene(from events: [StoryEvent]) -> [ChartBucket] {
        StoryScene.allCases.flatMap { scene in
            Mood.allCases.compactMap { mood in
                let count = events.filter { $0.scene == scene && $0.mood == mood }.count
                return count > 0 ? ChartBucket(category: scene.displayName, mood: mood, count: count) : nil
            }
        }
    }

    static func moodBucketsByPlace(from events: [StoryEvent]) -> [ChartBucket] {
        Place.allCases.flatMap { place in
            Mood.allCases.compactMap { mood in
                let count = events.filter { $0.place == place && $0.mood == mood }.count
                return count > 0 ? ChartBucket(category: place.displayName, mood: mood, count: count) : nil
            }
        }
    }

    static func dailyMoodPoints(from events: [StoryEvent]) -> [DailyMoodPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.date)
        }

        return grouped.map { day, events in
            let total = events.reduce(0.0) { $0 + $1.mood.numericScore }
            return DailyMoodPoint(
                date: day,
                averageScore: total / Double(events.count),
                eventCount: events.count
            )
        }
        .sorted { $0.date < $1.date }
    }

    static func dailyEventCounts(from events: [StoryEvent]) -> [DailyEventCountPoint] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.date)
        }

        return grouped.map { day, events in
            DailyEventCountPoint(date: day, count: events.count)
        }
        .sorted { $0.date < $1.date }
    }

    static func challengingMoodByScene(from events: [StoryEvent]) -> [SceneChallengePoint] {
        StoryScene.allCases.compactMap { scene in
            let matchingEvents = events.filter { $0.scene == scene }
            guard !matchingEvents.isEmpty else { return nil }

            return SceneChallengePoint(
                scene: scene.displayName,
                challengingCount: matchingEvents.filter { $0.mood.isChallenging }.count,
                totalCount: matchingEvents.count
            )
        }
    }

    static func topActivities(from events: [StoryEvent], limit: Int = 6) -> [ActivityCountPoint] {
        let grouped = Dictionary(grouping: events) { event in
            let activity = event.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            return activity.isEmpty ? "Unspecified" : activity
        }

        return grouped.map { activity, events in
            ActivityCountPoint(activity: activity, count: events.count)
        }
        .sorted {
            if $0.count == $1.count {
                return $0.activity < $1.activity
            }
            return $0.count > $1.count
        }
        .prefix(limit)
        .map { $0 }
    }

}

enum ModelDownloadHelper {
    static func downloadCompileAndLoadModel(from url: URL) async throws -> (savedURL: URL, model: MLModel) {
        let (temporaryURL, _) = try await URLSession.shared.download(from: url)
        let documents = try documentsDirectory()
        let downloadedURL = documents.appendingPathComponent(url.lastPathComponent)

        try? FileManager.default.removeItem(at: downloadedURL)
        try FileManager.default.copyItem(at: temporaryURL, to: downloadedURL)

        let loadURL: URL
        if downloadedURL.pathExtension.lowercased() == "mlmodel" {
            let compiledTemporaryURL = try await MLModel.compileModel(at: downloadedURL)
            let compiledURL = documents
                .appendingPathComponent(downloadedURL.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("mlmodelc")

            try? FileManager.default.removeItem(at: compiledURL)
            try FileManager.default.copyItem(at: compiledTemporaryURL, to: compiledURL)
            loadURL = compiledURL
        } else {
            loadURL = downloadedURL
        }

        let model = try MLModel(contentsOf: loadURL)
        return (loadURL, model)
    }

    static func featureProvider(scene: StoryScene, place: Place, activity: String) throws -> MLFeatureProvider {
        try MLDictionaryFeatureProvider(dictionary: [
            "scene": scene.rawValue as NSString,
            "place": place.rawValue as NSString,
            "activity": activity as NSString
        ])
    }

    private static func documentsDirectory() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return documents
    }
}

enum PrototypeAnalysisRunner {
    static func classifyMood(
        scene: StoryScene,
        place: Place,
        activity: String,
        engine: AnalysisEngine,
        model: MLModel? = nil
    ) -> MoodPrediction {
        if engine == .coreMLClassifier, let model {
            do {
                let input = try ModelDownloadHelper.featureProvider(scene: scene, place: place, activity: activity)
                let output = try model.prediction(from: input)
                if let moodString = output.featureValue(for: "mood")?.stringValue,
                   let mood = Mood(rawValue: moodString.lowercased()) {
                    return MoodPrediction(
                        mood: mood,
                        confidence: 0.72,
                        explanation: "Read a mood label from the loaded Core ML model output."
                    )
                }
            } catch {
                return MoodPrediction(
                    mood: fallbackMood(scene: scene, place: place, activity: activity),
                    confidence: 0.35,
                    explanation: "Core ML inference failed, so the prototype used simple fallback rules."
                )
            }
        }

        return MoodPrediction(
            mood: fallbackMood(scene: scene, place: place, activity: activity),
            confidence: engine == .simpleRules ? 0.64 : 0.45,
            explanation: "Prototype stub based on scene, place, and activity keywords."
        )
    }

    private static func fallbackMood(scene: StoryScene, place: Place, activity: String) -> Mood {
        let text = activity.lowercased()

        if text.contains("sleep") || text.contains("nap") || scene == .night {
            return .tired
        }

        if text.contains("drop") || text.contains("goodbye") {
            return .sad
        }

        if place == .park || text.contains("play") || text.contains("story") {
            return .happy
        }

        if scene == .morning {
            return .excited
        }

        return .happy
    }
}
