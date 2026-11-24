import Foundation

/// Flags a recording that has heard almost nothing for a while (microphone covered by a sleeve, wrong room).
// shortcut: threshold and duration are uncalibrated until real Watch audio exists; tune with Task 2 recordings.
nonisolated struct SilenceDetector: Sendable {
    /// Normalized level from `ChunkedRecorder.level` (0…1, where 0.1 ≈ −45 dBFS).
    var threshold: Float = 0.1
    var duration: TimeInterval = 60

    private var quietSince: TimeInterval?

    /// Feed every meter tick. Returns true while the level has stayed below the threshold for `duration` seconds.
    mutating func update(level: Float, at time: TimeInterval) -> Bool {
        guard level < threshold else {
            quietSince = nil
            return false
        }
        let start = quietSince ?? time
        quietSince = start
        return time - start >= duration
    }

    mutating func reset() {
        quietSince = nil
    }
}

/// Rough "about N hours left" from storage and, once enough has drained to measure, battery.
nonisolated enum RecordingBudget {
    /// - Parameters:
    ///   - batteryAtStart / batteryNow: 0…1, nil when unknown (simulator).
    ///   - elapsed: seconds since the battery reading at start.
    /// - Returns: hours until the first of battery (down to the 10 % stop level) or storage runs out; nil if unknown.
    static func hoursLeft(batteryAtStart: Float?, batteryNow: Float?, elapsed: TimeInterval, freeBytes: Int64?) -> Double? {
        let storage = freeBytes.map { Double($0 - PreflightStatus.lowStorageBytes / 10) / PreflightStatus.bytesPerHour }

        var battery: Double?
        if let start = batteryAtStart, let now = batteryNow, elapsed >= 10 * 60 {
            let drained = Double(start - now)
            // Under 1 % drained, the rate is too noisy to trust.
            if drained >= 0.01 {
                let perHour = drained / (elapsed / 3600)
                battery = max(Double(now) - Double(ChunkedRecorder.stopBatteryLevel), 0) / perHour
            }
        }

        switch (storage, battery) {
        case let (s?, b?): return max(min(s, b), 0)
        case let (s?, nil): return max(s, 0)
        case let (nil, b?): return b
        default: return nil
        }
    }
}
