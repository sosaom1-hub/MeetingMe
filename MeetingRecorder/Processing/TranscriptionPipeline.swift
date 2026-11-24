import Foundation
import Observation

/// Sends a meeting's chunks to the transcription provider one by one.
/// Each chunk's result is saved as soon as it arrives, so a retry only sends chunks without a transcript.
@Observable
final class TranscriptionPipeline {
    private(set) var runningMeetings: Set<UUID> = []

    func isRunning(_ meeting: Meeting) -> Bool {
        runningMeetings.contains(meeting.id)
    }

    // shortcut: uses a foreground URLSession, so leaving the app mid-run fails the current chunk (retryable);
    // move to a background URLSession if long meetings are often transcribed with the app closed.
    func run(_ meeting: Meeting, provider: any TranscriptionProvider, language: TranscriptLanguage) async {
        guard !runningMeetings.contains(meeting.id) else { return }
        runningMeetings.insert(meeting.id)
        defer { runningMeetings.remove(meeting.id) }

        let chunks = meeting.sortedChunks
        guard !chunks.isEmpty else { return }

        for chunk in chunks where chunk.result == nil {
            let done = chunks.count { $0.result != nil }
            meeting.state = .transcribing(done: done, total: chunks.count)
            do {
                chunk.result = try await provider.transcribe(
                    chunk: meeting.directory.appending(path: chunk.fileName),
                    language: language
                )
                try? meeting.modelContext?.save()
            } catch TranscriptionError.serverUnreachable {
                meeting.state = .waitingForServer
                return
            } catch {
                meeting.state = .failed(step: .transcription, chunk: chunk.index, reason: error.localizedDescription, retryable: true)
                return
            }
        }
        meeting.state = .transcriptReady
        try? meeting.modelContext?.save()
    }
}
