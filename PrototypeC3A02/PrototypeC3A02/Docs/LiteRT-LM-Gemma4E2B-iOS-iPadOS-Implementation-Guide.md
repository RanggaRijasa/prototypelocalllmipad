# LiteRT-LM + Gemma-4-E2B-it iOS/iPadOS Implementation Guide

Dokumen ini merangkum implementasi LiteRT-LM dan model `Gemma-4-E2B-it` di prototype `PrototypeC3A02`, lalu mengubahnya menjadi panduan teknis untuk aplikasi produksi. Panduan ini sengaja hanya mencakup satu model production path: `Gemma-4-E2B-it` dalam format LiteRT-LM `.litertlm`. Model lain, engine lain, dan eksperimen backend lain tidak masuk scope dokumen ini.

## 1. Tujuan Implementasi

Target fitur:

- App dapat memakai LLM lokal di iPhone dan iPad.
- Satu-satunya model yang didukung dalam panduan ini adalah `Gemma-4-E2B-it` dalam format LiteRT-LM `.litertlm`.
- Model tidak digunakan sebagai chatbot, tetapi sebagai engine analytics untuk membaca data log anak dan menghasilkan insight dashboard.
- Data keluarga tetap di device.
- Model hanya di-load secara internal saat dibutuhkan, lalu di-offload otomatis dari RAM setelah selesai atau saat app masuk background.
- Insight yang tampil ke user harus terstruktur, aman, non-diagnostik, dan bisa dipakai untuk visualisasi dashboard.

## 2. Status Implementasi Prototype

Yang sudah diimplementasikan di prototype:

- LiteRT-LM sudah terhubung melalui vendored `CLiteRTLM.xcframework`.
- App mendukung iPhone dan iPad target family.
- Model catalog production difokuskan hanya pada `Gemma-4-E2B-it`.
- Download model memakai resumable downloader, progress state, partial file repair, dan penyimpanan di Documents.
- User diarahkan memakai Local LLM via LiteRT-LM saja untuk generate analytics insight.
- User-facing local model flow hanya: download model, lalu generate insight dari Dashboard.
- Generate insight sudah dipindahkan ke dashboard.
- Generate insight mendukung scope data:
  - semua data
  - data mingguan
  - tanggal tertentu
- Prompt, context, sampling config, load/offload, dan diagnostics adalah internal/dev-only, bukan production user controls.
- Output LiteRT-LM diparse menjadi schema analytics yang stabil.
- Parent Recommendations dibuat dari curated recommendation catalog, bukan klaim bebas dari LLM.
- Runtime LiteRT-LM otomatis offload setelah generation, saat background, dan saat memory warning.

## 3. Arsitektur Tingkat Tinggi

Alur produksi yang direkomendasikan:

```text
User logs story events
        |
        v
Dashboard selects data scope
        |
        v
Build analytics prompt + context
        |
        v
Load Gemma-4-E2B-it via LiteRT-LM
        |
        v
Generate compact JSON insight
        |
        v
Parse and repair JSON if needed
        |
        v
Attach curated parent recommendations
        |
        v
Save generated insight
        |
        v
Offload model from memory
```

Key principle: LLM hanya menghasilkan analytics observation. Teks strategi parenting berbasis riset datang dari in-app curated catalog.

## 4. Dependency dan Xcode Configuration

### 4.1 Dependency Strategy

Prototype tidak lagi mengandalkan Swift Package LiteRT-LM langsung karena package sebelumnya memunculkan issue unsafe build flags. Solusi yang dipakai:

- Vendor LiteRT-LM sebagai binary framework.
- Link framework ke app target.
- Embed dan code sign framework di app bundle.
- Bungkus API native dalam Swift wrapper internal.

Important dependency decision:

- Jangan add package product `LiteRTLM` langsung ke app target lewat Swift Package Manager.
- Dependency URL dari Google bisa official, tetapi Xcode dapat tetap menolak product `LiteRTLM` karena package tersebut memakai unsafe linker/build flags.
- Error yang harus dihindari:

```text
The package product 'LiteRTLM' cannot be used as a dependency of this target because it uses unsafe build flags.
```

Fix yang dipakai di prototype dan harus diikuti di production:

