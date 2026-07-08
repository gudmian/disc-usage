import Foundation

public enum ByteFormatter {
    public static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false  // «0 байт», а не «Zero KB»
        return formatter.string(fromByteCount: bytes)
    }
}
