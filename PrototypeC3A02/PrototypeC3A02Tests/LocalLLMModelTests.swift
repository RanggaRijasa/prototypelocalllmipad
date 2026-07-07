//
//  LocalLLMModelTests.swift
//  PrototypeC3A02Tests
//
//  Created by Codex on 04/07/26.
//

import XCTest
@testable import PrototypeC3A02

final class LocalLLMModelTests: XCTestCase {
    func testRecommendedCatalogIncludesGemma4LiteRTLMModels() throws {
        let gemmaE2B = try XCTUnwrap(
            LocalModelCatalog.recommended.first { $0.id == "gemma-4-e2b-it-litertlm" }
        )
        let gemmaE4B = try XCTUnwrap(
            LocalModelCatalog.recommended.first { $0.id == "gemma-4-e4b-it-litertlm" }
        )

        XCTAssertEqual(gemmaE2B.runtime, .liteRTLM)
        XCTAssertEqual(gemmaE2B.modelID, "litert-community/gemma-4-E2B-it-litert-lm")
        XCTAssertEqual(gemmaE2B.files.first?.relativePath, "gemma-4-E2B-it.litertlm")
        XCTAssertEqual(gemmaE2B.sizeInBytes, 2_583_085_056)
        XCTAssertEqual(gemmaE2B.defaultConfiguration.maxTokens, 1_024)
        XCTAssertFalse(gemmaE2B.defaultConfiguration.enableThinking)
        XCTAssertFalse(gemmaE2B.defaultConfiguration.enableSpeculativeDecoding)

        XCTAssertEqual(gemmaE4B.runtime, .liteRTLM)
        XCTAssertEqual(gemmaE4B.modelID, "litert-community/gemma-4-E4B-it-litert-lm")
        XCTAssertEqual(gemmaE4B.files.first?.relativePath, "gemma-4-E4B-it.litertlm")
        XCTAssertEqual(gemmaE4B.sizeInBytes, 3_654_467_584)
        XCTAssertEqual(gemmaE4B.defaultConfiguration.maxTokens, 1_024)
        XCTAssertFalse(gemmaE4B.defaultConfiguration.enableSpeculativeDecoding)
    }

    func testDownloadProgressUsesByteFractionWhenAvailable() throws {
        let progress = LocalLLMDownloadProgress(
            modelID: "gemma-4-e2b-it-litertlm",
            fileName: "gemma-4-E2B-it.litertlm",
            completedFiles: 0,
            totalFiles: 1,
            completedBytes: 1_294_073_856,
            totalBytes: 2_583_085_056,
            isDownloading: true,
            message: "Downloading"
        )

        XCTAssertEqual(try XCTUnwrap(progress.fractionCompleted), 0.5, accuracy: 0.001)
    }

