# App Architecture

This document defines the intended production folder structure.

Primary user journey:

```text
First launch
-> Create child profile: name, age, gender
-> Start / continue guided storytelling
-> Choose scene, location, activity, mood
-> Optional after-activity notes
-> Add activity or move scene
-> Nighttime move-on requires end-of-day reflection
-> Dashboard shows analytics and generated insight
```

For the local model flow, the production user should only be able to:

1. Download `Gemma-4-E2B-it`.
2. Generate insight from the Dashboard.

All load/offload, prompt construction, parsing, memory cleanup, repair, and diagnostics are internal implementation details. They must not be exposed as production user controls.

## Recommended File Structure

Use this structure unless there is a strong reason to change it.

When Codex or another LLM agent is scaffolding this architecture, create the folders first and do not create empty placeholder files just because they are listed below. Create a file only when implementing its actual feature. Exception: the Local Model / LiteRT-LM implementation is critical, so those implementation files may be created together when wiring Gemma-4-E2B-it.

```text
AppName/
|
|-- App/
|   |-- AppNameApp.swift
|   |-- AppRouter.swift
|   |-- AppConstants.swift
|   `-- AppEnvironment.swift
|
|-- Models/
|   |-- ChildProfile.swift
|   |-- StorySession.swift
|   |-- StoryEvent.swift
|   |-- EndOfDayReflection.swift
|   |-- UserLocation.swift
|   |-- UserActivity.swift
|   |-- UserImageAsset.swift
|   |-- AudioNote.swift
|   |-- MusicTrack.swift
|   |-- DailySessionReport.swift
|   |-- AnalyticsInsight.swift
|   |-- AnalysisEngine.swift
|   |-- Gender.swift
|   |-- Mood.swift
|   |-- SceneType.swift
|   |-- PlaceType.swift
|   |-- ActivityType.swift
|   |-- UserImagePurpose.swift
|   |
|   |-- LocalModel/
|   |   |-- Gemma4E2BModel.swift
|   |   |-- LocalModelInstallation.swift
|   |   |-- LocalModelDownloadProgress.swift
|   |   |-- LocalModelRuntimeState.swift
|   |   `-- LocalLLMConfiguration.swift
|   |
|   `-- Recommendations/
|       |-- ParentRecommendation.swift
|       `-- RecommendationSource.swift
|
|-- Data/
|   |-- SwiftData/
|   |   |-- SwiftDataContainer.swift
|   |   `-- SwiftDataSchema.swift
|   |
|   `-- Repositories/
|       |-- StoryEventRepository.swift
|       |-- ChildProfileRepository.swift
|       |-- StorySessionRepository.swift
|       |-- EndOfDayReflectionRepository.swift
|       |-- UserLocationRepository.swift
|       |-- UserActivityRepository.swift
|       |-- UserImageAssetRepository.swift
|       |-- AnalyticsInsightRepository.swift
|       `-- LocalModelRepository.swift
|
|-- Features/
|   |-- StorySection/
|   |   |-- Views/
|   |   |   |-- ChildProfileSetupView.swift
|   |   |   |-- GuidedStoryHomeView.swift
|   |   |   |-- SceneSelectionView.swift
|   |   |   |-- LocationSelectionView.swift
|   |   |   |-- CustomLocationEditorView.swift
|   |   |   |-- ActivitySelectionView.swift
|   |   |   |-- CustomActivityEditorView.swift
|   |   |   |-- MoodSelectionView.swift
|   |   |   |-- AfterActivityNotesView.swift
|   |   |   |-- AddActivityOrMoveSessionView.swift
|   |   |   |-- EndOfDayReflectionView.swift
|   |   |   |-- DataExplorerView.swift
|   |   |   |-- StoryEventListView.swift
|   |   |   `-- StoryEventDetailView.swift
|   |   |
|   |   `-- ViewModels/
|   |       |-- GuidedStoryViewModel.swift
|   |       |-- ChildProfileSetupViewModel.swift
|   |       |-- CustomLocationEditorViewModel.swift
|   |       |-- CustomActivityEditorViewModel.swift
|   |       |-- EndOfDayReflectionViewModel.swift
|   |       `-- DataExplorerViewModel.swift
|   |
|   |-- Dashboard/
|   |   |-- Views/
|   |   |   |-- DashboardView.swift
|   |   |   |-- InsightSummaryCard.swift
|   |   |   |-- MoodBySceneChart.swift
|   |   |   |-- MoodByPlaceChart.swift
|   |   |   |-- ActivityMoodChart.swift
|   |   |   |-- BehaviorPatternCard.swift
|   |   |   |-- WeeklyTrendChart.swift
|   |   |   |-- GenerateInsightSheet.swift
|   |   |   `-- DownloadModelRequiredAlert.swift
|   |   |
|   |   `-- ViewModels/
|   |       `-- DashboardViewModel.swift
|   |
|   `-- Model/
|       |-- Views/
|       |   |-- Gemma4E2BDownloadView.swift
|       |   `-- ModelDownloadProgressView.swift
|       |
|       `-- ViewModels/
|           `-- ModelDownloadViewModel.swift
|
|-- Services/
|   |-- Analytics/
|   |   |-- AnalyticsService.swift
|   |   |-- RuleBasedAnalyticsService.swift
|   |   |-- BehaviorPatternDetector.swift
|   |   |-- InsightSummaryGenerator.swift
|   |   |-- MoodScoringService.swift
|   |   `-- ParentRecommendationService.swift
|   |
|   |-- StoryFlow/
|   |   |-- GuidedStoryFlowService.swift
|   |   |-- StorySessionService.swift
|   |   |-- EndOfDayReflectionService.swift
|   |   |-- LocationCatalogService.swift
|   |   |-- ActivityCatalogService.swift
|   |   `-- StoryEventBuilder.swift
|   |
|   |-- Media/
|   |   |-- UserImageImportService.swift
|   |   |-- UserImageStorage.swift
|   |   |-- ImageThumbnailService.swift
|   |   `-- PhotoLibraryPermissionService.swift
|   |
|   |-- Audio/
|   |   |-- AudioSessionService.swift
|   |   |-- AudioRecordingService.swift
|   |   |-- AudioNoteService.swift
|   |   |-- SpeechRecognitionService.swift
|   |   |-- MusicPlaybackService.swift
|   |   |-- AmbientMusicService.swift
|   |   |-- SoundEffectService.swift
|   |   `-- AudioPermissionService.swift
|   |
|   |-- LocalLLM/
|   |   |-- Catalog/
|   |   |   |-- Gemma4E2BManifest.swift
|   |   |   |-- Gemma4E2BCompatibility.swift
|   |   |   `-- Gemma4E2BLicenseInfo.swift
|   |   |
|   |   |-- Download/
|   |   |   |-- LocalModelDownloadService.swift
|   |   |   |-- LocalModelDownloadRequest.swift
|   |   |   |-- LocalModelDownloadState.swift
|   |   |   |-- LocalModelDownloadProgressTracker.swift
|   |   |   |-- LocalModelResumeDataStore.swift
|   |   |   `-- LocalModelDownloadError.swift
|   |   |
|   |   |-- Storage/
|   |   |   |-- LocalModelStorage.swift
|   |   |   |-- LocalModelFileValidator.swift
|   |   |   |-- LocalModelChecksumValidator.swift
|   |   |   |-- LocalModelMetadataStore.swift
|   |   |   `-- LocalModelRepairService.swift
|   |   |
|   |   |-- Runtime/
|   |   |   |-- LocalLLMRuntimeSession.swift
|   |   |   |-- LiteRTLMAnalyticsRuntime.swift
|   |   |   |-- LiteRTLMEngineFactory.swift
|   |   |   |-- LiteRTLMConversationFactory.swift
|   |   |   |-- LocalLLMMemoryManager.swift
|   |   |   `-- LocalLLMRuntimeError.swift
|   |   |
|   |   |-- Prompting/
|   |   |   |-- AnalyticsSystemPrompt.swift
|   |   |   |-- AnalyticsContextBuilder.swift
|   |   |   |-- AnalyticsPromptBuilder.swift
|   |   |   `-- AnalyticsPromptBudget.swift
|   |   |
|   |   |-- Parsing/
|   |   |   |-- AnalyticsInsightParser.swift
|   |   |   |-- AnalyticsInsightRepairer.swift
|   |   |   |-- AnalyticsInsightSchema.swift
|   |   |   `-- AnalyticsInsightParseError.swift
|   |   |
|   |   |-- Recommendations/
|   |   |   |-- ParentRecommendationCatalog.swift
|   |   |   |-- ParentRecommendationMatcher.swift
|   |   |   `-- ParentRecommendationSourceCatalog.swift
|   |   |
|   |   |-- Vendor/
|   |   |   |-- Frameworks/
|   |   |   |   `-- CLiteRTLM.xcframework
|   |   |   |
|   |   |   `-- Swift/
|   |   |       |-- Engine.swift
|   |   |       |-- Conversation.swift
|   |   |       |-- Config.swift
|   |   |       |-- Message.swift
|   |   |       |-- ExperimentalFlags.swift
|   |   |       |-- LiteRTLMError.swift
|   |   |       `-- Capabilities.swift
|   |   |
|   |   `-- LocalLLMService.swift
|   |
|   `-- Speech/
|       `-- SpeechTranscriptionService.swift
|
|-- Shared/
|   |-- Components/
|   |   |-- AppCard.swift
|   |   |-- EmptyStateView.swift
|   |   |-- LoadingView.swift
|   |   |-- PrimaryButton.swift
|   |   `-- SectionHeaderView.swift
|   |
|   |-- Extensions/
|   |   |-- Date+Extensions.swift
|   |   |-- Array+Grouping.swift
|   |   `-- Color+Theme.swift
|   |
|   |-- Theme/
|   |   |-- AppTheme.swift
|   |   |-- AppColors.swift
|   |   `-- AppTypography.swift
|   |
|   `-- Utilities/
|       |-- FileManagerHelper.swift
|       |-- DownloadProgressTracker.swift
|       `-- Logger.swift
|
|-- Resources/
|   |-- Assets.xcassets
|   |-- Preview Content/
|   |-- Audio/
|   |   |-- AmbientMusic/
|   |   `-- SoundEffects/
|   `-- LocalModels/
|       |-- Gemma4E2BManifest.json
|       `-- Gemma4E2BLicense.md
|
`-- Tests/
    |-- GuidedStoryFlowTests.swift
    |-- EndOfDayReflectionTests.swift
    |-- UserLocationActivityTests.swift
    |-- UserImageStorageTests.swift
    |-- AudioServiceTests.swift
    |-- LocalModelDownloadTests.swift
    |-- LocalModelStorageTests.swift
    |-- LocalLLMRuntimeTests.swift
    |-- AnalyticsInsightParserTests.swift
    |-- ParentRecommendationMatcherTests.swift
    `-- DashboardGenerateInsightTests.swift
```

