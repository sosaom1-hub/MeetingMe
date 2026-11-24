# Spec: Meeting Recorder (Apple Watch + iPhone + personal Mac server)

Status: **v2 + v3 approved 2026-11-24.** Tasks 1, 3 and 4 are built; see `tasks/todo.md`.

## 0. Verified environment (2026-11-24)

| Item | Value | Source |
|---|---|---|
| Xcode | 27.2 (27B52), at `/Applications/Xcode.app` | `xcodebuild -version` |
| SDKs | iOS 27.2, watchOS 27.2 | `xcrun --sdk … --show-sdk-version` |
| Swift | 6.4.2 | `xcrun swift --version` |
| iPhone 17 Pro | Present as simulator device type `iPhone-17-Pro` | `simctl list devicetypes` |
| Apple Watch Ultra 4 | Present as `Apple-Watch-Ultra-4-49mm`. Apple lists a three-mic array with beamforming; requires iPhone 11+ on iOS 27+ | `simctl`, https://support.apple.com/en-us/148758 |
| Mac server | Apple M4 Pro, 14 cores, 24 GB RAM, 566 GB free | `sysctl`, `df` |

Note: `xcode-select` points at CommandLineTools. Commands below set `DEVELOPER_DIR` per call instead of changing the global setting.

## 1. Decisions and assumptions

Approved by user:
- **D1. Speech-to-text runs on the user's own Mac** using OpenThai 2.0 ASR Streaming (iApp, 0.64B params, OpenMDW-1.1, weights at https://huggingface.co/iapp/OpenThai2.0-ASR-Streaming). No paid STT API.
- **D2. iPhone reaches the Mac over Tailscale** (private tailnet). The Mac is the primary processing server.
- **D3. Summaries use the user's existing Claude app subscription**: the iPhone app prepares a prompt + transcript and hands it to the Claude app via share sheet / copy. The user pastes the answer back. No Claude API, no API keys anywhere.
- **D4. Recording input: Apple Watch or iPhone.** Both produce the same chunked recording format.

Assumed (correct before implementation if wrong):
1. Deployment targets iOS 27.0 / watchOS 27.0.
2. Swift 6 / SwiftUI, strict concurrency. UIKit only for PDF pagination (`UIGraphicsPDFRenderer`).
3. iPhone persistence: SwiftData, CloudKit-compatible model shape, CloudKit not enabled.
4. Audio files in Application Support, Data Protection `completeUntilFirstUserAuthentication`.
5. Recording: `AVAudioRecorder`, AAC mono 16 kHz ~32 kbps (~14 MB/h), rotated into 5-minute chunks.
6. Watch → iPhone via `WCSession.transferFile` per chunk; Watch deletes a chunk only after iPhone ack.
7. iPhone → Mac: one `POST /v1/transcribe` per chunk (≈5 min audio each), so an upload or decode failure retries one chunk, not the whole meeting. Server cuts each chunk at pauses (`split=auto`).
8. No third-party Swift dependencies. DOCX via in-house store-only ZIP writer.
9. Default UI language Thai via String Catalog.
10. Results (transcript, pasted summary) live on iPhone. Watch shows recording/transfer/processing status, never transcript text.
    **Amended 2026-11-24 (user decision, relayed by session 6c):** the Watch may also show short summary content (decisions, action items) from the pasted summary. Full transcripts stay off the Watch.

## 2. Objective

Personal app. User records a meeting on Apple Watch Ultra 4 or iPhone 17 Pro. The iPhone collects the audio, sends it to the user's Mac for Thai/English transcription, stores the transcript, helps the user get a summary from the Claude app, and exports chosen sections as TXT, PDF, or DOCX.

Non-goals for MVP: accounts, cloud database, iCloud sync, paid APIs, public internet exposure of the Mac, Watch-side transcript reading, automatic processing, on-iPhone ASR.

## 3. Capability map

| Module id | Responsibility | Depends on |
|---|---|---|
| `core-model` | Shared types: `Meeting`, `AudioChunk`, `ProcessingState`, `OutputKind`, chunk manifest; `MeetingStore` protocol (persistence boundary for later iCloud) | — |
| `recorder` | Chunked recording engine shared by Watch and iPhone; permission, consent reminder, pre-flight battery/storage warning, interruption handling, crash recovery; Watch UI + iPhone record screen | core-model |
| `transfer` | WatchConnectivity chunk + status transfer, ack, retry, queued/transferred states | core-model, recorder |
| `phone-library` | SwiftData store, library list, search/sort, detail, playback, rename, delete, settings | core-model, transfer |
| `mac-asr-server` | OpenThai server on the Mac: install script, launchd agent, `tailscale serve` HTTPS, health check | — |
| `processing` | `TranscriptionProvider` protocol + `MacASRProvider`; per-chunk pipeline with retry; output selection; first-use disclosure; Claude hand-off prompt + paste-back | phone-library, mac-asr-server |
| `export` | TXT, paginated PDF (Thai line breaking), genuine DOCX, section picker, share sheet | phone-library, processing |

