import AppKit
import SwiftUI

/// Menu-bar-only Mac app: runs the transcription server and keeps the free-team iPhone install fresh.
@main
struct MeetingRecorderServerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: ServerAppDelegate
    @State private var renewal = AppRenewalStatus()

    var body: some Scene {
        MenuBarExtra {
            ServerMenuView()
                .environment(appDelegate.server)
                .environment(renewal)
        } label: {
            Label("บันทึกประชุม", systemImage: isReady ? "waveform.circle.fill" : "waveform.circle")
        }
        .menuBarExtraStyle(.window)
    }

    private var isReady: Bool {
        if case .ready = appDelegate.server.status { true } else { false }
    }
}

/// Owns the server so it starts at launch and is stopped on every kind of quit (menu, logout, `quit app`).
final class ServerAppDelegate: NSObject, NSApplicationDelegate {
    let server = ASRServerProcess()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await server.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server.stopAndWait()
    }
}
