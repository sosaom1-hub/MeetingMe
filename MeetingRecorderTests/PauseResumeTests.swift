import AVFoundation
import Foundation
import Testing
@testable import MeetingRecorder

/// Records for real (simulator uses the Mac microphone). Runs only when microphone access was granted, e.g.
/// `xcrun simctl privacy "iPhone 17 Pro" grant microphone com.sosaom1.meetingrecorder`.
@Suite(.serialized, .enabled(if: AVAudioApplication.shared.recordPermission == .granted))
struct PauseResumeTests {
    @Test func pauseClosesTheChunkAndResumeContinuesTheSameRecording() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "PauseResumeTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = ChunkedRecorder(source: .phone, root: root)

        try recorder.start()
        try await Task.sleep(for: .seconds(1.5))
        recorder.pause()

        #expect(recorder.phase == .paused)
        let paused = try #require(recorder.manifest)
        #expect(paused.chunks.map(\.index) == [0])
        // The paused chunk is a complete, readable file: a crash now would lose nothing.
        let directory = ChunkPlanner(recordingID: paused.id, root: root).directory
        #expect(RecordingPaths.duration(of: directory.appending(path: "chunk-000.m4a")) > 1)
        #expect(try RecordingManifest.read(from: directory).status == .recording)

        try recorder.resumeFromPause()
        #expect(recorder.phase == .recording)
        try await Task.sleep(for: .seconds(1.5))
        recorder.stop()

        let finished = try #require(recorder.manifest)
        #expect(recorder.phase == .stopped(.finished))
        #expect(finished.id == paused.id)
        #expect(finished.chunks.map(\.index) == [0, 1])
        #expect(try RecordingManifest.read(from: directory).status == .finished)
    }

    @Test func stopWhilePausedFinishesCleanly() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "PauseResumeTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = ChunkedRecorder(source: .phone, root: root)

        try recorder.start()
        try await Task.sleep(for: .seconds(1.2))
        recorder.pause()
        recorder.stop()

        #expect(recorder.phase == .stopped(.finished))
        #expect(recorder.manifest?.chunks.count == 1)
        #expect(!recorder.isActive)
    }
}
