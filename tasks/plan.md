# Implementation Plan: Meeting Recorder

Status: **DRAFT — awaiting approval.** Based on [SPEC.md](../SPEC.md) v2. Task checklist: [todo.md](todo.md).

## Overview

Native SwiftUI apps for watchOS 27 and iOS 27. Watch or iPhone records chunked audio. iPhone stores meetings, sends chunks to the user's Mac (OpenThai 2.0 ASR over Tailscale), shows transcripts, hands a summary prompt to the Claude app, takes the pasted answer back, and exports TXT/PDF/DOCX.

## Architecture decisions

- **XcodeGen** generates `MeetingRecorder.xcodeproj` from `project.yml`. The `.xcodeproj` is git-ignored.
- **Targets:** `MeetingRecorder` (iOS), `MeetingRecorder Watch App` (watchOS, embedded), `MeetingRecorderTests` (Swift Testing, iOS). `Shared/` sources compile into both apps. No Swift package yet; add one only if target membership becomes painful.
- **Recording engine in `Shared/`** (`ChunkedRecorder`), used by Watch and iPhone. Pure file logic (rotation, manifest, recovery scan) is separated from `AVAudioRecorder`, so tests run without a microphone.
- **Persistence:** SwiftData on iPhone only. Watch keeps a small JSON index of unsent chunks. The `MeetingStore` protocol is the seam for later iCloud work.
- **Transport:** `WCSession.transferFile` for chunks, `transferUserInfo` for status. Status messages stay small and idempotent.
- **Transcription:** `MacASRProvider` calls `POST /v1/transcribe` once per chunk.
- **Summary:** prompt builder + share sheet to the Claude app + paste-back. No network code for summaries.
- **Watch backgrounding (R1):** recording starts only in the foreground. Info.plist gets the `audio` background mode under `UIBackgroundModes`; on device, test whether the `WKBackgroundModes` key is also needed. Apple forum reports say recording **cannot restart in background after an interruption**, so an interruption ends the current part. The Watch then gives a haptic and shows “แตะเพื่อบันทึกต่อ” the next time the app is on screen.

## Watch UX design

Goal: understood in one glance (~2 s), operated with one tap, never ambiguous about “am I recording?”.

### Borrowed patterns (behaviour only, no branding or visuals copied)

| Pattern | Seen in | Use here |
|---|---|---|
| One huge red record button as the whole home screen | Voice Memos, Just Press Record | Home screen |
| Huge monospaced elapsed time as the main element | Workout app | Recording screen |
| Live level meter / waveform | Voice Memos | Proves the mic is hearing speech; shows when people are too far away |
| Vertical pages turned with the Digital Crown | watchOS 10+ system apps | Record page → recent recordings page |
| Status icons on each item (on device / sending / done) | Mail outbox, Photos sync | Recent recordings list |
| Highlight button during recording | Otter, Just Press Record (bookmark) | **Optional:** “⭐ จุดสำคัญ” marker saved as a timestamp and shown in the transcript |
| Double tap to do the primary action | watchOS system apps | Stop (or marker) by pinching, if the SDK allows it for this control. Verify `handGestureShortcut(.primaryAction)` |

### Screens

**1. Home (not recording)**
```
┌─────────────────────┐
│  บันทึกประชุม        │
│                     │
│       ( ● )         │  ← red button, ~110 pt
│     เริ่มบันทึก        │
│                     │
│ 🔋 82% · พื้นที่ ~9 ชม. │  ← pre-flight line; turns orange when low
└─────────────────────┘
```
- First tap shows the consent reminder sheet (text from iPhone settings) with “เริ่มเลย” / “ยกเลิก”, plus an option to hide it for 24 h.
- First-ever launch also shows the one-time wrist-mic notice: “นาฬิกาอยู่บนข้อมือ เสียงคนที่นั่งไกลอาจเบา”.