Build order: `mac-asr-server` (prove ASR works on real audio first) → `core-model` → `recorder` → `transfer` → `phone-library` → `processing` → `export` → polish.

## 4. Key behaviour

### Processing states (persisted per meeting)
`recording → savedOnWatch → waitingToTransfer → transferring → onPhone → awaitingSelection → waitingForServer → transcribing(chunk i/n) → transcriptReady → awaitingSummaryPaste → summaryReady → exportReady`, plus `failed(step, chunk?, reason, retryable)` and `interrupted(partialAudioSaved)`.
Each chunk stores its own transcript. Retry re-sends only chunks without one.

### Recording (Watch and iPhone)
- Start only from foreground, after microphone permission and a dismissible consent reminder (editable in settings).
- Pre-flight warning (not block): battery < 30 % or free storage < 200 MB.
- Watch shows a testable wrist-mic quality notice.
- Screen: red indicator, elapsed time, one large stop button.
- Background continuation: documented audio background mode only. No workout or unrelated extended-runtime session. See R1.
- Interruption: close current chunk, mark `interrupted`, keep saved chunks, offer continue-as-new-part or finish.
- On launch: finalize any unfinished recording directory.

### Transcription (Mac)
- iPhone sends `multipart/form-data` to `https://<mac>.<tailnet>.ts.net/v1/transcribe` with `file` (m4a chunk), `lang` (`th-TH` or `th-mix`, user setting), `latency_ms=1120` (batch accuracy over latency; to be confirmed by benchmark), `mode=standard`.
- Response `display_text` + `segments[{start,end,text}]` stored per chunk; chunk offsets added so timestamps are meeting-relative.
- Speaker labels (`mode=meeting`) are **off by default**: the server decodes that mode as one stream, which the model card says drops speech after pauses. Offer only after benchmark proves it acceptable.
- Server unreachable → state `waitingForServer` with message “Mac ปิดอยู่หรือไม่ได้เชื่อมต่อ Tailscale” and a retry button. Nothing is lost.
- Before the first upload, a one-time screen explains: audio goes only to your own Mac via your Tailscale network.

### Summary (Claude app hand-off)
- User picks outputs (summary, decisions, action items) and language (Thai / English / follow meeting).
- App builds one prompt: instructions + transcript. Instructions require fixed Markdown headings, “ไม่ระบุ” / “Not specified” for missing owners and deadlines, an uncertainty section, and no invented content.
- “Open in Claude” uses the share sheet; “Copy” is the fallback. If the transcript exceeds a safe paste size, the app splits it into numbered parts with merge instructions and says so. Never silent truncation.
- User pastes the answer into a “วางผลสรุป” field. The app stores it as-is, labelled “สรุปโดย Claude (วางเอง)”, and parses headings into sections for export when possible.

### iPhone UI
- Library: title, date/time, duration, status, output badges, search, sort date/title, empty/loading/error states, “on Watch / waiting to transfer” badge.
- Detail: rename, playback with progress, transcript, result cards, status + retry, delete with confirmation listing what is deleted.
- Settings: transcription language mode, default outputs, audio retention (keep / delete after transcript), delete all data, consent text, Mac server URL + live health check (`GET /v1/health`).

### Export
- TXT UTF-8; PDF A4 with title/date header, page numbers, Core Text Thai line breaking; DOCX real OOXML package. Share via `ShareLink`.

## 5. Commands

```sh
# Mac server (dev run, localhost only)
cd mac-server/model/serve && ../../.venv/bin/python -m uvicorn app:app --host 127.0.0.1 --port 18081
curl -s http://127.0.0.1:18081/v1/health
curl -F file=@sample.m4a -F lang=th-TH -F latency_ms=1120 -F mode=standard http://127.0.0.1:18081/v1/transcribe
# Expose to tailnet only, with HTTPS
tailscale serve --bg 18081

# Apps
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project MeetingRecorder.xcodeproj -scheme MeetingRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -project MeetingRecorder.xcodeproj -scheme "MeetingRecorder Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 4 (49mm)' build
# Tests (run only when asked)
xcodebuild test -project MeetingRecorder.xcodeproj -scheme MeetingRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 6. Project structure

```
mac-server/             .venv/ and model/ are git-ignored (~2.6 GB weights)
  setup.sh              reproducible install
  com.user.openthai-asr.plist   launchd agent (keep server running, restart on crash)