## Local Model User Flow

Production user-facing flow:

```text
Model tab
-> Download Gemma-4-E2B-it

Dashboard
-> Generate Insight
```

If `Generate Insight` is tapped before the model is installed, show `DownloadModelRequiredAlert` and stop generation.

Do not expose these as production user controls:

- manual load
- manual offload
- delete/redownload
- runtime diagnostics
- prompt editing
- sampling configuration

These behaviors can exist internally in services, tests, or debug-only builds.

## Guided Storytelling User Flow

The Story tab is the main daily input flow.

First-run behavior:

```text
Open Story tab
-> If no child profile exists, show ChildProfileSetupView
-> Parent enters child name, age, and gender
-> Save ChildProfile
-> Start today's guided story
```

Daily guided storytelling:

```text
Start / Continue Today's Story
-> Choose scene: morning, afternoon, evening, night
-> Choose location
-> Optionally create custom location with uploaded image
-> Choose activity
-> Optionally create custom activity with uploaded image
-> Choose mood
-> Add optional after-activity notes
-> Save StoryEvent
-> Add another activity OR move to another scene
-> If moving on from nighttime, require EndOfDayReflection
```

Rules:

- Child profile is required before story logging.
- Required profile fields: name, age, gender.
- A day can contain multiple scenes.
- A scene can contain multiple activities.
- Each logged activity creates a structured `StoryEvent`.
- After-activity notes are optional.
- End-of-day reflection is required when the parent taps `Move On` from the nighttime scene.
- The app must not complete the nighttime flow without end-of-day reflection.

