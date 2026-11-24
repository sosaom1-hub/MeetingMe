# OpenThai 2.0 ASR — Mac benchmark

Machine: Apple M4 Pro, 24 GB, CPU only, 1 thread (server default on macOS). Model `openthai2.0-asr-streaming_raw.nemo`, loaded in 15.6 s.

## Run 1 — 2026-11-24, synthetic smoke test

Input: 13.94 s, macOS `say -v Kanya` (Thai TTS), WAV 16 kHz mono. Clean synthetic speech, **not representative of a real meeting.**

Reference: สวัสดีครับ วันนี้เราประชุมเรื่องงบประมาณไตรมาสหน้า คุณสมชายจะส่งรายงานภายในวันศุกร์ และเราจะใช้ Microsoft Teams สำหรับการประชุมครั้งต่อไป

| lang | latency_ms | processing | speed | English words |
|---|---|---|---|---|
| th-TH | 560 | 3.48 s | 4.0× real time | ไมโครซอฟต์ทีม |
| th-TH | 1120 | 1.68 s | 8.3× real time | ไมโครซอฟต์ทีม |
| th-mix | 560 | 2.96 s | 4.7× real time | microsoft ทีม |
| th-mix | 1120 | 1.69 s | 8.3× real time | microsoft ทีม |

Thai words were all correct in every run. `display_text` has no spaces between sentences.
At 8.3×, a 3 h meeting would take about 22 min. This is an extrapolation, not a measurement.

## Run 2 — 2026-11-24, app-format m4a, chunk length

Input: 504 s (8.4 min) of macOS `say -v Kanya` Thai TTS with 1–2 s pauses, encoded exactly as the app records
(AAC, 16 kHz mono, 32 kbps, 2.0 MB). Sent through ffmpeg via `POST /v1/transcribe`, `split=auto`, `mode=standard`.
**Still synthetic speech; not representative of a real meeting.**

| lang | latency_ms | processing | speed | segments |
|---|---|---|---|---|
| th-mix | 1120 | 31.8 s | 15.9× real time | 64 (one per sentence, as expected) |
| th-mix | 560 | 35.4 s | 14.2× real time | 64 |

At 15.9×, a 5-min app chunk takes about 19 s and a 3 h meeting about 11 min.

Accuracy on one round of 4 sentences (`th-mix`, 1120 ms):

| Reference | Output |
|---|---|
| …เพิ่มงบโฆษณาออนไลน์ร้อยละสิบ | …เพิ่มงบโฆษณา online ร้อยละ 10 ✓ |
| ให้ทีม IT ย้ายระบบไป Microsoft Teams | ให้**ทีมอีก**ย้ายระบบไป microsoft **ทีม** ✗ |
| คุณวิภาจะประสานงาน… นัดประชุมครั้งถัดไป | คุณ**วิพา**จะประสานงาน… นัดประชุม**ครัง**ถัดไป ✗ |

Errors are on short English acronyms, a name's spelling, and one tone mark. All 16 repetitions gave consistent output
(6 distinct segment texts in 64).

Defaults chosen for the app: `latency_ms=1120` (fastest and most accurate for batch files), language default `th-mix`
(keeps English terms such as "online" and "microsoft" readable). The user can switch to `th-TH` in Settings.

Integration test `transcribesThaiM4AOnLocalMacServer` passes from the iPhone simulator against this server.

## Next

Run 3: a real 5-min meeting recorded on Apple Watch Ultra 4 (wrist audio, real speakers, room noise). Needed before
trusting accuracy numbers; waiting for a recording from the user.
