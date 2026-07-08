import ScanKit
import SwiftUI

public enum ContentCategory: Sendable, Equatable {
    case media, code, archive, document, caches, directory, other
}

public enum NodeColor {
    private static let mediaExtensions: Set<String> = [
        "mp4", "mov", "mkv", "avi", "jpg", "jpeg", "png", "heic", "gif", "mp3",
        "wav", "aac", "flac", "raw", "tiff", "webp", "webm",
    ]
    private static let codeExtensions: Set<String> = [
        "swift", "kt", "java", "ts", "tsx", "js", "py", "go", "rs", "c", "cpp",
        "h", "m", "rb", "sh", "json", "yaml", "yml", "xml", "html", "css",
    ]
    private static let archiveExtensions: Set<String> = [
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "iso", "xip", "pkg", "jar",
    ]
    private static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "pages",
        "numbers", "key", "rtf", "csv",
    ]
    private static let cacheDirectoryNames: Set<String> = [
        "caches", "cache", "deriveddata", "tmp", "temp", ".trash", "logs",
    ]

    public static func category(for node: FileNode) -> ContentCategory {
        if node.kind != .file {
            return cacheDirectoryNames.contains(node.name.lowercased()) ? .caches : .directory
        }
        let ext = (node.name as NSString).pathExtension.lowercased()
        if mediaExtensions.contains(ext) { return .media }
        if codeExtensions.contains(ext) { return .code }
        if archiveExtensions.contains(ext) { return .archive }
        if documentExtensions.contains(ext) { return .document }
        return .other
    }

    public static func color(for category: ContentCategory) -> Color {
        switch category {
        case .media: .purple
        case .code: .teal
        case .archive: .orange
        case .document: .blue
        case .caches: .brown
        case .directory: .indigo
        case .other: .gray
        }
    }
}
