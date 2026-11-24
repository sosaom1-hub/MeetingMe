import Foundation

/// The iPhone recorder as the Watch remote shows it. Sent iPhone → Watch with `sendMessage` (about once a second while
/// recording and reachable) and in every reply to a `RemoteCommand`.
nonisolated struct RemoteState: Equatable {
    enum Phase: String {
        case idle, recording, paused, stopped
    }

    var phase: Phase
    var elapsed: TimeInterval
    var level: Float
    var markers: Int

    static let idle = RemoteState(phase: .idle, elapsed: 0, level: 0, markers: 0)

    var isActive: Bool { phase == .recording || phase == .paused }

    var message: [String: Any] {
        [
            TransferMessage.kind: TransferMessage.Kind.remoteState.rawValue,
            "phase": phase.rawValue,
            "elapsed": elapsed,
            "level": Double(level),
            "markers": markers,
        ]
    }

    init(phase: Phase, elapsed: TimeInterval, level: Float, markers: Int) {
        self.phase = phase
        self.elapsed = elapsed
        self.level = level
        self.markers = markers
    }

    /// Validates a payload from the other device.
    init?(message: [String: Any]) {
        guard message[TransferMessage.kind] as? String == TransferMessage.Kind.remoteState.rawValue,
              let phase = (message["phase"] as? String).flatMap(Phase.init(rawValue:)),
              let elapsed = message["elapsed"] as? Double, elapsed.isFinite, elapsed >= 0 else { return nil }
        self.phase = phase
        self.elapsed = elapsed
        self.level = Float(min(max(message["level"] as? Double ?? 0, 0), 1))
        self.markers = max(message["markers"] as? Int ?? 0, 0)
    }
}

/// Watch → iPhone `sendMessage` with a reply handler. The reply is a `RemoteState` message, or `error` (Thai text).
nonisolated enum RemoteCommand: String {
    /// Asks only for the current state.
    case status, start, stop, marker

    var message: [String: Any] {
        [TransferMessage.kind: TransferMessage.Kind.remoteCommand.rawValue, TransferMessage.command: rawValue]
    }

    init?(message: [String: Any]) {
        guard message[TransferMessage.kind] as? String == TransferMessage.Kind.remoteCommand.rawValue,
              let command = (message[TransferMessage.command] as? String).flatMap(Self.init(rawValue:)) else { return nil }
        self = command
    }
}
