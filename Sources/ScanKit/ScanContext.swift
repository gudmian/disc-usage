import Foundation

/// Потокобезопасные счётчики скана: прогресс + недоступные пути.
final class ScanContext: @unchecked Sendable {
    let hardLinks = HardLinkRegistry()
    let visitedDirectories = VisitedDirectoryRegistry()

    private let lock = NSLock()
    private var items = 0
    private var bytes: Int64 = 0
    private var inaccessible: [String] = []
    private let onProgress: (@Sendable (ScanProgress) -> Void)?
    private let progressInterval: Int

    init(onProgress: (@Sendable (ScanProgress) -> Void)?, progressInterval: Int) {
        self.onProgress = onProgress
        self.progressInterval = max(1, progressInterval)
    }

    func addFile(bytes fileBytes: Int64, path: String) {
        lock.lock()
        items += 1
        bytes += fileBytes
        let snapshot = items % progressInterval == 0
            ? ScanProgress(scannedItems: items, totalBytes: bytes, currentPath: path) : nil
        lock.unlock()
        if let snapshot { onProgress?(snapshot) }
    }

    func recordInaccessible(_ path: String) {
        lock.lock()
        inaccessible.append(path)
        lock.unlock()
    }

    func emitFinal(path: String) {
        lock.lock()
        let snapshot = ScanProgress(scannedItems: items, totalBytes: bytes, currentPath: path)
        lock.unlock()
        onProgress?(snapshot)
    }

    var inaccessiblePaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return inaccessible
    }
}
