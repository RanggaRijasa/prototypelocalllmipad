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
        XCTAssertTrue(prompt.contains("dashboardFocus"))
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
    }

    func testParsesGeneratedAnalyticsJSON() throws {
        let output = """
        ```json
        {
          "summary": "Mornings are mostly happy, while evenings show more tired transitions.",
          "dashboardFocus": "Compare evening mood by activity.",
          "chartSuggestions": ["Evening mood stacked bars", "Daily average mood line"],
          "notablePatterns": ["Clean-up appears with angry or tired moods."],
          "parentReflectionPrompt": "Which evening transition could be made calmer tomorrow?",
          "ethicalNote": "Use this as reflection, not diagnosis."
        }
        ```
        """

        let insight = LocalLLMAnalyticsParser.parse(modelOutput: output, modelName: "Gemma-4-E2B-it")

        XCTAssertEqual(insight.modelName, "Gemma-4-E2B-it")
        XCTAssertEqual(insight.dashboardFocus, "Compare evening mood by activity.")
        XCTAssertEqual(insight.chartSuggestions.count, 2)
        XCTAssertEqual(insight.ethicalNote, "Use this as reflection, not diagnosis.")
    }
}
