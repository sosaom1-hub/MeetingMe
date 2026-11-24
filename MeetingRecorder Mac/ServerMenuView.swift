import AppKit
import ServiceManagement
import SwiftUI

struct ServerMenuView: View {
    @Environment(ASRServerProcess.self) private var server
    @Environment(AppRenewalStatus.self) private var renewal

    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            serverSection
            Divider()
            tailscaleSection
            Divider()
            renewalSection
            Divider()
            footer
        }
        .padding()
        .frame(width: 340)
        .task { renewal.refresh() }
    }

    private var serverSection: some View {
        Label {
            VStack(alignment: .leading) {
                Text("เครื่องถอดเสียง").font(.headline)
                Text(statusText)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: statusImage)
                .foregroundStyle(statusColor)
                .font(.title2)
        }
    }

    private var tailscaleSection: some View {
        VStack(alignment: .leading) {
            Text("ให้ iPhone เข้าถึงผ่าน Tailscale (ครั้งเดียว)").font(.subheadline).bold()
            HStack {
                Text(verbatim: "tailscale serve --bg \(ASRServerProcess.port)")
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                Spacer()
                Button("คัดลอก", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("tailscale serve --bg \(ASRServerProcess.port)", forType: .string)
                }
                .labelStyle(.iconOnly)
            }
            Text("server ฟังเฉพาะเครื่องนี้ (127.0.0.1) ห้ามใช้ tailscale funnel")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var renewalSection: some View {
        VStack(alignment: .leading) {
            Label(renewalText, systemImage: "iphone.and.arrow.forward")
                .foregroundStyle((renewal.daysLeft ?? 7) <= 2 ? .orange : .primary)
            HStack {
                Button("ต่ออายุเดี๋ยวนี้") { renewal.renewNow(repository: server.repository) }
                    .disabled(renewal.isRenewing)
                if renewal.isRenewing {
                    ProgressView().controlSize(.small)
                }
            }
            if let message = renewal.lastMessage {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading) {
            Toggle("เปิดเมื่อล็อกอิน", isOn: $opensAtLogin)
                .onChange(of: opensAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        opensAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let loginError {
                Text(loginError).font(.footnote).foregroundStyle(.orange)
            }
            HStack {
                if server.isRunning {
                    Button("หยุด server", action: server.stop)
                } else {
                    Button("เริ่ม server") { Task { await server.start() } }
                }
                Button("เปิด log") { NSWorkspace.shared.open(server.logURL) }
                Spacer()
                Button("ออก") {
                    server.stopAndWait()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    private var statusText: String {
        switch server.status {
        case .stopped: "หยุดอยู่"
        case .starting: "กำลังโหลดโมเดล (~20 วินาที)…"
        case .ready(let model): server.isExternal ? "พร้อม · \(model) (เปิดไว้จากที่อื่น)" : "พร้อม · \(model)"
        case .failed(let message): message
        }
    }

    private var statusImage: String {
        switch server.status {
        case .ready: "checkmark.circle.fill"
        case .starting: "hourglass.circle.fill"
        case .stopped: "pause.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch server.status {
        case .ready: .green
        case .starting: .secondary
        case .stopped: .secondary
        case .failed: .orange
        }
    }

    private var renewalText: String {
        guard let days = renewal.daysLeft else { return "ยังไม่ได้ติดตั้งแอปลง iPhone ด้วยสคริปต์" }
        return days == 0 ? "แอปบน iPhone หมดอายุแล้ว" : "แอปบน iPhone ใช้ได้อีก \(days) วัน"
    }
}
