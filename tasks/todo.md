# Tasks: Meeting Recorder

Plan: [plan.md](plan.md) · Spec: [../SPEC.md](../SPEC.md)

Build commands (from SPEC §5):
```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project MeetingRecorder.xcodeproj -scheme MeetingRecorder -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MeetingRecorder.xcodeproj -scheme "MeetingRecorder Watch App" -destination 'generic/platform=watchOS Simulator' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
```
Tests run only when the user asks.

---

## Phase A — Foundation + risk

- [x] **Task 1: XcodeGen project skeleton** (done 2026-11-24; tests not run)
  - Acceptance: `project.yml` defines the iOS app, embedded Watch app, and Swift Testing target; `Shared/` compiles into both apps; iOS 27 / watchOS 27; microphone usage strings in Thai; `UIBackgroundModes: audio` on Watch. Both apps launch to a placeholder screen.
  - Verify: `xcodegen generate` + both `xcodebuild … build` succeed.
  - Files: `project.yml`, `MeetingRecorder/MeetingRecorderApp.swift`, `MeetingRecorder Watch App/MeetingRecorderWatchApp.swift`, `Shared/.gitkeep`, `MeetingRecorderTests/SmokeTests.swift`
  - Size: S

- [ ] **Task 2: R1 spike — Watch background recording on a real Ultra 4**
  - Acceptance: minimal Watch screen with start/stop; `AVAudioRecorder` rotates a file every 5 min; the result of a 30-min wrist-down test is written to `docs/r1-watch-background.md` (works / stops at N min / which plist keys were needed).
  - Verify: manual on device (**needs the user's Watch + signing team**).
  - Files: `MeetingRecorder Watch App/Recording/SpikeRecorderView.swift`, `…/SpikeRecorder.swift`, `project.yml`, `docs/r1-watch-background.md`
  - Size: S
  - Dependencies: 1

- [x] **Task 3: Core model + chunk logic (Shared)** (done 2026-11-24; ⭐ markers added; 6/6 tests pass on iPhone 17 Pro simulator)
  - Acceptance: `RecordingManifest` (id, start, chunks[], markers[], state) is Codable; `ChunkPlanner` names and rotates chunk files; `RecoveryScanner` turns an unfinished directory into an `interrupted` manifest; `ProcessingState` enum matches SPEC §4.
  - Verify: Swift Testing tests for rotation, recovery, manifest round-trip (run when asked); both apps build.
  - Files: `Shared/Model/RecordingManifest.swift`, `Shared/Model/ProcessingState.swift`, `Shared/Recording/ChunkPlanner.swift`, `Shared/Recording/RecoveryScanner.swift`, `MeetingRecorderTests/ChunkLogicTests.swift`
  - Size: M
  - Dependencies: 1

### Checkpoint A
- [ ] Both apps build · R1 result known · human review (if R1 fails, revisit the spec before Phase B)

## Phase B — Recording

- [x] **Task 4: Shared `ChunkedRecorder` + Watch recording UI** (done 2026-11-24 in simulator: Liquid Glass buttons, ⭐ marker, double-tap stop, Always-On view; real-device check pending Task 2)
  - Acceptance: Home / Recording / After-stop screens as in plan.md; permission request; consent sheet; wrist-mic notice; pre-flight battery/storage line; level meter; haptics; Always-On reduced view.
  - Verify: build; simulator UI check; device check that the timer and chunks are correct.
  - Files: `Shared/Recording/ChunkedRecorder.swift`, `MeetingRecorder Watch App/Recording/HomeView.swift`, `…/RecordingView.swift`, `…/ConsentSheet.swift`, `…/PreflightStatus.swift`
  - Size: M
  - Dependencies: 2, 3

- [ ] **Task 5: Interruptions + crash recovery** (code landed with Task 4: OS 27 `didBecomeInactiveNotification`, recovery on launch, resume as new part. Device test still open)
  - Acceptance: call/Siri/route change ends the part and saves audio; low storage stops cleanly; on relaunch an unfinished recording appears as `interrupted` with “บันทึกต่อ / จบ”.
  - Verify: device test with an incoming call; kill the app mid-recording, relaunch, saved chunks intact.
  - Files: `Shared/Recording/ChunkedRecorder.swift`, `MeetingRecorder Watch App/Recording/InterruptedView.swift`, `…/WatchRecordingModel.swift`
  - Size: S
  - Dependencies: 4

- [ ] **Task 6: iPhone recording screen**
  - Acceptance: same flow on iPhone using `ChunkedRecorder`; the recording becomes a meeting in the library directly (no transfer).
  - Verify: simulator recording produces chunk files.
  - Files: `MeetingRecorder/Record/RecordView.swift`, `MeetingRecorder/Record/PhoneRecordingModel.swift`
  - Size: S
  - Dependencies: 4 (library insert lands in Task 8)

### Checkpoint B
- [ ] 30-min recordings on Watch and iPhone produce the expected chunks · human review

## Phase C — Transfer + library

- [ ] **Task 7: Watch → iPhone chunk transfer**
  - Acceptance: each closed chunk is queued with `transferFile` plus manifest metadata; iPhone saves it to Application Support and acks; Watch deletes only acked chunks; Watch recent list shows `บนนาฬิกา / กำลังส่ง n/m / อยู่บน iPhone`.
  - Verify: paired simulators; device test with iPhone out of range, then reconnect.
  - Files: `Shared/Transfer/TransferMessage.swift`, `MeetingRecorder Watch App/Transfer/WatchTransferService.swift`, `MeetingRecorder/Transfer/PhoneTransferService.swift`, `MeetingRecorder Watch App/Recording/RecentListView.swift`
  - Size: M
  - Dependencies: 5

- [ ] **Task 8: SwiftData store + library list**
  - Acceptance: `Meeting`/`Chunk` models (CloudKit-compatible shape) behind `MeetingStore`; list with title/date/duration/status/badges; search; sort by date/title; empty/error states.
  - Verify: build; meetings persist across relaunch in the simulator.
  - Files: `MeetingRecorder/Persistence/Meeting.swift`, `…/MeetingStore.swift`, `MeetingRecorder/Library/LibraryView.swift`, `…/MeetingRow.swift`
  - Size: M
  - Dependencies: 3, 7

- [ ] **Task 9: Meeting detail basics**
  - Acceptance: rename, date/duration, playback across chunks with progress, delete with a confirmation that lists what is removed.
  - Verify: simulator check.
  - Files: `MeetingRecorder/Detail/MeetingDetailView.swift`, `…/ChunkPlayer.swift`, `…/DeleteConfirmation.swift`
  - Size: M
  - Dependencies: 8

### Checkpoint C
- [ ] Record on Watch → appears on iPhone → plays → survives relaunch · human review

## Phase D — Transcription (Mac)

- [ ] **Task 10: Native macOS menu-bar app "MeetingRecorder Server"** (decided 2026-11-24: native Mac app replaces the launchd plist)
  - Acceptance: SwiftUI `MenuBarExtra` app (macOS target in `project.yml`) starts the Python ASR server as a child process on 127.0.0.1:18081, restarts it on crash, shows status (loading / ready / error) and the last jobs; "Open at login" via `SMAppService`; `mac-server/setup.sh` reproduces the venv + model download; README for `tailscale serve --bg 18081`.
  - Verify: build the macOS target; launch → health ready; quit → server process gone; from iPhone over Tailscale → health OK.
  - Files: `project.yml`, `MeetingRecorder Mac/MeetingRecorderServerApp.swift`, `MeetingRecorder Mac/ASRServerProcess.swift`, `MeetingRecorder Mac/ServerMenuView.swift`, `mac-server/setup.sh`
  - Size: M
  - Dependencies: none (needs Tailscale installed by the user)

- [ ] **Task 11: `MacASRProvider` + per-chunk pipeline**
  - Acceptance: one-time disclosure before the first upload; chunks sent one by one; per-chunk transcript stored; `waitingForServer` on failure; retry re-sends only missing chunks; server URL + health in Settings.
  - Verify: tests for the pipeline state machine with a fake provider (when asked); real run against the Mac.
  - Files: `MeetingRecorder/Processing/TranscriptionProvider.swift`, `…/MacASRProvider.swift`, `…/TranscriptionPipeline.swift`, `MeetingRecorder/Settings/ServerSettingsView.swift`, `MeetingRecorderTests/PipelineTests.swift`
  - Size: M
  - Dependencies: 8, 10

- [ ] **Task 12: Transcript view**
  - Acceptance: segments with meeting-relative timestamps; tap a line to seek; markers shown if Task 4 adds them; good Thai line spacing.
  - Verify: simulator check with a real transcript.
  - Files: `MeetingRecorder/Detail/TranscriptView.swift`, `…/TranscriptLine.swift`
  - Size: S
  - Dependencies: 9, 11

- [ ] **Task 13: Benchmark run 2 (real audio)**
  - Acceptance: the user's 5-min Watch m4a transcribed at 560/1120 ms × th-TH/th-mix; speed and readability recorded; defaults chosen.
  - Verify: `mac-server/BENCHMARK.md` updated.
  - Files: `mac-server/BENCHMARK.md`
  - Size: XS
  - Dependencies: user's audio file (can run any time)

### Checkpoint D
- [ ] Watch recording → transcript on iPhone, end to end · human review

## Phase E — Summary + export

- [ ] **Task 14: Output selection + Claude hand-off**
  - Acceptance: sheet to pick outputs and language; prompt builder (fixed headings, “ไม่ระบุ” rule, uncertainty section, numbered parts for long transcripts); “เปิดใน Claude” share + copy.
  - Verify: tests for the prompt builder (when asked); manual paste into the Claude app.
  - Files: `MeetingRecorder/Processing/OutputSelectionSheet.swift`, `…/ClaudePromptBuilder.swift`, `MeetingRecorderTests/PromptBuilderTests.swift`
  - Size: M
  - Dependencies: 12

- [ ] **Task 15: Paste-back + result cards**
  - Acceptance: “วางผลสรุป” field; stored as-is with the label “สรุปโดย Claude (วางเอง)”; headings parsed into summary/decisions/action items cards; raw text is shown when parsing fails.
  - Verify: parser tests (when asked).
  - Files: `MeetingRecorder/Processing/SummaryPasteView.swift`, `…/SummaryParser.swift`, `MeetingRecorder/Detail/ResultCards.swift`, `MeetingRecorderTests/SummaryParserTests.swift`
  - Size: M
  - Dependencies: 14

- [ ] **Task 16: TXT + DOCX export**
  - Acceptance: section picker; UTF-8 TXT; DOCX built with an in-house store-only ZIP; opens in Pages and Word with headings.
  - Verify: `unzip -t` on the output; open in Pages.
  - Files: `MeetingRecorder/Export/ExportSections.swift`, `…/TextExporter.swift`, `…/DocxExporter.swift`, `…/ZipWriter.swift`, `MeetingRecorderTests/DocxExporterTests.swift`
  - Size: M
  - Dependencies: 15

- [ ] **Task 17: PDF export + share**
  - Acceptance: A4; title/date header; page numbers; Core Text Thai wrapping with no clipped lines; `ShareLink` for all three formats.
  - Verify: 10-page Thai transcript PDF checked visually.
  - Files: `MeetingRecorder/Export/PDFExporter.swift`, `MeetingRecorder/Export/ExportSheet.swift`
  - Size: S
  - Dependencies: 16

### Checkpoint E
- [ ] Full flow: record → transcript → Claude summary → export 3 formats · human review

## Phase F — Polish

- [ ] **Task 18: Settings + privacy controls**
  - Acceptance: language mode, default outputs, audio retention, delete all data (with confirmation), consent text synced to Watch via `transferUserInfo`.
  - Verify: change the consent text on iPhone → appears on Watch.
  - Files: `MeetingRecorder/Settings/SettingsView.swift`, `…/AppSettings.swift`, `Shared/Transfer/TransferMessage.swift`
  - Size: M
  - Dependencies: 11

- [ ] **Task 19: Accessibility + localization pass**
  - Acceptance: String Catalog Thai (default) + English; VoiceOver labels on every control; AX5 layouts hold; Reduce Motion respected; contrast checked.
  - Verify: Accessibility Inspector on key screens; review with the `swiftui-pro` skill.
  - Files: `Localizable.xcstrings`, views touched as needed (split if more than 5)
  - Size: M
  - Dependencies: all

### Checkpoint F
- [ ] SPEC §10 success criteria all met · ready for daily use