- Hapus Swift Package dependency `LiteRTLM` dari target app.
- Hapus stale package resolution jika Xcode masih mencoba fetch package lama, misalnya `Package.resolved`.
- Vendor official LiteRT-LM binary framework secara lokal sebagai `CLiteRTLM.xcframework`.
- Copy Swift wrapper sources LiteRT-LM ke folder lokal app.
- Import native framework dengan `import CLiteRTLM`, bukan `import LiteRTLM`.
- Pastikan `CLiteRTLM.xcframework` masuk ke Link Binary With Libraries dan Embed Frameworks.

Dengan pola ini, build tidak bergantung pada SwiftPM product yang ditolak Xcode, tetapi tetap memakai official LiteRT-LM runtime pieces secara lokal.

File penting:

```text
PrototypeC3A02/LiteRTLMVendor/Frameworks/CLiteRTLM.xcframework
PrototypeC3A02/LiteRTLMVendor/Swift/Engine.swift
PrototypeC3A02/LiteRTLMVendor/Swift/Conversation.swift
PrototypeC3A02/LiteRTLMVendor/Swift/Config.swift
PrototypeC3A02/LiteRTLMVendor/Swift/Message.swift
PrototypeC3A02/LiteRTLMVendor/Swift/ExperimentalFlags.swift
PrototypeC3A02/LiteRTLMAnalyticsRuntime.swift
```

Untuk production app, dependency strategy yang disarankan:

- Gunakan official atau audited LiteRT-LM XCFramework.
- Pastikan ada slice:
  - `ios-arm64` untuk physical iPhone/iPad.
  - `ios-arm64-simulator` untuk Apple Silicon simulator.
- Jangan memakai SPM package yang memaksa unsafe build flags kecuali sudah diaudit dan diterima oleh build policy.
- Simpan versi binary framework secara eksplisit agar build reproducible.
- Setelah dependency diganti ke vendored framework, jalankan clean build agar Xcode tidak memakai package cache lama.

### 4.2 Xcode Target Settings

Checklist target:

- Tambahkan `CLiteRTLM.xcframework` ke `Frameworks, Libraries, and Embedded Content`.
- Set ke `Embed & Sign`.
- Pastikan framework masuk ke build phase:
  - Link Binary With Libraries.
  - Embed Frameworks.
- Tambahkan Swift wrapper files ke target app.
- Deployment target harus sesuai runtime LiteRT-LM yang dipakai.
- Target devices harus `iPhone` dan `iPad`.

Guard di Swift:

```swift
#if canImport(CLiteRTLM)
import CLiteRTLM
#endif
```

Jika framework tidak ter-link, runtime harus memberi error yang jelas:

```text
CLiteRTLM is not linked. Rebuild after adding the LiteRT-LM framework to the app target.
```

## 5. Model Catalog

Satu-satunya model production dalam panduan ini:

```text
Name: Gemma-4-E2B-it
Runtime: LiteRT-LM
Hugging Face repo: litert-community/gemma-4-E2B-it-litert-lm
File: gemma-4-E2B-it.litertlm
Size: ~2.58 GB
Estimated peak memory: ~8.59 GB
Production default: true
```

Di prototype, definisi ini ada di:

```text
PrototypeC3A02/LocalLLMModels.swift
```

Contoh struktur catalog:

```swift
LocalLLMModel(
    id: "gemma-4-e2b-it-litertlm",
    name: "Gemma-4-E2B-it",
    provider: "LiteRT Community",
    modelID: "litert-community/gemma-4-E2B-it-litert-lm",
    runtime: .liteRTLM,
    description: "Gemma 4 E2B LiteRT-LM package from the AI Edge Gallery allowlist.",
    sizeInBytes: 2_583_085_056,
    estimatedPeakMemoryInBytes: 8_589_934_592,
    files: [
        LocalLLMFile(
            relativePath: "gemma-4-E2B-it.litertlm",
            urlString: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/<revision>/gemma-4-E2B-it.litertlm",
            sizeInBytes: 2_583_085_056
        )
    ],
    defaultConfiguration: .default
)
```

Production recommendation:

- Jadikan Gemma-4-E2B-it sebagai satu-satunya model yang tampil di UI production.
- Jangan tampilkan model lain di production UI kecuali ada keputusan produk baru.
- Kalau kode internal masih menyimpan catalog model lain untuk eksperimen, sembunyikan dari build production dengan feature flag.
- Tambahkan remote manifest agar URL, revision, size, checksum, dan compatibility bisa diperbarui tanpa update app.
- Simpan model revision secara eksplisit agar file yang di-download stabil.
- Tambahkan SHA256 checksum verification setelah download selesai.

