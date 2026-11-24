import Foundation

/// What was recorded. Shapes the summary prompt; the headings stay the same so results stay comparable.
enum RecordingType: String, CaseIterable, Identifiable, Sendable {
    case meeting, lecture, interview, consultation

    var id: Self { self }

    var label: String {
        switch self {
        case .meeting: "ประชุม"
        case .lecture: "บรรยาย / เรียน"
        case .interview: "สัมภาษณ์"
        case .consultation: "ปรึกษา / คุยกับลูกค้า"
        }
    }

    var systemImage: String {
        switch self {
        case .meeting: "person.3"
        case .lecture: "graduationcap"
        case .interview: "mic"
        case .consultation: "bubble.left.and.bubble.right"
        }
    }

    var promptRule: String {
        switch self {
        case .meeting:
            "นี่คือการประชุม เน้นสิ่งที่ตกลงกัน งานที่ต้องทำ และประเด็นที่ยังค้าง"
        case .lecture:
            "นี่คือการบรรยายหรือการเรียน ในหัวข้อสรุปให้เน้นแนวคิดหลัก คำศัพท์สำคัญพร้อมความหมายตามที่ผู้บรรยายอธิบาย มติและงานอาจไม่มี ถ้าไม่มีให้บอกว่าไม่มี"
        case .interview:
            "นี่คือการสัมภาษณ์ ในหัวข้อสรุปให้เรียงตามคำถามหลักและคำตอบของผู้ให้สัมภาษณ์ แยกให้ชัดว่าใครพูด เฉพาะเมื่อ transcript ระบุได้"
        case .consultation:
            "นี่คือการปรึกษาหรือคุยกับลูกค้า เน้นความต้องการ ปัญหา ข้อเสนอ และสิ่งที่ต้องติดตามต่อ"
        }
    }
}
