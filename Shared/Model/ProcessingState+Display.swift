import Foundation

nonisolated extension ProcessingState {
    /// Short Thai status shown in lists and on the Watch.
    var label: String {
        switch self {
        case .recording: "กำลังบันทึก"
        case .savedOnWatch: "อยู่บนนาฬิกา"
        case .waitingToTransfer: "รอส่งไป iPhone"
        case .transferring(let sent, let total): "กำลังส่ง \(sent)/\(total)"
        case .onPhone: "อยู่บน iPhone"
        case .awaitingSelection: "พร้อมถอดเสียง"
        case .waitingForServer: "รอเครื่อง Mac"
        case .transcribing(let done, let total): "กำลังถอดเสียง \(done)/\(total)"
        case .transcriptReady: "ถอดเสียงแล้ว"
        case .awaitingSummaryPaste: "รอวางผลสรุป"
        case .summaryReady: "สรุปแล้ว"
        case .exportReady: "พร้อม export"
        case .interrupted: "หยุดกลางคัน · เก็บเสียงไว้แล้ว"
        case .failed: "ล้มเหลว · ลองใหม่ได้"
        }
    }

    var systemImage: String {
        switch self {
        case .recording: "record.circle"
        case .savedOnWatch, .waitingToTransfer: "applewatch"
        case .transferring: "arrow.up.forward.circle"
        case .onPhone, .awaitingSelection: "iphone"
        case .waitingForServer: "desktopcomputer"
        case .transcribing: "waveform.badge.magnifyingglass"
        case .transcriptReady: "text.quote"
        case .awaitingSummaryPaste: "doc.on.clipboard"
        case .summaryReady, .exportReady: "checkmark.seal"
        case .interrupted: "exclamationmark.triangle"
        case .failed: "exclamationmark.octagon"
        }
    }

    /// States the user should look at.
    var needsAttention: Bool {
        switch self {
        case .interrupted, .failed: true
        default: false
        }
    }
}