## Custom Location and Activity Architecture

The app must support built-in and user-created locations and activities.

Custom location:

- Parent can create a location name.
- Parent can upload or choose an image for the location.
- Store the image file in app file storage.
- Store only metadata/path/thumbnail reference in SwiftData.

Custom activity:

- Parent can create an activity name.
- Parent can upload or choose an image for the activity.
- Store the image file in app file storage.
- Store only metadata/path/thumbnail reference in SwiftData.

Historical event rule:

- `StoryEvent` should preserve enough display snapshot data so old logs remain understandable even if a custom location/activity is later edited.
- Do not rely only on mutable catalog names for historical analytics labels.

Image storage responsibilities:

- Copy selected images into app-controlled storage.
- Generate thumbnails for list/grid UI.
- Avoid storing large image blobs in SwiftData.
- Keep images local to the device.

## Audio and Music Architecture

Audio and music are optional experience layers, not requirements for analytics to work.

Audio notes:

- After-activity notes may support text and audio.
- End-of-day reflection may support text and audio.
- Text input must remain available.
- Store raw audio files in app file storage.
- Store only metadata/path/duration/transcript in SwiftData.
- If transcription is added, prefer on-device transcription.

Music:

- Ambient music can support the guided storytelling mood.
- Use bundled or locally stored tracks.
- Do not require streaming.
- Respect mute, interruptions, and system audio session behavior.
- Music must be optional and easy to mute.
- Music must never block story logging.