## 6. Model Download dan Install

Model `Gemma-4-E2B-it` wajib di-download sebelum fitur `Generate Insight` bisa berjalan. Karena ukuran model sekitar 2.58 GB, app harus menjelaskan ini secara eksplisit ke user sebelum download.

Required UX:

- Jika user membuka Dashboard dan menekan `Generate Insight` sebelum model ter-install, tampilkan popup.
- Jangan mencoba generate tanpa model.
- Popup harus memberi pilihan:
  - `Download Model`
  - `Cancel`
- Jika user memilih `Download Model`, arahkan ke Models screen atau langsung mulai download setelah confirmation.

Suggested popup copy:

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

SwiftUI guard pattern:

```swift
guard let installedModel = library.installedGemma4E2BModel else {
    showDownloadRequiredAlert = true
    return
}
```

Alert pattern:

```swift
.alert("Download Gemma-4-E2B-it First", isPresented: $showDownloadRequiredAlert) {
    Button("Download Model") {
        selectedTab = .models
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("On-device insight generation needs the Gemma-4-E2B-it model before it can run. The download is about 2.58 GB and stays on this iPhone or iPad.")
}
```

### 6.1 Storage Path

Prototype menyimpan model di Documents:

```text
Documents/LocalLLMModels/<model.id>/
```

Untuk Gemma-4-E2B-it:

```text
Documents/LocalLLMModels/gemma-4-e2b-it-litertlm/gemma-4-E2B-it.litertlm
```

Alasan memakai Documents:

- File bertahan setelah app restart.
- File terlihat sebagai Documents & Data di iOS Settings.
- Tidak hilang seperti cache.

Production recommendation:

- Tetap gunakan Documents atau Application Support.
- Jika memakai Application Support, pastikan folder dibuat sebelum CoreData/UserDefaults/runtime akses.
- Jangan tampilkan delete/redownload sebagai production user control; file cleanup boleh tetap ada sebagai internal maintenance atau debug-only tool.
- Cek free disk space sebelum download.
- Beri opsi Wi-Fi only untuk file besar.
- Jangan bundle model 2.58 GB ke app binary kecuali ada alasan distribusi khusus.
- Setelah download selesai, pilih `Gemma-4-E2B-it` sebagai installed model otomatis.

### 6.2 Resumable Download

Prototype memakai downloader custom:

- Download ke file sementara `*.download`.
- Jika koneksi putus, lanjutkan dengan HTTP `Range`.
- Progress dihitung dari bytes jika server memberi content length.
- Jika server tidak memberi size, progress fallback ke jumlah file selesai.
- Setelah partial file mencapai expected size, file dipindahkan ke nama final.

State progress:

```text
modelID
fileName
completedFiles
totalFiles
completedBytes
totalBytes
isDownloading
message
```

Production recommendation:

- Tampilkan progress bar berdasarkan bytes.
- Tampilkan file name yang sedang di-download.
- Sediakan cancel.
- Sediakan retry/resume.
- Jangan tandai model sebagai installed sebelum semua file final ada.
- Lakukan validation:
  - file exists
  - size matches expected size
  - checksum matches expected checksum
  - extension `.litertlm` ditemukan

### 6.3 Installed Model Metadata

Prototype menyimpan metadata installed model di UserDefaults:

```text
localLLMInstalledModels
localLLMSelectedModelID
localLLMConfiguration
```

Production recommendation:

- Untuk model kecil, UserDefaults metadata cukup.
- Untuk model banyak atau state kompleks, gunakan SwiftData/CoreData.
- Metadata harus dapat direkonstruksi dari disk jika UserDefaults rusak.
- Saat app start, scan folder model dan repair installed metadata.

## 7. Install Gemma-4-E2B-it dari Hugging Face

Untuk production, import harus dibatasi ke `Gemma-4-E2B-it` saja. App boleh memakai URL tetap dari manifest internal, atau menerima paste URL selama URL tersebut divalidasi sebagai repo/file Gemma-4-E2B-it yang benar.

Dua pola URL yang boleh diterima:

