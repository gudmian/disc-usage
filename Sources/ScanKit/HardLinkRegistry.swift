import Foundation

/// Дедупликация жёстких ссылок: файл с nlink > 1 считается один раз.
final class HardLinkRegistry: @unchecked Sendable {
    private struct Key: Hashable {
        let device: Int32
        let inode: UInt64
    }

    private var seen = Set<Key>()
    private let lock = NSLock()

    /// reportedSize для первого вхождения multi-link файла, 0 для повторов.
    /// Для обычных файлов (nlink == 1) — reportedSize без учёта в реестре.
    func countableSize(of url: URL, reportedSize: Int64) -> Int64 {
        var status = stat()
        let success = url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            return lstat(path, &status) == 0
        }
        guard success, status.st_nlink > 1 else { return reportedSize }
        let key = Key(device: status.st_dev, inode: status.st_ino)
        lock.lock()
        defer { lock.unlock() }
        return seen.insert(key).inserted ? reportedSize : 0
    }
}
