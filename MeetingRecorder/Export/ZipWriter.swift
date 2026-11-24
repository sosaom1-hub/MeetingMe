import Foundation

/// Minimal ZIP writer (stored, no compression) — enough for a valid .docx package without a dependency.
enum ZipWriter {
    struct Entry {
        let path: String
        let data: Data
    }

    static func archive(_ entries: [Entry]) -> Data {
        var output = Data()
        var central = Data()

        for entry in entries {
            let name = Data(entry.path.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(output.count)

            // Local file header
            output.append(le32(0x0403_4B50))
            output.append(le16(20))          // version needed
            output.append(le16(0x0800))      // flags: UTF-8 names
            output.append(le16(0))           // method: stored
            output.append(le16(0))           // mod time
            output.append(le16(0x5B21))      // mod date: 2025-09-01 (fixed, reproducible output)
            output.append(le32(crc))
            output.append(le32(size))
            output.append(le32(size))
            output.append(le16(UInt16(name.count)))
            output.append(le16(0))
            output.append(name)
            output.append(entry.data)

            // Central directory entry
            central.append(le32(0x0201_4B50))
            central.append(le16(20))         // version made by
            central.append(le16(20))
            central.append(le16(0x0800))
            central.append(le16(0))
            central.append(le16(0))
            central.append(le16(0x5B21))
            central.append(le32(crc))
            central.append(le32(size))
            central.append(le32(size))
            central.append(le16(UInt16(name.count)))
            central.append(le16(0))          // extra
            central.append(le16(0))          // comment
            central.append(le16(0))          // disk
            central.append(le16(0))          // internal attrs
            central.append(le32(0))          // external attrs
            central.append(le32(offset))
            central.append(name)
        }

        let centralOffset = UInt32(output.count)
        output.append(central)
        output.append(le32(0x0605_4B50))     // end of central directory
        output.append(le16(0))
        output.append(le16(0))
        output.append(le16(UInt16(entries.count)))
        output.append(le16(UInt16(entries.count)))
        output.append(le32(UInt32(central.count)))
        output.append(le32(centralOffset))
        output.append(le16(0))
        return output
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    private static func le16(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    private static func le32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
}