1. Paste Hugging Face model page URL:

```text
https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
```

2. Paste direct file URL:

```text
https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
```

Supported file type:

```text
.litertlm
```

Untuk production:

- Tolak file selain `gemma-4-E2B-it.litertlm`.
- Tolak repo selain `litert-community/gemma-4-E2B-it-litert-lm`, kecuali manifest production sudah diubah secara sadar.
- Tampilkan estimated size dan compatibility sebelum user menekan Download.
- Minta user menerima license model jika model license mengharuskan.
- Jangan mengirim data anak ke Hugging Face. Hugging Face hanya untuk download model.
- Setelah download selesai, jalankan validation dan set model sebagai selected model.

## 8. Runtime Configuration

Prototype menyimpan konfigurasi di `LocalLLMConfiguration`.

Default yang dipakai:

```text
maxTokens: 1024
topK: 40
topP: 0.95
temperature: 0.7
accelerator: GPU
enableThinking: false
enableSpeculativeDecoding: false
```

Untuk generation analytics, output token limit di-clamp lebih rendah agar memory dan latency lebih aman:

```text
output tokens: 128...512
```

Production recommendation:

- Gunakan temperature rendah sampai sedang untuk analytics.
- Jangan pakai max output terlalu besar.
- Jangan expose semua low-level sampling config ke user biasa.
- Simpan Advanced Settings untuk internal/debug builds saja.
- Jangan tampilkan prompt/context editor di production user UI.
- Default accelerator GPU, fallback CPU jika GPU gagal.
- Speculative decoding hanya aktif jika runtime dan model sudah terbukti stabil.

## 9. System Prompt dan Context

System prompt prototype menekankan:

- App adalah on-device storytelling analytics engine.
- Output bukan chatbot.
- Tidak boleh diagnosis.
- Tidak boleh medical claims.
- Harus memakai data rows yang diberikan.
- Tidak boleh mengarang research claim.
- Harus return compact JSON.

Schema output yang diminta:

```json
{
  "summary": "One concise paragraph with the overall insight.",
  "commonTriggers": [
    {
      "title": "Nighttime",
      "explanation": "Grounded explanation from rows."
    }
  ],
  "observedPatterns": [
    {
      "title": "Short evidence label",
      "evidence": "Concrete observation tied to rows.",
      "linkedTrigger": "Nighttime",
      "contextTags": ["Night", "Home", "Scared"]
    }
  ],
  "parentReflectionPrompt": "One gentle question.",
  "ethicalNote": "Privacy and non-diagnosis reminder."
}
```

Context notes prototype:

```text
Child profile: Leo, age 4.
Data fields: date, scene, place, activity, mood, reason, and parent note.
Dashboard goal: explain mood patterns, common triggers, and context comparison visualizations.
Output style: structured analytics for charts and reflective summaries, not a chatbot reply.
```

Production recommendation:

- Pisahkan prompt menjadi:
  - system prompt
  - domain context
  - child profile
  - data scope description
  - event rows
- Jangan masukkan data yang tidak diperlukan.
- Batasi jumlah event rows per prompt.
- Jangan biarkan LLM membuat parenting strategy berbasis riset secara bebas.
- LLM hanya mengidentifikasi summary, common triggers, dan observed evidence.

## 10. Generate Insight Flow

Prototype flow:

1. User membuka Dashboard.
2. User menekan menu `Generate Insight`.
3. App mengecek apakah `Gemma-4-E2B-it` sudah ter-install.
4. Jika belum ter-install, app menampilkan popup `Download Gemma-4-E2B-it First` dan menghentikan generate.
5. Jika sudah ter-install, user memilih data scope:
   - All data
   - Weekly data
   - Pick a date
6. App mengambil events sesuai scope.
7. Jika `Gemma-4-E2B-it` belum loaded, app load model via LiteRT-LM.
8. App build analytics prompt.
9. LiteRT-LM generate JSON.
10. App parse JSON.
11. App attach parent recommendations dari curated catalog.
12. App save generated insight.
13. App offload model dari memory.
14. Dashboard render insight.

Pseudo-code:

