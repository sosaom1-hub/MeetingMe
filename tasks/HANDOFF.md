# Handoff: resuming when a session runs out of tokens

If a Claude session stops (usage limit, context full, crash), files on disk are safe. What gets lost is **who was doing what and what the next step was**. This file and the rules below keep that on disk, so any new session can continue.

## Rules for every agent working in this repo

1. **Small steps, pushed often.** One task = one commit. Build + tests pass first, then `git push origin main` right away. Never leave finished work unpushed.
2. **Claim before you start.** Add your row to the "In progress" table below (session name, task, files you own) and remove it when the task is pushed.
3. **Leave a next-step note.** Before any long step (big refactor, long test run), update your row's "Next step" in one line. If you stop, the next session reads it.
4. **Stay in your files.** Only edit the files your row lists. Ask the owner before touching theirs.
5. **Do not commit another session's half-done files.** Stage your own paths only (`git add <paths>`, never `git add -A` while others are working).
6. **Most valuable work first.** Pick tasks in the order of [todo.md](todo.md), so if tokens run out, what is left is the least important.

## In progress

| Session | Task | Files owned | Next step |
|---|---|---|---|
| app-apple-watch-ai-da | v3 Tasks 24 → 25 → 26 → 23 (iPhone intents, import audio, iPad, speakers) | Shared/Intents/, Shared/Recording/*, Shared/Model/*, MeetingRecorder/Import/, MeetingRecorder/Library/*, project.yml (device family) | Task 24: move recording intents to Shared, add iPhone App Shortcuts |
| app-apple-watch-ai-6c | Task 2 R1 device test plan (no app code) | docs/r1-watch-background.md | Plan written; user runs it on a real Ultra 4 and fills in results |
| app-apple-watch-ai-5e | iPhone "Claude บน Mac" summary button (then Batch B on hold) | Processing/SummarySheet.swift, Processing/MacASRProvider.swift, mac-server/server.py | Add askClaude to MacASRProvider + button in SummarySheet |

## How to resume in a new session

1. Open a new Claude Code session in this folder.
2. Paste:

   > Read tasks/HANDOFF.md, tasks/todo.md and SPEC.md. Run `git status` and `git log --oneline -10`. Take over the row for session `<old session name>` in HANDOFF.md: continue from its "Next step". Build and run tests before committing; push after each task.

3. The new session first checks uncommitted files:
   - It builds and the tests pass → finish the task, commit, push.
   - It does not build and the cause is unclear → `git stash push -m "wip <session> <task>"` and redo the task from its last commit. Never discard with `git checkout --` or `git reset --hard`.

## When the usage limit is hit

- **Wait for the reset**, then resume as above. Nothing is lost if rule 1 was followed.
- **Keep going on a lighter model** for mechanical work (tests, docs, small fixes): `/model` → Sonnet or Haiku. Keep design and tricky concurrency work on Opus.
- **Context full** (not the usage limit): run `/compact`, or start a new session with the resume prompt.
- **Fewer parallel sessions.** Each session uses its own tokens. When the limit is close, let one session finish while the others stop at a pushed commit.

## Build and test commands

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild test -project MeetingRecorder.xcodeproj -scheme MeetingRecorder -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/dd
xcodebuild build -project MeetingRecorder.xcodeproj -scheme "MeetingRecorder Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 4 (49mm)' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO
xcodebuild build -project MeetingRecorder.xcodeproj -scheme "MeetingRecorder Server" -destination 'platform=macOS' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO
```

All sessions share one iPhone 17 Pro simulator. Tell the others before running tests or installing apps.
