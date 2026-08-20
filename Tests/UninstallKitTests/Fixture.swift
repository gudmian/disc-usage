import Foundation

enum Fixture {
    static func makeTree(_ spec: [String: Int]) throws -> URL {
        let unresolved = FileManager.default.temporaryDirectory
            .appendingPathComponent("discusage-uninstall-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: unresolved, withIntermediateDirectories: true)
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

    /// Создаёт фикстурный `.app`-бандл с Info.plist (CFBundleIdentifier/CFBundleName/CFBundleDisplayName).
    static func makeApp(
        at directory: URL, name: String, bundleIdentifier: String,
        displayName: String? = nil, payloadBytes: Int = 1_000
    ) throws -> URL {
        let appURL = directory.appendingPathComponent("\(name).app")
        let contents = appURL.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        var info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
        ]
        if let displayName { info["CFBundleDisplayName"] = displayName }
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: info, format: .xml, options: 0)
        try plistData.write(to: contents.appendingPathComponent("Info.plist"))
        try Data(repeating: 0x61, count: payloadBytes)
            .write(to: contents.appendingPathComponent("payload.bin"))
        return appURL
    }
}