```swift
let events = selectedScope.events(from: allEvents)

guard let installedModel = library.installedGemma4E2BModel else {
    showDownloadRequiredAlert = true
    return
}

if !runtimeSession.isLoaded(model: installedModel) {
    await runtimeSession.load(model: installedModel, configuration: config)
}

let insight = try await runtimeSession.generateAnalytics(
    events: events,
    configuration: config,
    model: installedModel
)

library.saveGeneratedInsight(insight)
```

UX requirement:

- Saat generate, tampilkan loading animation.
- Disable tombol generate agar tidak double-submit.
- Jangan terlihat freeze.
- Beri pesan state:
  - model required
  - loading model
  - generating insight
  - retrying smaller prompt
  - completed
  - failed with reason

## 11. LiteRT-LM Runtime Lifecycle

File utama:

```text
PrototypeC3A02/LiteRTLMAnalyticsRuntime.swift
```

State runtime:

```text
offloaded
loading
loaded
generating
failed
```

Load flow:

```swift
releaseRuntime()
state = .loading(...)
find .litertlm file
create EngineConfig
initialize Engine
create Conversation
state = .loaded(...)
schedule idle offload
```

Generate flow:

```swift
guard events not empty
guard model is loaded
state = .generating(...)
generate output
releaseRuntime()
parse output
state = .offloaded
return insight
```

Offload flow:

```swift
try? conversation?.cancel()
conversation = nil
engine = nil
loadedModelID = nil
state = .offloaded
```

Production recommendation:

- Load model just-in-time.
- Generate.
- Immediately release conversation and engine.
- Do not keep model loaded forever in final app.
- Do not expose manual load/offload controls to production users.
- Production UX should automate load/offload completely.

## 12. Memory Management

This is critical for iOS/iPadOS.

Prototype memory strategy:

- Runtime is stored in a single `LocalLLMRuntimeSession`.
- `generateAnalytics` releases model after every generation.
- Runtime offloads on:
  - generation completion
  - generation failure
  - app entering background
  - memory warning
  - idle timeout after load
- `conversation?.cancel()` is called before references are nilled.
- `engine` and `conversation` are set to nil.

Expected behavior:

- RAM rises while model is loaded.
- RAM may not return exactly to initial value because iOS, Metal, malloc, and runtime caches can hold memory temporarily.
- It should not keep increasing unbounded after repeated generate/offload cycles.

Production hardening:

- Add repeated load/generate/offload memory test.
- Track resident memory after each cycle.
- Add safety threshold:
  - if memory pressure is high, refuse generation with friendly message.
  - suggest closing other apps, restarting the app, or trying again after memory pressure drops.
- Prefer smaller prompt and smaller output.
- Limit events per generation.
- Avoid keeping large raw LLM output strings in state longer than needed.
- Store generated insight as parsed compact data, not raw output.
- Keep model cache in `Caches/LiteRTLMCache`, but do not rely on cache for required model files.
- On app background, always offload.

Suggested production policy:

```text
On Generate tapped:
  load model
  generate
  parse
  save compact insight
  offload model

On app background:
  cancel generation if possible
  offload model

On memory warning:
  cancel generation if possible
  offload model
  clear transient raw strings
```

## 13. Prompt Size and Retry Strategy

Prototype limits event rows:

```text
Primary prompt: up to 24 events
Fallback prompt: up to 10 events
```

If generation fails, app retries with smaller dashboard prompt.

Production recommendation:

- Keep a deterministic fallback path:
  - retry smaller prompt
  - fallback to rule-based insight if local LLM fails
  - never show raw broken JSON to user
- Keep model output compact.
- Request JSON only.
- Avoid long prose in model output.
- Let UI and curated catalog expand recommendations.

## 14. Parsing Output and Backward Compatibility

Generated insight schema:

```text
summary
commonTriggers
observedPatterns
parentRecommendations
parentReflectionPrompt
ethicalNote
modelName
generatedAt
```

Important schema change:

- Old field: `notablePatterns: [String]`
- New field: `observedPatterns: [GeneratedLLMObservedPattern]`

Prototype keeps backward decoding for old saved insights.

Production recommendation:

- Version the schema.
- Keep migration code for saved insights.
- Parse strict JSON first.
- If parsing fails, salvage safe sections only.
- Never render full raw model output as "Overall Insight".
- If output is malformed, show friendly error and allow retry.

## 15. Parent Recommendations

LLM should not freely invent science-based claims.

Prototype recommendation strategy:

- LLM generates:
  - common triggers
  - observed patterns
  - summary
