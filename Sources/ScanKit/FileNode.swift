import Foundation

/// Узел дерева размеров. Иммутабелен после создания.
public final class FileNode: Sendable, Identifiable, Equatable {
    public enum Kind: Sendable, Equatable {
        case file
        case directory
        case inaccessibleDirectory
    }

    public let name: String
    public let kind: Kind
    /// Аллоцированные байты; для директорий — сумма детей.
    public let size: Int64
    /// Отсортированы по размеру по убыванию; пусто для файлов.
    public let children: [FileNode]

    public init(fileNamed name: String, size: Int64) {
        self.name = name
        self.kind = .file
        self.size = size
        self.children = []
    }

    public init(inaccessibleDirectoryNamed name: String) {
        self.name = name
        self.kind = .inaccessibleDirectory
        self.size = 0
        self.children = []
    }

    public init(directoryNamed name: String, children: [FileNode]) {
        self.name = name
        self.kind = .directory
        self.children = children.sorted { $0.size > $1.size }
        self.size = children.reduce(0) { $0 + $1.size }
    }

    public func child(named name: String) -> FileNode? {
        children.first { $0.name == name }
    }

    public static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs === rhs }
}
