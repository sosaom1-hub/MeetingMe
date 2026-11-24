import Foundation
import Observation

/// Runs the OpenThai ASR server (Python/uvicorn in `mac-server/`) as a child process on 127.0.0.1 only,
/// restarts it after a crash, and reports health. The server has no authentication, so it must never
/// listen on another interface; `tailscale serve` exposes it to the user's own tailnet.
@Observable
final class ASRServerProcess {
    enum Status: Equatable {
        case stopped
        case starting
        case ready(model: String)
        case failed(String)
    }

    static let port = 18081
    private static let maxRestarts = 5

    private(set) var status = Status.stopped
    /// True when a server was already running before this app started (for example from Terminal).
    private(set) var isExternal = false

    let repository: URL
    private var process: Process?
    private var isStopping = false
    private var restartCount = 0
    private var healthTask: Task<Void, Never>?

    init() {
        let builtIn = Bundle.main.object(forInfoDictionaryKey: "MRRepositoryPath") as? String ?? ""
        repository = URL(filePath: UserDefaults.standard.string(forKey: "repositoryPath") ?? builtIn, directoryHint: .isDirectory)
    }

    var serverDirectory: URL { repository.appending(path: "mac-server", directoryHint: .isDirectory) }
    var logURL: URL { URL.libraryDirectory.appending(path: "Logs/MeetingRecorderServer/server.log") }
    var isRunning: Bool { process != nil || isExternal }

    func start() async {
        guard process == nil else { return }
        isStopping = false
        if let model = await health() {
            isExternal = true
            status = .ready(model: model)
            startHealthLoop()
            return
        }

        let python = serverDirectory.appending(path: ".venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: python.path(percentEncoded: false)) else {
            status = .failed("ไม่พบ Python ใน mac-server/.venv ให้รัน mac-server/setup.sh ก่อน")
            return
        }

        let logDirectory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path(percentEncoded: false), contents: nil)
        let log = try? FileHandle(forWritingTo: logURL)

        let process = Process()
        process.executableURL = python
        // server.py (ours, in git) wraps iApp's downloaded app.py and adds /v1/claude.
        process.arguments = ["-m", "uvicorn", "server:app", "--app-dir", "../..", "--host", "127.0.0.1", "--port", String(Self.port)]
        process.currentDirectoryURL = serverDirectory.appending(path: "model/serve", directoryHint: .isDirectory)
        process.environment = ProcessInfo.processInfo.environment.merging([
            "CHINDA_PRELOAD": "1",
            // ffmpeg (Homebrew) decodes the m4a chunks from the Watch and iPhone.
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
        ]) { _, new in new }
        process.standardOutput = log
        process.standardError = log
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.processEnded() }
        }

        do {
            try process.run()
            self.process = process
            isExternal = false
            status = .starting
            startHealthLoop()
        } catch {
            status = .failed("เปิด server ไม่ได้: \(error.localizedDescription)")
        }
    }

    func stop() {
        isStopping = true
        healthTask?.cancel()
        healthTask = nil
        process?.terminate()
        if isExternal {
            isExternal = false
            status = .stopped
        }
    }

    /// For app quit: give uvicorn a moment to exit so the port is free next launch.
    func stopAndWait() {
        let running = process
        stop()
        running?.waitUntilExit()
    }

    private func processEnded() {
        process = nil
        guard !isStopping else {
            status = .stopped
            return
        }
        restartCount += 1
        guard restartCount <= Self.maxRestarts else {
            healthTask?.cancel()
            status = .failed("server หยุดทำงานซ้ำ \(Self.maxRestarts) ครั้ง ดู log")
            return
        }
        status = .starting
        Task {
            try? await Task.sleep(for: .seconds(3))
            await start()
        }
    }

    private func startHealthLoop() {
        healthTask?.cancel()
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let model = await self.health() {
                    self.status = .ready(model: model)
                    self.restartCount = 0
                } else if self.isExternal {
                    self.isExternal = false
                    self.status = .failed("server ที่เปิดไว้ก่อนหน้าหยุดตอบ กด “เริ่ม” เพื่อเปิดใหม่")
                    return
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func health() async -> String? {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(Self.port)/v1/health")!)
        request.timeoutInterval = 2
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["model"] as? String ?? "ready"
    }
}
