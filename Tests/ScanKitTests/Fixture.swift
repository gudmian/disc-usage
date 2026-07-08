import Foundation

enum Fixture {
    /// Создаёт временное дерево. Ключ — относительный путь; значение — байты файла.
    /// Ключ с завершающим "/" создаёт пустую директорию. Возвращает корень.
    static func makeTree(_ spec: [String: Int]) throws -> URL {
        let unresolved = FileManager.default.temporaryDirectory
            .appendingPathComponent("discusage-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unresolved, withIntermediateDirectories: true)
        // realpath: /var → /private/var; Foundation-методы этого не делают, а сканер
        // получает от FileManager уже резолвленные пути — без этого assert'ы
        // по путям не сойдутся.
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let root = realpath(unresolved.path, &buffer).map { URL(filePath: String(cString: $0)) }
            ?? unresolved
        for (relativePath, byteCount) in spec {
            let url = root.appendingPathComponent(relativePath)
            if relativePath.hasSuffix("/") {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(repeating: 0x61, count: byteCount).write(to: url)
            }
        }
        return root
    }

    /// Аллоцированный размер файла — как его должен посчитать сканер.
    static func allocatedSize(of url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return Int64(values.totalFileAllocatedSize ?? 0)
    }
}