**2. Recording**
```
┌─────────────────────┐
│ ● กำลังบันทึก         │  ← red dot (pulses only if Reduce Motion is off)
│                     │
│     1:02:37         │  ← largest text, monospaced digits
│  ▁▃▅▇▅▃▁▂▅▇▆▃       │  ← level meter
│                     │
│ [ ⭐ ]   [ ■ หยุด  ]  │  ← stop is wide and red; marker is optional
└─────────────────────┘
```
- Haptic on start, on stop, and when an interruption ends a part.
- Always-On / wrist down: show only the red dot and minutes (`isLuminanceReduced`), with no per-second updates.
- Warnings slide in as one line: “แบตต่ำ 15%”, “พื้นที่ใกล้เต็ม”, “ไม่ได้ยินเสียงมา 5 นาที”.

**3. After stop (3 s summary, then back to Home)**
```
✓ บันทึกแล้ว 1:02:37
13 ส่วน · กำลังส่งไป iPhone
```

**4. Recent recordings (Digital Crown down)**
- The 5 latest, each one line: title/time, duration, status icon + word:
  `⌚ บนนาฬิกา` · `↗ กำลังส่ง 4/13` · `📱 อยู่บน iPhone` · `📝 ถอดเสียงแล้ว` · `⚠ ล้มเหลว – แตะเพื่อลองใหม่`
- Never shows transcript text.

**5. Interrupted**
- “การบันทึกหยุดเพราะมีสายเข้า · เก็บเสียงไว้แล้ว 42:10” with buttons “บันทึกต่อ (ส่วนใหม่)” and “จบ”.

**Optional later:** a Smart Stack widget / complication showing “● 0:42” while recording, or the last recording's status. It needs a WidgetKit target, so ask first.

### Ultra 4 specifics to verify on device (not assumed)
- Whether a third-party app can be assigned to the Action button. As far as I know it is limited to workout/dive intents, so the plan doesn't rely on it.
- Level-meter readings in a real meeting room, to set the “too quiet” threshold.

## iPhone UX (brief)

- Library styled like Voice Memos and Notes: a plain list with large titles, status chips, swipe to delete (with confirmation).
- Detail: Otter-style transcript with timestamps. Tap a line to seek playback. Result cards below the transcript.
- Same recording screen as the Watch, scaled up.

## Phases (detail in todo.md)

| Phase | Goal | Tasks |
|---|---|---|
| A. Foundation + risk | Project builds; R1 answered on a real Ultra 4 | 1–3 |
| B. Recording | Reliable recording on Watch and iPhone | 4–6 |
| C. Transfer + library | Watch recording appears on iPhone and survives relaunch | 7–9 |
| D. Transcription | Mac transcribes chunks; transcript shown | 10–13 |
| E. Summary + export | Claude hand-off, paste-back, TXT/DOCX/PDF | 14–17 |
| F. Polish | Settings, accessibility, Thai localization | 18–19 |

Phases D and E (Mac-side work, exporters) could run in parallel with B and C. They are kept sequential because one agent works at a time.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| R1 Watch stops recording when wrist is down | High | Task 2 spike on real device first. Fallback: record on iPhone. Never a workout session |
| Interruption cannot resume in background | Med | Treat as a new part; haptic + resume prompt; tested in Task 5 |
| ASR accuracy on wrist audio | High | Task 13 benchmark with real audio before UI polish |
| Mac asleep/off | Med | `waitingForServer` state + retry; launchd keeps the server alive |
| XcodeGen config drift | Low | `project.yml` is the single source; regenerate in every build command |
| No physical device during development | Med | Tasks that need a device are marked; simulator covers UI and logic only |

## Open questions

1. Include the **⭐ marker** during recording? (Small: a timestamp list in the manifest plus one button.)
2. **Smart Stack widget/complication**: in MVP or later?
3. **Bundle ID prefix** and **Apple Developer Team ID** for signing on real devices (e.g. `com.<you>.meetingrecorder`). A free personal team works for device testing, but its apps expire after 7 days.
