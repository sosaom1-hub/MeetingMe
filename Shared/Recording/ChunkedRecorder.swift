import AVFoundation
import Observation

/// Records a meeting as a series of 5-minute AAC files so a crash or interruption loses at most the open chunk.
/// Used by both the Watch and the iPhone app.
@Observable
final class ChunkedRecorder {
    enum Phase: Equatable {
        case idle
        case recording
        /// Paused within the same recording. The current chunk is closed on pause, so a crash while paused loses nothing.
        case paused
        case stopped(RecordingManifest.Status)
    }

    enum RecorderError: LocalizedError {
        case couldNotStart
        case storageFull

        var errorDescription: String? {
            switch self {
            case .couldNotStart: "เริ่มบันทึกไม่ได้ ลองปิดแอปอื่นที่ใช้ไมโครโฟนแล้วลองใหม่"
            case .storageFull: "พื้นที่เก็บข้อมูลเหลือน้อยเกินไป"
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var manifest: RecordingManifest?
    private(set) var elapsed: TimeInterval = 0
    /// 0…1 input level for the meter.
    private(set) var level: Float = 0
    /// Why the last recording stopped early, in Thai, when it was not stopped by the user.
    private(set) var stopReason: String?
    /// True after about a minute of near-silence (microphone covered?).
    private(set) var isSilent = false
    /// Estimated hours of recording left (battery or storage, whichever ends first); nil until known.
    private(set) var hoursLeft: Double?

    /// Below this battery level the recorder closes the current chunk and stops, so the audio is not lost
    /// to a sudden shutdown.
    nonisolated static let stopBatteryLevel: Float = 0.10

    /// Called after each chunk file is closed, with the manifest that now lists it and the chunk index.
    var onChunkClosed: ((RecordingManifest, Int) -> Void)?
    /// Called once a recording ends (finished or interrupted) and its manifest is saved.
    var onFinish: ((RecordingManifest) -> Void)?
    /// Called when title or type is set after the recording ended, so the change reaches the iPhone library.
    var onManifestEdited: ((RecordingManifest) -> Void)?

    /// Copy of the most recently closed chunk, for "play the last 10 seconds" after stopping.
    /// The chunk itself may be deleted from the Watch as soon as the iPhone acknowledges it.
    nonisolated static var lastChunkPreviewURL: URL {
        URL.cachesDirectory.appending(path: "last-chunk-preview.m4a")
    }

    private let root: URL
    private let source: RecordingManifest.Source
    private var planner: ChunkPlanner?
    private var recorder: AVAudioRecorder?
    private var currentIndex = 0
    private var ticker: Task<Void, Never>?
    private var interruptionObserver: (any NSObjectProtocol)?
    private var silence = SilenceDetector()
    private var tickCount = 0
    private var batteryAtStart: Float?
    private var batteryStartElapsed: TimeInterval = 0

    init(source: RecordingManifest.Source, root: URL = RecordingPaths.root) {
        self.source = source
        self.root = root
    }

    // MARK: Public controls

    func start() throws {
        try ensureStorage()
        let manifest = RecordingManifest(source: source)
        let planner = ChunkPlanner(recordingID: manifest.id, root: root)
        try planner.createDirectory()
        self.manifest = manifest
        self.planner = planner
        try begin(at: 0)
    }

    /// Continues an interrupted recording as a new part of the same meeting.
    func resume() throws {
        guard var manifest, phase == .stopped(.interrupted) else { return }
        try ensureStorage()
        manifest.status = .recording
        self.manifest = manifest
        planner = ChunkPlanner(recordingID: manifest.id, root: root)
        try begin(at: (manifest.chunks.map(\.index).max() ?? -1) + 1)
    }

    func stop() {
        finish(as: .finished, reason: nil)
    }

    /// Recording or paused: a recording is in progress and must be stopped before another starts.
    var isActive: Bool {
        phase == .recording || phase == .paused
    }

    /// Pauses without ending the recording. Closes the current chunk file so it is complete on disk.
    func pause() {
        guard phase == .recording else { return }
        closeChunk()
        level = 0
        isSilent = false
        silence.reset()
        phase = .paused
    }

    /// Continues a paused recording in a new chunk of the same recording (same meeting, same timeline).
    func resumeFromPause() throws {
        guard phase == .paused else { return }
        try ensureStorage()
        try AVAudioSession.sharedInstance().setActive(true)
        try openChunk(currentIndex + 1)
        saveManifest()
        phase = .recording
    }

    func addMarker() {
        addMarker(.important)
    }

    func addMarker(_ kind: MarkerKind) {
        guard phase == .recording else { return }
        if kind == .important {
            manifest?.markers.append(elapsed)
            saveManifest()
        } else {
            addNote(kind.noteText, at: elapsed)
        }
    }

    /// All markers of every kind so far (for counts on the recording screen).
    var markerCount: Int {
        (manifest?.markers.count ?? 0) + (manifest?.notes ?? []).count { MarkerKind(noteText: $0.text) != nil }
    }

    /// Typed note at the current recording time (iPhone only; the Watch has no keyboard flow).
    func addNote(_ text: String, at time: TimeInterval) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard phase == .recording, !trimmed.isEmpty else { return }
        manifest?.notes = (manifest?.notes ?? []) + [.init(time: time, text: trimmed)]
        saveManifest()
    }

    /// Shows a recording found by `RecoveryScanner` so the user can continue or finish it.
    func adoptRecovered(_ recovered: RecordingManifest) {
        guard phase == .idle else { return }
        manifest = recovered
        planner = ChunkPlanner(recordingID: recovered.id, root: root)
        elapsed = recovered.totalDuration
        stopReason = "แอปปิดไประหว่างบันทึก"
        phase = .stopped(.interrupted)
    }

    /// Title and recording type chosen after stopping. Saved to the manifest and passed to `onManifestEdited`.
    func updateDetails(title: String?, type: RecordingType?) {
        guard case .stopped = phase, var manifest else { return }
        if let title {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            manifest.title = trimmed.isEmpty ? nil : trimmed
        }
        if let type {
            manifest.recordingType = type.rawValue
        }
        self.manifest = manifest
        saveManifest()
        onManifestEdited?(manifest)
    }

    func reset() {
        guard !isActive else { return }
        phase = .idle
        manifest = nil
        planner = nil
        elapsed = 0
        stopReason = nil
    }

    // MARK: Recording

    private static var settings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: RecordingDefaults.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: RecordingDefaults.bitRate,
        ]
    }

