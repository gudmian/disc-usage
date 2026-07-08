import Foundation

public protocol DirectorySizing: Sendable {
    func size(of url: URL) async -> Int64
}

public struct FileSystemSizer: DirectorySizing {
    public init() {}

    public func size(of url: URL) async -> Int64 {
        walkSize(of: url)
    }

    // Синхронный обход: NSEnumerator нельзя итерировать из async-контекста.
    private func walkSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [])
        else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
