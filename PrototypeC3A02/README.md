# PrototypeC3A02

PrototypeC3A02 is an iOS proof of concept for a guided storytelling analytics app. It lets a parent log a child's daily story events, review local SwiftData records, inspect mood and context patterns with Charts, and choose a prototype analysis engine.

## What Is Included

- SwiftData persistence for `StoryEvent` records.
- A seeded week of dummy story events for Leo.
- A Data tab for browsing, adding, viewing, and deleting events.
- A Dashboard tab with mood-by-scene, mood-by-place, and mood-over-time charts.
- A simple reflective insight summary that is not diagnostic.
- A Models tab with persistent engine selection, Core ML download/load support, and a local LiteRT-LM analytics flow.
- A Local LLM model manager with curated Gemma 4 `.litertlm` downloads, Hugging Face import, system prompt/configuration controls, and explicit load/offload controls.
- A generated Local LLM insight card on the Dashboard for model-produced chart focus, visualization suggestions, and grounded pattern summaries.
- Basic SwiftData persistence tests.

## Run The App

1. Open `PrototypeC3A02.xcodeproj` in Xcode.
2. Select the `PrototypeC3A02` scheme.
3. Run on an iPhone simulator or iPhone device using iOS 17 or later.

The project currently targets the iOS version configured by Xcode in the project settings. SwiftData and Charts require iOS 17 or later.

## Local LLM Flow

1. Open the Models tab.
2. Download a curated Gemma 4 LiteRT-LM model, or import a Hugging Face `.litertlm` link.
3. Tap `Load Model` to allocate the model in RAM.
4. Tap `Generate Dashboard Insight` to analyze the local SwiftData story events.
5. Tap `Offload From Memory` when finished, or background/close the app to release the loaded runtime.

## Limitations

- The data model and insights are intentionally small and local to the device.
- The Core ML classifier path is wired, but no `.mlmodel` is bundled.
- LiteRT-LM is vendored locally from Google's iOS `CLiteRTLM.xcframework` and Swift wrapper sources because the official Swift package product currently uses unsafe linker flags that Xcode rejects for this target. Actual generation requires a compatible downloaded `.litertlm` model and enough device RAM for that model.
- Insights are reflective prompts only and should not be treated as psychological or medical diagnosis.

## Parent Resources

- CDC developmental milestones: https://www.cdc.gov/act-early/milestones/index.html
- HealthyChildren Ages & Stages: https://www.healthychildren.org/English/ages-stages/Pages/default.aspx
