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

## Next

Run 2: real 5-min meeting recorded on Apple Watch Ultra 4 (m4a; needs `ffmpeg` on the Mac, or convert with `afconvert` first).
