import Foundation

/// Values shared by the Watch and iPhone recorders (SPEC §1).
nonisolated enum RecordingDefaults {
    /// Each chunk file covers this many seconds, so a crash loses at most one chunk.
    static let chunkDuration: TimeInterval = 5 * 60
    static let sampleRate: Double = 16_000
    static let bitRate = 32_000
}