## Internal Runtime Flow

```text
Generate Insight tapped
|
|-- Check LocalModelRepository for Gemma-4-E2B-it installation
|   |
|   |-- Missing
|   |   `-- Show DownloadModelRequiredAlert
|   |
|   `-- Installed
|       |
|       |-- Select data scope: all, weekly, or date
|       |-- Build analytics prompt internally
|       |-- Load Gemma-4-E2B-it through LiteRT-LM internally
|       |-- Generate compact JSON insight
|       |-- Parse and repair JSON if needed
|       |-- Match parent recommendations from curated catalog
|       |-- Save AnalyticsInsight
|       `-- Offload model from memory internally
```

## Download Required Alert

```text
Title:
Download Gemma-4-E2B-it First

Message:
On-device insight generation needs the Gemma-4-E2B-it model before it can run. The download is about 2.58 GB and stays on this iPhone or iPad.

Primary button:
Download Model

Secondary button:
Cancel
```

## LiteRT-LM Dependency Rule

Use vendored LiteRT-LM runtime pieces:

```text
Services/LocalLLM/Vendor/
|-- Frameworks/
|   `-- CLiteRTLM.xcframework
|
`-- Swift/
    |-- Engine.swift
    |-- Conversation.swift
    |-- Config.swift
    |-- Message.swift
    `-- ExperimentalFlags.swift
```

Do not attach SwiftPM product `LiteRTLM` directly to the app target. Xcode can reject it with:

```text
The package product 'LiteRTLM' cannot be used as a dependency of this target because it uses unsafe build flags.
```
