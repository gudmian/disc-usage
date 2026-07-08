public struct LargeFileEntry: Sendable, Identifiable, Equatable {
    public let path: String
    public let size: Int64
    public var id: String { path }

    public init(path: String, size: Int64) {
        self.path = path
        self.size = size
    }
}

public enum LargeFileCollector {
    public static func topFiles(
        in root: FileNode, rootPath: String, limit: Int = 100, minimumSize: Int64
    ) -> [LargeFileEntry] {
        var entries: [LargeFileEntry] = []
        collect(node: root, path: rootPath, minimumSize: minimumSize, into: &entries)
        return Array(entries.sorted { $0.size > $1.size }.prefix(limit))
    }

    private static func collect(
        node: FileNode, path: String, minimumSize: Int64, into entries: inout [LargeFileEntry]
    ) {
        for child in node.children {
            let childPath = path.hasSuffix("/") ? path + child.name : path + "/" + child.name
            switch child.kind {
            case .file where child.size >= minimumSize:
                entries.append(LargeFileEntry(path: childPath, size: child.size))
            case .directory where child.size >= minimumSize:
                collect(node: child, path: childPath, minimumSize: minimumSize, into: &entries)
            default:
                break
            }
        }
    }
}
