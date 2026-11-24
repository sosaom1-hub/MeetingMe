import SwiftData
import SwiftUI

/// Deleting always names what will be removed and cannot happen without this confirmation.
struct DeleteConfirmation: ViewModifier {
    @Binding var meeting: Meeting?
    var onDeleted: () -> Void = {}

    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "ลบ “\(meeting?.title ?? "")”?",
            isPresented: Binding(get: { meeting != nil }, set: { if !$0 { meeting = nil } }),
            titleVisibility: .visible,
            presenting: meeting
        ) { target in
            Button("ลบถาวร", role: .destructive) {
                MeetingStore(context: context).delete(target)
                meeting = nil
                onDeleted()
            }
        } message: { target in
            Text("ไฟล์เสียง \(target.chunks?.count ?? 0) ส่วน, transcript และผลสรุปของประชุมนี้จะถูกลบออกจาก iPhone และกู้คืนไม่ได้")
        }
    }
}

extension View {
    func meetingDeleteConfirmation(for meeting: Binding<Meeting?>, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(DeleteConfirmation(meeting: meeting, onDeleted: onDeleted))
    }
}
