import Foundation

/// Speech-to-text backend. The app ships one implementation (`MacASRProvider`); tests use fakes.
protocol TranscriptionProvider: Sendable {
    /// Model name reported by the server, used for the connection test in Settings.
    func health() async throws -> String
    func transcribe(chunk: URL, language: TranscriptLanguage) async throws -> ChunkTranscript
}

/// Result for one 5-minute chunk. Segment times are relative to the chunk's start.
nonisolated struct ChunkTranscript: Codable, Hashable, Sendable {
    struct Segment: Codable, Hashable, Sendable {
        var start: TimeInterval
        var end: TimeInterval
        var text: String
    }

    var text: String
    var segments: [Segment]
}

nonisolated enum TranscriptLanguage: String, CaseIterable, Identifiable, Sendable {
    /// Everything in Thai script, including English words.
    case thai = "th-TH"
    /// Thai, with some English words kept in Latin script.
    case thaiMixed = "th-mix"

    var id: Self { self }

    var label: String {
        switch self {
        case .thai: "ไทย (คำอังกฤษเขียนเป็นภาษาไทย)"
        case .thaiMixed: "ไทยปนอังกฤษ (คำอังกฤษบางคำเป็นตัวอังกฤษ)"
        }
    }
}

nonisolated enum TranscriptionError: LocalizedError, Equatable {
    case invalidServerURL
    case serverUnreachable
    case server(status: Int, detail: String)
    case unreadableResponse

    var errorDescription: String? {
        switch self {
        case .invalidServerURL: "ที่อยู่เครื่อง Mac ไม่ถูกต้อง ตั้งค่าได้ที่หน้า ตั้งค่า"
        case .serverUnreachable: "ติดต่อเครื่อง Mac ไม่ได้ ตรวจว่าเปิด Mac, แอป server และ Tailscale อยู่"
        case .server(let status, let detail): "เครื่อง Mac ตอบกลับผิดพลาด (\(status)) \(detail)"
        case .unreadableResponse: "อ่านผลจากเครื่อง Mac ไม่ได้"
        }
    }
}
