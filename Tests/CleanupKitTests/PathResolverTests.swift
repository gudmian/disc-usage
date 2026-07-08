import Foundation
import Testing
@testable import CleanupKit

/// Копия хелпера из ScanKitTests (тест-таргеты не делят код).
enum Fixture {
    static func makeTree(_ spec: [String: Int]) throws -> URL {
        let unresolved = FileManager.default.temporaryDirectory
            .appendingPathComponent("discusage-cleanup-\(UUID().uuidString)")
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
}

@Test func resolvesLiteralPathRelativeToHome() throws {
    let home = try Fixture.makeTree(["Library/Caches/App1/data.bin": 100])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)

    let pattern = PathPattern(base: .home, components: ["Library", "Caches"])
    let resolved = PathResolver.resolve(pattern, environment: environment)
    #expect(resolved.map(\.lastPathComponent) == ["Caches"])

    let missing = PathPattern(base: .home, components: ["Library", "Nope"])
    #expect(PathResolver.resolve(missing, environment: environment).isEmpty)
}

@Test func starExpandsOneLevel() throws {
    let home = try Fixture.makeTree([
        "profiles/alpha/cache/x.bin": 10,
        "profiles/beta/cache/y.bin": 10,
        "profiles/gamma/nocache.txt": 10,
    ])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)

    let pattern = PathPattern(base: .home, components: ["profiles", "*", "cache"])
    let resolved = PathResolver.resolve(pattern, environment: environment)
    #expect(resolved.count == 2)
    #expect(resolved.allSatisfy { $0.lastPathComponent == "cache" })
}

@Test func cleanupItemDerivesFieldsFromRule() {
    let rule = CleanupRule(
        id: "test.rule", title: "Тестовое правило", category: .systemJunk, safety: .safe,
        pathPatterns: [], enabledByDefault: false)
    let url = URL(filePath: "/tmp/target")
    let item = CleanupItem(rule: rule, url: url, size: 42)
    #expect(item.id == "test.rule:/tmp/target")
    #expect(item.title == "target")
    #expect(item.enabledByDefault == false)
    #expect(item.deletable == true)
    let commandItem = CleanupItem(
        rule: rule, url: nil, size: 0,
        command: CommandAction(executable: "/usr/bin/true", arguments: []))
    #expect(commandItem.title == "Тестовое правило")
    #expect(commandItem.id == "test.rule:command")
}