MeetingRecorder.xcodeproj
Shared/                 core-model + recorder engine (iOS + watchOS membership)
MeetingRecorder/        iPhone app: Library/ Detail/ Record/ Processing/ Export/ Settings/ Transfer/ Persistence/
MeetingRecorder Watch App/   Recording/ Transfer/
MeetingRecorderTests/   Swift Testing, logic only
SPEC.md  tasks/plan.md  tasks/todo.md
.claude/skills/         (local only, git-ignored) swiftui-pro, swiftdata-pro, swift-concurrency-pro, swift-testing-pro
```

## 7. Code style

One type per file. `@Observable` models, `@MainActor` UI, actors for file/network work, async APIs.

```swift
protocol TranscriptionProvider: Sendable {
    var displayName: String { get }
    func health() async throws -> ServerHealth
    func transcribe(chunk: URL, language: TranscriptLanguage) async throws -> ChunkTranscript
}
```

## 8. Testing strategy

Swift Testing (run only on request): chunk rotation + recovery, state machine retry per chunk, manifest round-trip, segment offset merge, prompt builder (contains “ไม่ระบุ” rule, splits long transcripts), pasted-summary heading parser, DOCX package validity (`unzip -t`), PDF multi-page Thai.
Server benchmark (stage 1): real Thai meeting audio from Watch and iPhone → CER eyeball + speed (× real time) at `latency_ms` 560 vs 1120, `th-TH` vs `th-mix`.
Manual device checks: 30+ min Watch recording wrist-down, call mid-recording, transfer while phone locked, Mac asleep during processing.

## 9. Boundaries

- **Always:** keep app buildable; preserve captured audio on any failure; report real vs stubbed per stage; server listens on 127.0.0.1 only.
- **Ask first:** new dependencies; enabling iCloud; deployment target changes; running test suites; anything that exposes the Mac beyond the tailnet.
- **Never:** API keys anywhere; `tailscale funnel` or router port-forwarding (server has no authentication); logging audio/transcripts; uploading before user action; workout/unrelated background sessions; silent deletion or truncation.

## 10. Success criteria

1. Mac server transcribes a 5-min Thai m4a chunk from a real Watch recording; speed and readability recorded in `mac-server/BENCHMARK.md`.
2. Watch and iPhone each record 3 h simulated as 36 chunks; killing the app loses ≤ 1 chunk.
3. All Watch chunks reach iPhone after reconnect; Watch deletes only acked chunks.
4. With Mac off, processing waits with a clear message; turning Mac on + retry completes without re-sending finished chunks.
5. No network request before the user taps transcribe and has seen the disclosure once.
6. Claude hand-off prompt opens in the Claude app; pasted answer is stored and exportable.
7. TXT, PDF (page numbers, unbroken Thai), DOCX (opens in Pages and Word) export.
8. VoiceOver labels all controls; AX5 Dynamic Type holds; Reduce Motion respected.

## 11. Risks

- **R1 (highest): Watch background recording.** Confirm in watchOS 27 docs and on a real Ultra 4 that `AVAudioRecorder` + audio background mode survives wrist-down. Fallback: iPhone recording or keep-frontmost guidance; never a workout session.
- **R2: ASR accuracy on wrist audio.** Vendor CER on meeting audio is 20.77 % (self-reported). Benchmark first.
- **R3: Mac availability.** Mac asleep/off blocks transcription. Mitigation: clear waiting state; optional `caffeinate`/energy settings documented.
- **R4: Server has no auth.** Mitigation: localhost bind + `tailscale serve` (tailnet only). Any tailnet device can call it; acceptable for a single-user tailnet.
- **R5: Manual summary step.** Accepted trade-off for zero API cost.

## 12. Open questions

1. **Xcode project creation:** user creates it in Xcode (“iOS App with Watch App”, name `MeetingRecorder`), or Claude generates it with XcodeGen (`brew install xcodegen`)?
2. **Git:** OK to `git init` inside this folder, separate from parent `~/Desktop/Code` repo?
3. **Tailscale:** install the Mac app + iOS app and sign in (needs the user; Claude cannot log in for you).

## 13. v3 proposal: reach the feature level of leading AI note-taker apps

Status: **Approved 2026-11-24.** Benchmark app: "Recco: AI Meeting Note Taker" (Next Pixel Ltd, App Store id6757509070, read 2026-11-24). We copy **capabilities only**: no name, branding, layout, art, or text.

### 13.1 Feature comparison

| Capability (per Recco's listing) | Ours today | v3 plan |
|---|---|---|
| Record on iPhone, iPad, Apple Watch | Watch + iPhone (built/planned) | Add iPad (same iOS target, adaptive layout) |
| Full transcription | Thai/English via OpenThai on own Mac | Same |
| Speaker labels | Off (server's speaker mode drops words) | New server endpoint: split-at-pause ASR + separate diarization pass, merged by timestamp (§13.3) |
| AI summary, decisions, action items | Claude app hand-off | Same, plus templates per recording type |
| Context-aware notes (lecture / meeting / interview) | — | Recording type picker → prompt template |
| Translate summary | Language choice in prompt | Same, any language Claude supports |
| AI chat over one or many notes | — | "ถาม AI": pick notes + question → Claude app hand-off |
| Follow-up email draft | — | Prompt template |
| Search transcript and summary | Planned (title search) | Full-text search across transcripts, summaries, own notes |
| Edit transcript and AI notes; own notes | — | Edit transcript lines, edit pasted summary, typed notes during and after recording |
| Export transcript | TXT/PDF/DOCX planned | Same, plus audio export (Recco users ask for this) |
| One-tap record from Home Screen | — | iPhone widget + Control Center control (also assignable to the iPhone 17 Pro Action button) + Live Activity while recording + Siri/Shortcuts via App Intents |
| Watch quick record + sync | Built (sync in Task 7) | Same; Watch Smart Stack widget later (decided) |
| Share via web link | — | **Not planned**: needs a cloud server; share files instead |
| Web search / "deep thinking" | — | Covered by the Claude app during hand-off |
| Import audio / documents / social links | — | Import audio files from Files → transcribe. Documents and links not planned |

### 13.2 Where we deliberately differ (selling points for personal use)
- Audio never leaves the user's own devices (Watch → iPhone → own Mac). Recco's App Store privacy label lists audio data linked to the user and used for analytics, plus tracking identifiers.
- No account, no subscription, no per-minute limits. Recco sells minute packs (e.g. Weekly Pro 300 min ฿249–299, Annual Pro ฿1,990–2,990).
- ASR model tuned for Thai (12,373 h Thai training audio).
- Trade-off: summaries and AI chat need one manual hand-off step to the Claude app.

### 13.3 Speaker labels approach (to verify in benchmark)
The bundled `mode=meeting` decodes one stream, which the model card says drops speech after pauses. Instead, a small endpoint of our own on the Mac server:
1. Transcribe with `transcribe_long` (split at pauses), which returns `segments[{start,end,text}]`.
2. Run `Diarizer.segments(audio)` (nvidia/Nemotron-3-Diarization, OpenMDW-1.1, ~downloaded once) on the whole meeting.
3. Give each ASR segment the speaker that overlaps it most. Speakers stay anonymous ("ผู้พูด 1, 2…"); the user can rename them, and renames apply to the whole meeting.
Diarization needs the whole meeting, so it runs after all chunks have arrived. A per-chunk run would renumber speakers in every chunk.

### 13.4 Proposed capability map additions

| Module id | Responsibility | Depends on |
|---|---|---|
| `speakers` | Mac endpoint for diarized transcripts + iPhone speaker rename | mac-asr-server, processing |
| `notes` | Typed notes during/after recording, transcript and summary editing | phone-library |
| `search` | Full-text search over titles, transcripts, summaries, notes | phone-library, processing |
| `ask-ai` | Recording-type templates, follow-up email, multi-note Q&A via Claude hand-off | processing |
| `quick-start` | App Intents: widget, Control Center control / Action button, Live Activity, Siri/Shortcuts | recorder |
| `import` | Import audio from Files into the pipeline | phone-library, processing |
| `ipad` | Adaptive iPad layout (split view: library + detail) | phone-library |

Build order after the current Phase E: `notes` + `search` → `ask-ai` → `speakers` → `quick-start` → `import` → `ipad`.

### 13.5 Decisions (2026-11-24, user delegated: "no extra cost, single user")
1. **AI chat engine:** Claude app hand-off (free). No API, no local LLM for now.
2. **iPad:** last in the v3 order.
3. **No paid Apple Developer Program.** No iCloud/CloudKit: the Mac app does transcription only, and the meeting library lives on iPhone. Free-team 7-day expiry is handled by automatic re-signing from the Mac (`scripts/renew-devices.sh` + launchd, see `docs/free-signing.md`). Keep App IDs ≤ 3 (iPhone, Watch, later widget).
4. **v3 module list and build order approved** as in §13.4.