    @MainActor
    func testRepairsCompletedPartialDownloadIntoInstalledModel() throws {
        let id = "test-complete-partial-\(UUID().uuidString)"
        let model = LocalLLMModel(
            id: id,
            name: "Tiny LiteRT-LM",
            provider: "Test",
            modelID: "test/tiny",
            runtime: .liteRTLM,
            description: "A tiny test model.",
            version: "test",
            sizeInBytes: 4,
            estimatedPeakMemoryInBytes: 8,
            supportsImages: false,
            isRecommended: false,
            files: [
                LocalLLMFile(
                    relativePath: "tiny.litertlm",
                    urlString: "https://example.com/tiny.litertlm",
                    sizeInBytes: 4
                )
            ],
            defaultConfiguration: .default
        )
        let modelDirectory = LocalModelLibrary.modelStorageDirectory(for: model)
        let destination = modelDirectory.appendingPathComponent("tiny.litertlm")
        let partialURL = destination.appendingPathExtension("download")
        let defaults = UserDefaults.standard
        let keys = [
            LocalModelLibrary.installedModelsKey,
            LocalModelLibrary.customModelsKey,
            LocalModelLibrary.selectedModelIDKey,
            LocalModelLibrary.configurationKey
        ]

        keys.forEach(defaults.removeObject)
        try? FileManager.default.removeItem(at: modelDirectory)
        defer {
            keys.forEach(defaults.removeObject)
            try? FileManager.default.removeItem(at: modelDirectory)
        }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0, 1, 2, 3]).write(to: partialURL)

        let library = LocalModelLibrary()
        library.addCustomModel(model)
        XCTAssertFalse(library.isInstalled(model))

        library.repairCompletedDownloads()

        XCTAssertTrue(library.isInstalled(model))
        XCTAssertEqual(library.selectedInstalledModel?.id, id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialURL.path))
    }

    func testImportsHuggingFaceResolveURL() throws {
        let model = try LocalModelCatalog.customModel(
            name: "",
            urlsText: "https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm",
            runtime: .liteRTLM
        )

        XCTAssertEqual(model.modelID, "litert-community/gemma-4-E4B-it-litert-lm")
        XCTAssertEqual(model.name, "gemma-4-E4B-it-litert-lm")
        XCTAssertEqual(model.runtime, .liteRTLM)
        XCTAssertEqual(model.files.first?.relativePath, "gemma-4-E4B-it.litertlm")
    }

    func testImportsMultipleCheckpointURLs() throws {
        let urls = """
        https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/model.yaml
        https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/checkpoints/mp_rank_00_model-state.tuned
        """

        let model = try LocalModelCatalog.customModel(name: "Gemma 4 E4B", urlsText: urls, runtime: .liteRTLM)

        XCTAssertEqual(model.files.count, 2)
        XCTAssertEqual(model.files[0].relativePath, "model.yaml")
        XCTAssertEqual(model.files[1].relativePath, "checkpoints/mp_rank_00_model-state.tuned")
    }

    func testDefaultConfigurationIsCodable() throws {
        let data = try JSONEncoder().encode(LocalLLMConfiguration.default)
        let decoded = try JSONDecoder().decode(LocalLLMConfiguration.self, from: data)

        XCTAssertEqual(decoded, .default)
    }

    @MainActor
    func testAnalyticsPromptUsesDashboardJSONContract() throws {
        let event = SampleDataSeeder.makeTestEvent()
        let prompt = LocalModelLibrary.analyticsPrompt(for: [event], configuration: .default)

        XCTAssertTrue(prompt.contains("Return compact JSON only"))
        XCTAssertTrue(prompt.contains("commonTriggers"))
        XCTAssertTrue(prompt.contains("observedPatterns"))
        XCTAssertFalse(prompt.contains("notablePatterns"))
        XCTAssertTrue(prompt.contains("Analyze these rows for a dashboard"))
        XCTAssertFalse(prompt.contains("child-friendly sentence"))
    }

    @MainActor
    func testAnalyticsUserPromptLimitsRowsForNativeRuntime() throws {
        let events = (0..<30).map { index in
            SampleDataSeeder.makeTestEvent(date: Date(timeIntervalSince1970: Double(index) * 3_600))
        }
        let prompt = LocalModelLibrary.analyticsUserPrompt(
            for: events,
            configuration: .default,
            eventLimit: 5
        )
        let eventRows = prompt
            .split(separator: "\n")
            .filter { $0.hasPrefix("- ") }

        XCTAssertEqual(eventRows.count, 5)
        XCTAssertFalse(prompt.contains("System:"))
        XCTAssertTrue(prompt.contains("Keep the response compact"))
        XCTAssertTrue(prompt.contains("curated catalog"))
    }

    func testParsesGeneratedAnalyticsJSON() throws {
        let output = """
        ```json
        {
          "summary": "Mornings are mostly happy, while evenings show more tired transitions.",
          "commonTriggers": [
            {
              "title": "Clean-up",
              "explanation": "Clean-up appears with angry or tired moods during evening transitions."
            }
          ],
          "observedPatterns": [
            {
              "title": "Evening Clean-up",
              "evidence": "Clean-up appears with angry or tired moods in evening home events.",
              "linkedTrigger": "Clean-up",
              "contextTags": ["Evening", "Home", "Angry"]
            }
          ],
          "parentReflectionPrompt": "Which evening transition could be made calmer tomorrow?",
          "ethicalNote": "Use this as reflection, not diagnosis."
        }
        ```
        """

        let insight = LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: "Gemma-4-E2B-it")

        XCTAssertEqual(insight.modelName, "Gemma-4-E2B-it")
        XCTAssertEqual(insight.commonTriggers.first?.title, "Clean-up")
        XCTAssertEqual(
            insight.commonTriggers.first?.explanation,
            "Clean-up appears with angry or tired moods during evening transitions."
        )
        XCTAssertEqual(insight.observedPatterns.first?.title, "Evening Clean-up")
        XCTAssertEqual(insight.observedPatterns.first?.linkedTrigger, "Clean-up")
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "emotion-coaching" })
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "calm-limits-choices" })
        XCTAssertEqual(insight.ethicalNote, "Use this as reflection, not diagnosis.")
    }

    func testParsesFoundationModelsObservedPatterns() throws {
        let output = """
        ```json
        {
          "summary": "Leo's weekly mood patterns reveal a strong connection between nighttime activities and his emotional state.",
          "commonTriggers": [
            {
              "title": "Nighttime Activities",
              "explanation": "Leo experiences heightened anxiety or excitement during bedtime stories."
            }
          ],
          "observedPatterns": [
            {
              "title": "Excited Story Circle",
              "evidence": "Leo is animated during school story circles.",
              "linkedTrigger": "Nighttime Activities",
              "contextTags": ["School", "Excited"]
            },
            {
              "title": "Sad Drop-offs",
              "evidence": "Mood shifts from happy to sad during school drop-offs.",
              "linkedTrigger": "Nighttime Activities",
              "contextTags": ["School", "Sad"]
            }
          ],
          "parentReflectionPrompt": "How can you support transitions?",
          "ethicalNote": "Use this as reflection, not diagnosis."
        }
        ```
        """

        let insight = LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: "Apple Foundation Models")

        XCTAssertEqual(insight.summary, "Leo's weekly mood patterns reveal a strong connection between nighttime activities and his emotional state.")
        XCTAssertEqual(insight.commonTriggers.first?.title, "Nighttime Activities")
        XCTAssertEqual(insight.observedPatterns.count, 2)
        XCTAssertEqual(insight.observedPatterns.first?.displayText, "Excited Story Circle: Leo is animated during school story circles.")
        XCTAssertTrue(insight.parentRecommendations.contains { $0.sourceLabels.contains("CDC") })
    }

    func testParsesTruncatedAnalyticsJSONWithoutRawSummary() throws {
        let output = """
        ```json
        {
          "summary": "Nighttime and transitions are the clearest stress points this week.",
          "commonTriggers": [
            {
              "title": "Nighttime",
              "explanation": "Bedtime stories appear near scared moods."
            }
          ],
          "observedPatterns": [
            {
              "title": "Bedtime shadows",
              "evidence": "Scared mood appeared during a bedtime story after asking about shadows.",
              "linkedTrigger": "Nighttime",
              "contextTags": ["Night", "Scared"]
            }
        ```
        """

        let insight = LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: "Gemma-4-E2B-it")

        XCTAssertEqual(insight.summary, "Nighttime and transitions are the clearest stress points this week.")
        XCTAssertFalse(insight.summary.contains("\"summary\""))
        XCTAssertEqual(insight.commonTriggers.first?.title, "Nighttime")
        XCTAssertEqual(insight.observedPatterns.first?.title, "Bedtime shadows")
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "predictable-routines" })
    }

    func testMalformedAnalyticsFallbackDoesNotUseRawJSONAsRecommendationEvidence() throws {
        let output = """
        {
          "summary": "Drop-off transitions seem harder after long mornings.",
          "commonTriggers": [
        """

        let insight = LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: "Gemma-4-E2B-it")

        XCTAssertEqual(insight.summary, "Drop-off transitions seem harder after long mornings.")
        XCTAssertFalse(insight.summary.contains("\"commonTriggers\""))
        XCTAssertFalse(
            insight.parentRecommendations.contains {
                $0.basedOnEvidence.contains("\"summary\"") || $0.basedOnEvidence.contains("\"commonTriggers\"")
            }
        )
    }

    func testParsesLegacyNotablePatternsIntoObservedPatterns() throws {
        let output = """
        {
          "summary": "Transitions are harder when the day is long.",
          "commonTriggers": [
            {
              "title": "Transition",
              "explanation": "Screen-off and clean-up transitions appear with angry moods."
            }
          ],
          "notablePatterns": ["Screen-off transition appears with angry moods after afternoon activities."],
          "parentReflectionPrompt": "Which transition could be previewed tomorrow?",
          "ethicalNote": "Reflective only."
        }
        """

        let insight = LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: "Gemma-4-E2B-it")

        XCTAssertEqual(insight.observedPatterns.first?.title, "Evidence from Logs")
        XCTAssertEqual(
            insight.observedPatterns.first?.evidence,
            "Screen-off transition appears with angry moods after afternoon activities."
        )
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "predictable-routines" })
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "calm-limits-choices" })
    }

    func testParentRecommendationsFallbackWhenPatternsAreWeak() throws {
        let insight = GeneratedLLMAnalyticsInsight(
            modelName: "Apple Foundation Models",
            summary: "There is a broad weekly pattern but the generated details are sparse.",
            commonTriggers: [
                GeneratedLLMCommonTrigger(
                    title: "Nighttime",
                    explanation: "Nighttime appears near scared moods."
                )
            ],
            observedPatterns: [],
            parentReflectionPrompt: "What helps bedtime feel predictable?",
            ethicalNote: "Reflective only."
        )

        XCTAssertEqual(insight.parentRecommendations.count, 3)
        XCTAssertEqual(insight.parentRecommendations.first?.id, "predictable-routines")
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "emotion-coaching" })
        XCTAssertTrue(insight.parentRecommendations.contains { $0.id == "serve-return-connection" })
    }

    func testRepairsSavedRawJSONFallbackInsight() throws {
        let rawOutput = """
        ```json
        {
          "summary": "Transitions are the clearest pattern.",
          "commonTriggers": [
            {
              "title": "Clean-up",
              "explanation": "Clean-up follows long play sessions."
            }
          ],
          "observedPatterns": [
            {
              "title": "Evening Fatigue",
              "evidence": "Tired moods appear more in the evening.",
              "linkedTrigger": "Clean-up",
              "contextTags": ["Evening", "Tired"]
            }
          ],
          "parentReflectionPrompt": "Which transition could be softened?",
          "ethicalNote": "Reflective only."
        }
        ```
        """
        let brokenInsight = GeneratedLLMAnalyticsInsight(
            modelName: "Apple Foundation Models",
            summary: rawOutput,
            commonTriggers: [],
            observedPatterns: [],
            parentReflectionPrompt: "What pattern feels most useful to watch over the next few days?",
            ethicalNote: "Model output is reflective and non-diagnostic."
        )

        let repaired = LocalLLMAnalyticsParser.repairFallbackInsight(brokenInsight)

        XCTAssertEqual(repaired.id, brokenInsight.id)
        XCTAssertEqual(repaired.generatedAt, brokenInsight.generatedAt)
        XCTAssertEqual(repaired.summary, "Transitions are the clearest pattern.")
        XCTAssertEqual(repaired.commonTriggers.first?.title, "Clean-up")
        XCTAssertEqual(repaired.observedPatterns.first?.displayText, "Evening Fatigue: Tired moods appear more in the evening.")
        XCTAssertTrue(repaired.parentRecommendations.contains { $0.id == "predictable-routines" })
    }
}
