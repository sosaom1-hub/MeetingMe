import AVFoundation
import Observation

/// Plays a meeting's chunk files as one continuous timeline, so seeking works across chunks.
@Observable
final class ChunkPlayer {
    private(set) var duration: TimeInterval = 0
    private(set) var currentTime: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var errorMessage: String?

    var isReady: Bool { duration > 0 }

    private let player = AVPlayer()
    private var timeObserver: Any?

    func load(_ urls: [URL]) async {
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
        var cursor = CMTime.zero
        do {
            for url in urls {
                guard let source = try await AVURLAsset(url: url).loadTracks(withMediaType: .audio).first else { continue }
                let range = try await source.load(.timeRange)
                try track.insertTimeRange(range, of: source, at: cursor)
                cursor = cursor + range.duration
            }
        } catch {
            errorMessage = "เล่นเสียงบางส่วนไม่ได้"
        }
        player.replaceCurrentItem(with: AVPlayerItem(asset: composition))
        duration = cursor.seconds
        observeTime()
    }

    func togglePlay() {
        if isPlaying {
            player.pause()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try? AVAudioSession.sharedInstance().setActive(true)
            if currentTime >= duration - 0.5 {
                seek(to: 0)
            }
            player.play()
        }
        isPlaying.toggle()
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: TimeInterval) {
        let target = min(max(seconds, 0), duration)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    private func observeTime() {
        guard timeObserver == nil else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                self.isPlaying = self.player.timeControlStatus != .paused
            }
        }
    }
}
