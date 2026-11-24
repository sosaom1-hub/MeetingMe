import AppIntents

/// Opens the app (Watch or iPhone) and starts recording through the normal on-screen flow (consent reminder, microphone permission).
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "เริ่มบันทึกประชุม"
    static let description = IntentDescription("เปิดแอปแล้วเริ่มบันทึก ข้อความเตือนก่อนบันทึกยังแสดงตามการตั้งค่า")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !AppServices.recorder.isActive else {
            return .result(dialog: "กำลังบันทึกอยู่แล้ว")
        }
        AppServices.requests.startRequestedAt = .now
        return .result(dialog: "กำลังเริ่มบันทึก")
    }
}

/// Stops the current recording. Works while the app is recording in the background.
struct StopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "หยุดบันทึกประชุม"
    static let description = IntentDescription("หยุดการบันทึกที่กำลังทำอยู่ เสียงที่บันทึกแล้วถูกเก็บไว้ทั้งหมด")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recorder = AppServices.recorder
        guard recorder.isActive else {
            return .result(dialog: "ตอนนี้ไม่ได้บันทึกอยู่")
        }
        recorder.stop()
        let duration = Duration.seconds(recorder.manifest?.totalDuration ?? 0).formatted(.units(allowed: [.hours, .minutes], width: .wide))
        return .result(dialog: "หยุดแล้ว เก็บเสียงไว้ \(duration)")
    }
}

/// Adds a marker (important / action item / decision / question) at the current recording time.
struct AddMarkerIntent: AppIntent {
    static let title: LocalizedStringResource = "ทำเครื่องหมายในการบันทึก"
    static let description = IntentDescription("ทำเครื่องหมาย ณ เวลานี้ของการบันทึกที่กำลังทำอยู่")

    @Parameter(title: "ประเภท", default: .important)
    var kind: MarkerKindOption

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let recorder = AppServices.recorder
        guard recorder.phase == .recording else {
            return .result(dialog: "ตอนนี้ไม่ได้บันทึกอยู่")
        }
        recorder.addMarker(kind.markerKind)
        return .result(dialog: "ทำเครื่องหมาย\(kind.markerKind.label)แล้ว")
    }
}

enum MarkerKindOption: String, AppEnum {
    case important, actionItem, decision, question

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "ประเภทเครื่องหมาย"
    static let caseDisplayRepresentations: [MarkerKindOption: DisplayRepresentation] = [
        .important: "จุดสำคัญ",
        .actionItem: "งานที่ต้องทำ",
        .decision: "มติ",
        .question: "คำถาม",
    ]

    var markerKind: MarkerKind {
        switch self {
        case .important: .important
        case .actionItem: .actionItem
        case .decision: .decision
        case .question: .question
        }
    }
}

/// Siri phrases and Shortcuts actions on Watch and iPhone. The iPhone 17 Pro Action button can run them directly;
/// on the Ultra, assign a Shortcut that runs "เริ่มบันทึกประชุม".
struct RecordingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: ["เริ่มบันทึกประชุมด้วย \(.applicationName)", "Start recording with \(.applicationName)"],
            shortTitle: "เริ่มบันทึก",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: ["หยุดบันทึกประชุมด้วย \(.applicationName)", "Stop recording with \(.applicationName)"],
            shortTitle: "หยุดบันทึก",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: AddMarkerIntent(),
            phrases: ["ทำเครื่องหมายด้วย \(.applicationName)", "Mark this in \(.applicationName)"],
            shortTitle: "ทำเครื่องหมาย",
            systemImageName: "bookmark.fill"
        )
    }
}
