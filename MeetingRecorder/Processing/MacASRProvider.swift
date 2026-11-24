import Foundation

/// Calls the OpenThai server on the user's own Mac (`POST /v1/transcribe`, `GET /v1/health`).
/// Reached over Tailscale (`https://<mac>.<tailnet>.ts.net`) or, from the simulator, `http://127.0.0.1:18081`.
nonisolated struct MacASRProvider: TranscriptionProvider {
    /// Batch decoding favours accuracy over latency (SPEC §4); 1120 ms was also fastest in mac-server/BENCHMARK.md.
    static let latencyMs = 1120

    let baseURL: URL
    let session: URLSession

    /// Validates user input at the trust boundary: only http(s) URLs with a host.
    init?(string: String, session: URLSession = .shared) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host() != nil else { return nil }
        baseURL = url
        self.session = session
    }

    func health() async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "v1/health"))
        request.timeoutInterval = 5
        let data = try await send(request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranscriptionError.unreadableResponse
        }
        return json["model"] as? String ?? "ready"
    }

    func transcribe(chunk: URL, language: TranscriptLanguage) async throws -> ChunkTranscript {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("lang", language.rawValue)
        field("latency_ms", String(Self.latencyMs))
        field("mode", "standard")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(chunk.lastPathComponent)\"\r\nContent-Type: audio/mp4\r\n\r\n".utf8))
        body.append(try Data(contentsOf: chunk))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: baseURL.appending(path: "v1/transcribe"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // A 5-minute chunk takes well under a minute on an M4 Pro; leave room for a busy Mac.
        request.timeoutInterval = 600
        request.httpBody = body

        return try Self.parse(try await send(request))
    }

    /// Server response → transcript. Files of 30 s or less come back without `segments`.
    static func parse(_ data: Data) throws -> ChunkTranscript {
        struct Response: Decodable {
            struct Segment: Decodable {
                let start: Double
                let end: Double
                let text: String
            }
            let displayText: String
            let durationS: Double
            let segments: [Segment]?
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(Response.self, from: data) else {
            throw TranscriptionError.unreadableResponse
        }
        let segments = response.segments?
            .filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ChunkTranscript.Segment(start: $0.start, end: $0.end, text: $0.text) }
            ?? (response.displayText.isEmpty ? [] : [.init(start: 0, end: response.durationS, text: response.displayText)])
        return ChunkTranscript(text: response.displayText, segments: segments)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.unreachableCodes.contains(error.code) {
            throw TranscriptionError.serverUnreachable
        }
        guard let http = response as? HTTPURLResponse else { throw TranscriptionError.unreadableResponse }
        guard http.statusCode == 200 else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? ""
            throw TranscriptionError.server(status: http.statusCode, detail: detail)
        }
        return data
    }

    private static let unreachableCodes: Set<URLError.Code> = [
        .cannotConnectToHost, .cannotFindHost, .timedOut, .notConnectedToInternet,
        .networkConnectionLost, .dnsLookupFailed, .secureConnectionFailed,
    ]
}
