import Foundation

public struct ScanResult: Sendable {
    public let root: FileNode
    public let inaccessiblePaths: [String]

    public init(root: FileNode, inaccessiblePaths: [String]) {
        self.root = root
        self.inaccessiblePaths = inaccessiblePaths
    }
}

public struct DiskScanner: Sendable {
    private let progressInterval: Int

    public init(progressInterval: Int = 2048) {
        self.progressInterval = progressInterval
    }

    public func scan(
        configuration: ScanConfiguration,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async throws -> ScanResult {
        let context = ScanContext(onProgress: onProgress, progressInterval: progressInterval)
        _ = context.visitedDirectories.markVisited(configuration.rootURL)
        let root = try await scanDirectory(
            configuration.rootURL, configuration: configuration, context: context)
        context.emitFinal(path: configuration.rootURL.path)
        return ScanResult(root: root, inaccessiblePaths: context.inaccessiblePaths)
    }

    /// Пересканирует поддиректорию и возвращает новое дерево с заменённым
    /// поддеревом. После удаления элемента с диска вызывайте для его РОДИТЕЛЯ.
    public func rescanSubtree(
        at relativePath: [String],
        in result: ScanResult,
        configuration: ScanConfiguration
    ) async throws -> ScanResult {
        let url = relativePath.reduce(configuration.rootURL) {
            $0.appendingPathComponent($1)
        }
        let subConfiguration = ScanConfiguration(
            rootURL: url, excludedPaths: configuration.excludedPaths)
        let subResult = try await scan(configuration: subConfiguration)
        guard let newRoot = TreeRebuilder.replacing(
            nodeAt: relativePath, with: subResult.root, in: result.root)
        else { return result }
        return ScanResult(root: newRoot, inaccessiblePaths: result.inaccessiblePaths)
    }

    private func scanDirectory(
        _ url: URL, configuration: ScanConfiguration, context: ScanContext
    ) async throws -> FileNode {
        try Task.checkCancellation()
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isSymbolicLinkKey, .isVolumeKey, .totalFileAllocatedSizeKey,
        ]
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: keys, options: [])
        } catch {
            context.recordInaccessible(url.path)
            return FileNode(inaccessibleDirectoryNamed: url.lastPathComponent)
        }

        var files: [FileNode] = []
        var subdirectories: [URL] = []
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                files.append(FileNode(fileNamed: entry.lastPathComponent, size: 0))
            } else if values.isDirectory == true {
                // Корень чужого тома (симулятор, cryptex, внешний диск) не входит
                // в счёт; реестр отсекает повторный обход алиасов (/.nofollow).
                if values.isVolume != true, !configuration.isExcluded(entry),
                    context.visitedDirectories.markVisited(entry) {
                    subdirectories.append(entry)
                }
            } else {
                let reported = Int64(values.totalFileAllocatedSize ?? 0)
                let size = context.hardLinks.countableSize(of: entry, reportedSize: reported)
                files.append(FileNode(fileNamed: entry.lastPathComponent, size: size))
                context.addFile(bytes: size, path: entry.path)
            }
        }

        var directories: [FileNode] = []
        directories.reserveCapacity(subdirectories.count)
        try await withThrowingTaskGroup(of: FileNode.self) { group in
            for subdirectory in subdirectories {
                group.addTask {
                    try await scanDirectory(subdirectory, configuration: configuration, context: context)
                }
            }
            for try await node in group { directories.append(node) }
        }
        return FileNode(directoryNamed: url.lastPathComponent, children: files + directories)
    }
}