    private func begin(at index: Int) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        try openChunk(index)
        elapsed = manifest?.totalDuration ?? 0
        stopReason = nil
        silence.reset()
        isSilent = false
        let preflight = PreflightStatus.current()
        batteryAtStart = preflight.batteryLevel
        batteryStartElapsed = elapsed
        hoursLeft = preflight.hoursOfAudioLeft
        phase = .recording
        saveManifest()
        observeInterruptions()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    private func openChunk(_ index: Int) throws {
        guard let planner else { throw RecorderError.couldNotStart }
        let recorder = try AVAudioRecorder(url: planner.url(for: index), settings: Self.settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw RecorderError.couldNotStart }
        self.recorder = recorder
        currentIndex = index
    }

    private func closeChunk() {
        guard let recorder, let planner else { return }
        let url = planner.url(for: currentIndex)
        let liveDuration = recorder.isRecording ? recorder.currentTime : 0
        recorder.stop()
        self.recorder = nil
        // If the system already stopped the recorder, read the length back from the file.
        let duration = liveDuration > 0 ? liveDuration : RecordingPaths.duration(of: url)
        guard duration > 0 else { return }
        manifest?.chunks.append(.init(index: currentIndex, fileName: ChunkPlanner.fileName(for: currentIndex), duration: duration))
        saveManifest()
        // Before the transfer callback: the original may be deleted once the iPhone has it.
        try? FileManager.default.removeItem(at: Self.lastChunkPreviewURL)
        try? FileManager.default.copyItem(at: url, to: Self.lastChunkPreviewURL)
        if let manifest {
            onChunkClosed?(manifest, currentIndex)
        }
    }

    private func tick() {
        guard phase == .recording, let recorder else { return }
        guard recorder.isRecording else {
            finish(as: .interrupted, reason: "การบันทึกหยุดเอง (อาจเพราะพื้นที่เต็มหรือระบบหยุดไมโครโฟน)")
            return
        }
        recorder.updateMeters()
        level = max(0, min(1, (recorder.averagePower(forChannel: 0) + 50) / 50))
        elapsed = (manifest?.totalDuration ?? 0) + recorder.currentTime
        isSilent = silence.update(level: level, at: elapsed)

        tickCount += 1
        if tickCount % 120 == 0 { // every 30 s
            checkBudget()
            guard phase == .recording else { return }
        }

        if recorder.currentTime >= RecordingDefaults.chunkDuration {
            rotate()
        }
    }

    /// Updates "hours left" and stops cleanly before the battery runs out.
    private func checkBudget() {
        let status = PreflightStatus.current()
        if let battery = status.batteryLevel, battery < Self.stopBatteryLevel {
            finish(as: .interrupted, reason: "แบตเตอรี่ต่ำกว่า 10% จึงหยุดบันทึกและเก็บเสียงไว้แล้ว")
            return
        }
        hoursLeft = RecordingBudget.hoursLeft(
            batteryAtStart: batteryAtStart,
            batteryNow: status.batteryLevel,
            elapsed: elapsed - batteryStartElapsed,
            freeBytes: status.freeBytes
        )
    }

    private func rotate() {
        closeChunk()
        do {
            try ensureStorage()
            try openChunk(currentIndex + 1)
            saveManifest()
        } catch {
            finish(as: .interrupted, reason: error.localizedDescription)
        }
    }

    private func finish(as status: RecordingManifest.Status, reason: String?) {
        guard isActive else { return }
        ticker?.cancel()
        ticker = nil
        closeChunk()
        manifest?.status = status
        saveManifest()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        elapsed = manifest?.totalDuration ?? elapsed
        level = 0
        isSilent = false
        stopReason = reason
        phase = .stopped(status)
        if let manifest {
            onFinish?(manifest)
        }
    }

    private func saveManifest() {
        guard let manifest, let planner else { return }
        try? manifest.write(to: planner.directory)
    }

    private func ensureStorage() throws {
        if PreflightStatus.current().freeBytes.map({ $0 < 20_000_000 }) == true {
            throw RecorderError.storageFull
        }
    }

    /// Calls, Siri, and other apps taking the microphone. watchOS cannot restart recording in the
    /// background, so the current part ends and the user resumes it from the app.
    private func observeInterruptions() {
        guard interruptionObserver == nil else { return }
        // OS 27 replacement for the interruption notification: any system deactivation ends the part.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finish(as: .interrupted, reason: "ถูกขัดจังหวะ เช่น มีสายเข้าหรือเรียก Siri")
            }
        }
    }
}
