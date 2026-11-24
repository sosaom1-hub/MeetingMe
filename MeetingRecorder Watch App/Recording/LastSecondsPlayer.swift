import AVFoundation
import Observation

/// Plays the last 10 seconds of the most recent chunk, to check that the wrist microphone picked up speech.
@Observable
final class LastSecondsPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var errorMessage: String?
    private var player: AVAudioPlayer?

    func toggle() {
        isPlaying ? stop() : play()
    }

    func play() {
        errorMessage = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: ChunkedRecorder.lastChunkPreviewURL)
            player.delegate = self
            player.currentTime = max(player.duration - 10, 0)
            guard player.play() else { throw CocoaError(.fileReadUnknown) }
            self.player = player
            isPlaying = true
        } catch {
            errorMessage = "เล่นเสียงไม่ได้"
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
