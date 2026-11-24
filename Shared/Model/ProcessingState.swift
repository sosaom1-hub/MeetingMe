import Foundation

/// Where a meeting is in the pipeline (SPEC §4). Persisted, and shown on both Watch and iPhone.
nonisolated enum ProcessingState: Codable, Hashable, Sendable {
    case recording
    case savedOnWatch
    case waitingToTransfer
    case transferring(sent: Int, total: Int)
    case onPhone
    case awaitingSelection
    case waitingForServer
    case transcribing(done: Int, total: Int)
    case transcriptReady
    case awaitingSummaryPaste
    case summaryReady
    case exportReady
    /// Recording stopped unexpectedly. Audio captured before the stop is kept.
    case interrupted
    case failed(step: ProcessingStep, chunk: Int?, reason: String, retryable: Bool)
}

nonisolated enum ProcessingStep: String, Codable, Hashable, Sendable {
    case recording, transfer, transcription, summary, export
}