- App deterministically selects parent recommendations from curated catalog.
- Recommendations are matched primarily by `commonTriggers`, prioritized by `observedPatterns`, and framed by `summary`.

Recommendation fields:

```text
title
action
whyItHelps
basedOnTrigger
basedOnEvidence
sourceLabels
sourceURL
```

Source labels used:

- CDC
- AAP
- Harvard

Source categories:

- Routines and predictability.
- Emotion naming/coaching.
- Positive attention/praise.
- Calm limits and choices.
- Serve-and-return responsive connection.
- Body needs check for hunger/tired patterns.

Production recommendation:

- Keep recommendation text bundled and reviewed.
- Keep visible source labels in UI.
- Use tap or long-press popup for "why this helps".
- Add non-diagnostic note.
- Do not imply therapy, diagnosis, or medical certainty.

## 16. Dashboard UI Behavior

Generated insight should render in this order:

1. Overall Insight
2. Common Triggers
3. Observed Patterns
4. Parent Recommendations
5. Reflection / non-diagnostic note

Production UI guidelines:

- Insight cards should be full-width and readable on iPhone and iPad.
- Use loading animation during generation.
- Use tappable or long-pressable recommendation cards.
- Keep source labels visible.
- Do not show raw JSON unless in debug mode.
- On iPad, use wider layout but keep sections readable.

## 17. Model Scope: Gemma-4-E2B-it Only

Production scope untuk dokumen ini:

- Satu model: `Gemma-4-E2B-it`.
- Satu runtime: LiteRT-LM.
- Satu file format: `.litertlm`.
- Satu analytics schema: `GeneratedLLMAnalyticsInsight`.

Yang tidak masuk scope dokumen ini:

- Backend LLM lain.
- Model Gemma lain.
- Model non-Gemma.
- Chatbot UI.
- Server-side LLM.

Alasan scope dibuat sempit:

- Mengurangi risiko compatibility.
- Mengurangi variasi memory behavior.
- Membuat QA lebih jelas.
- Membuat user journey sederhana: download satu model, lalu generate insight.
- Menghindari kebingungan user saat memilih model.

Production UI harus menampilkan `Gemma-4-E2B-it` sebagai required analytics model, bukan sebagai salah satu opsi dari banyak model.

## 18. iPhone and iPad Considerations

Target support:

- iPhone
- iPad

Production checklist:

- Confirm target family includes both.
- Test physical iPhone and physical iPad, not only simulator.
- Use adaptive layout:
  - compact width for iPhone
  - wider dashboard cards for iPad
  - avoid iPad-only assumptions
- For model memory, prefer physical device tests.
- Simulator is useful for UI/build tests, but cannot fully validate real neural runtime memory behavior.

Device guidance:

- Gemma-4-E2B-it is the practical default for newer devices with enough RAM.
- Do not show larger or experimental models in production UI for this flow.
- Add compatibility messaging before download.

## 19. Error Handling

Important errors and expected UX:

```text
Gemma-4-E2B-it not downloaded
  -> Show the "Download Gemma-4-E2B-it First" popup and stop generation.

Model partial
  -> Show partial status and allow resume.

No .litertlm file found
  -> Repair metadata by scanning model folder, or return user to the download flow.

Load failed
  -> Show model/runtime error and keep app alive.

Generation failed
  -> Retry smaller prompt once, then show actionable failure.

Native output nil
  -> Reset conversation/runtime, offload, allow retry.

Memory warning
  -> Cancel/offload and show friendly message if generation was active.
```

Production recommendation:

- Avoid scary native errors in user-facing text.
- Keep detailed errors in logs.
- Offer retry/resume.
- Keep delete/redownload and diagnostics in internal/debug builds only.
- Do not offer alternate model choices in the production error state.

## 20. Testing Plan

Prototype tests already cover key areas:

- Model catalog contains `Gemma-4-E2B-it`.
- Hugging Face import URL parsing.
- Download partial repair.
- Prompt contract.
- JSON parsing.
- Backward compatibility for old `notablePatterns`.
- Truncated/malformed JSON handling.
- Parent recommendation matching and fallback.
- iPhone simulator tests.
- iPad simulator build.

Production test plan:

