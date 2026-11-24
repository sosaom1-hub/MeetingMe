import Foundation
import Observation

/// Shows how long the free-team iPhone/Watch install has left and runs `scripts/renew-devices.sh` on demand.
@Observable
final class AppRenewalStatus {
    private(set) var lastInstall: Date?
    private(set) var isRenewing = false
    private(set) var lastMessage: String?

    private let stateFile = URL.applicationSupportDirectory.appending(path: "MeetingRecorderRenew/last-install")

    /// Free provisioning profiles last 7 days from install.
    var daysLeft: Int? {
        guard let lastInstall else { return nil }
        let elapsed = Calendar.current.dateComponents([.day], from: lastInstall, to: .now).day ?? 0
        return max(7 - elapsed, 0)
    }

    func refresh() {
        guard let text = try? String(contentsOf: stateFile, encoding: .utf8),
              let seconds = TimeInterval(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastInstall = nil
            return
        }
        lastInstall = Date(timeIntervalSince1970: seconds)
    }

    func renewNow(repository: URL) {
        guard !isRenewing else { return }
        isRenewing = true
        lastMessage = "กำลัง build และติดตั้งลง iPhone…"

        let process = Process()
        process.executableURL = URL(filePath: "/bin/bash")
        process.arguments = [repository.appending(path: "scripts/renew-devices.sh").path(percentEncoded: false), "--force"]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
        ]) { _, new in new }
        process.terminationHandler = { [weak self] finished in
            let code = finished.terminationStatus
            Task { @MainActor in self?.renewEnded(exitCode: code) }
        }
        do {
            try process.run()
        } catch {
            renewEnded(exitCode: -1)
        }
    }

    private func renewEnded(exitCode: Int32) {
        isRenewing = false
        refresh()
        lastMessage = switch exitCode {
        case 0: "ต่ออายุแล้ว"
        case 1: "ยังไม่ได้ตั้งค่า scripts/signing.env (ดู docs/free-signing.md)"
        case 2: "ไม่เจอ iPhone ให้ปลดล็อกและอยู่ Wi-Fi เดียวกับ Mac"
        default: "ไม่สำเร็จ ดู log ใน ~/Library/Logs/MeetingRecorderRenew"
        }
    }
}
