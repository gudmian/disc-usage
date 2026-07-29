import Foundation

/// Дедупликация каталогов по (device, inode): защита от повторного обхода
/// одной и той же директории через алиасы — магические каталоги ядра
/// (/.nofollow), firmlink'и и прочие зеркала иерархии.
final class VisitedDirectoryRegistry: @unchecked Sendable {
    private struct Key: Hashable {
        let device: Int32
        let inode: UInt64
    }

    private var seen = Set<Key>()
    private let lock = NSLock()

    /// true — каталог ещё не посещался (и теперь зарегистрирован),
    /// false — уже был посещён по другому пути. Если lstat недоступен,
    /// пропускаем без регистрации: решение остаётся за сканером.
    func markVisited(_ url: URL) -> Bool {
        var status = stat()
        let success = url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            return lstat(path, &status) == 0
        }
        guard success else { return true }
        let key = Key(device: status.st_dev, inode: status.st_ino)
        lock.lock()
        defer { lock.unlock() }
        return seen.insert(key).inserted
    }
}
