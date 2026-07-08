import Foundation
import Observation
import ScanKit

@MainActor
@Observable
public final class LargeFilesViewModel {
    public var minimumSize: Int64 = 50 * 1024 * 1024
    public private(set) var entries: [LargeFileEntry] = []
    public var selectedPaths: Set<String> = []

    public init() {}

    public func refresh(root: FileNode?, rootPath: String) {
        guard let root else {
            entries = []
            selectedPaths = []
            return
        }
        entries = LargeFileCollector.topFiles(
            in: root, rootPath: rootPath, minimumSize: minimumSize)
        selectedPaths = selectedPaths.intersection(Set(entries.map(\.path)))
    }

    public var selectedTotalBytes: Int64 {
        entries.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.size }
    }

    public func entriesToDelete() -> [LargeFileEntry] {
        entries.filter { selectedPaths.contains($0.path) }
    }
}
