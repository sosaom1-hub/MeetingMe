import AVFoundation

nonisolated enum RecordingPaths {
    /// App-controlled storage. iOS default file protection (complete until first unlock) applies,
    /// so Watch transfers can still be written while the phone is locked.
    static var root: URL {
        URL.applicationSupportDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    }

    /// Playable length of an audio file; 0 when it cannot be read (e.g. cut off mid-write).
    static func duration(of url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }
}

nonisolated enum ConsentDefaults {
    /// `@AppStorage` key on both devices. Edited on iPhone, copied to the Watch via application context.
    static let storageKey = "consentText"
    static let text = "โปรดแจ้งผู้เข้าประชุมทุกคนว่ากำลังบันทึกเสียง"
}