- Verify the app target does not depend on SwiftPM product `LiteRTLM`.
- Verify `CLiteRTLM.xcframework` is linked and embedded.
- Run clean `xcodebuild build` after removing any stale SwiftPM package resolution.
- Unit test catalog revisions, size, and file paths.
- Unit test that production catalog exposes only `Gemma-4-E2B-it`.
- Unit test that `Generate Insight` shows download-required popup when the model is missing.
- Unit test downloader resume behavior.
- Unit test checksum validation.
- Unit test installed metadata repair after app reinstall/update.
- Unit test parser for LiteRT-LM output.
- UI test generate insight loading state.
- UI test iPhone and iPad dashboard layout.
- Memory test repeated cycles:
  - load
  - generate
  - offload
  - clear insight
  - repeat 10-20 times
- Physical device test with actual Gemma-4-E2B-it file.
- Test app background during generation.
- Test low storage and poor network.

## 21. Production Readiness Checklist

Before shipping:

- [ ] LiteRT-LM binary source and license reviewed.
- [ ] No SwiftPM `LiteRTLM` package product is attached to the app target.
- [ ] `CLiteRTLM.xcframework` is linked, embedded, and code-signed.
- [ ] Swift files import `CLiteRTLM`, not rejected package product `LiteRTLM`.
- [ ] Stale SwiftPM package resolution/cache has been removed after vendoring the framework.
- [ ] Gemma model license reviewed.
- [ ] App privacy labels reviewed.
- [ ] Model download consent screen added.
- [ ] Download-required popup appears before generation if Gemma-4-E2B-it is missing.
- [ ] Production UI exposes only Gemma-4-E2B-it for this analytics flow.
- [ ] Disk space check added.
- [ ] SHA256 checksum verification added.
- [ ] Resume/cancel/retry download tested.
- [ ] Model folder repair tested.
- [ ] Physical iPhone memory tested.
- [ ] Physical iPad memory tested.
- [ ] Background offload tested.
- [ ] Memory warning offload tested.
- [ ] Raw JSON never shown in production UI.
- [ ] Parent recommendation text reviewed.
- [ ] Source labels visible.
- [ ] Non-diagnostic note visible.
- [ ] Fallback analytics works when LLM fails.
- [ ] No production user controls for load/offload/delete/redownload/prompt configuration.
- [ ] Crash and memory telemetry added for internal builds.

## 22. File Map in Prototype

Main implementation files:

```text
PrototypeC3A02/LocalLLMModels.swift
  Model catalog, configuration, downloaded model metadata, parser models,
  recommendation catalog, download manager.

PrototypeC3A02/LiteRTLMAnalyticsRuntime.swift
  LiteRT-LM runtime session, load/generate/offload lifecycle, memory warning
  and background observers.

PrototypeC3A02/ModelSelectionView.swift
  Models UI for Gemma-4-E2B-it download only. Load/offload and prompt/context
  configuration are internal or debug-only.

PrototypeC3A02/DashboardView.swift
  Dashboard charts, generate insight menu, data scope selection, insight UI,
  parent recommendation popups.

PrototypeC3A02/LiteRTLMVendor/
  Vendored LiteRT-LM framework and Swift wrapper files.

PrototypeC3A02Tests/LocalLLMModelTests.swift
  Tests for catalog, parser, download state, recommendations, and prompt schema.
```

## 23. Minimal Production Implementation Order

Recommended order for rebuilding this in a non-prototype app:

1. Add domain data model for story events.
2. Add analytics schema types.
3. Add curated recommendation catalog.
4. Add LiteRT-LM binary framework.
5. Add Swift wrapper/runtime session.
6. Add model catalog with Gemma-4-E2B-it.
7. Add model downloader with resume and validation.
8. Add installed model metadata persistence.
9. Add prompt/context builder.
10. Add generate insight service.
11. Add parser with fallback repair.
12. Add dashboard UI.
13. Add loading/error states.
14. Add automatic offload policy.
15. Add tests and physical-device profiling.

## 24. Final Production Principle

For this product, the LLM should be treated as an on-device analytics component, not the product voice.

The safest architecture is:

- LLM finds patterns from local rows.
- App validates and parses the result.
- App selects parent recommendations from reviewed source-backed content.
- UI explains the insight gently.
- Runtime is released as soon as possible.

This keeps the app useful, private, and much safer for parents than a free-form chatbot approach.
