import Foundation
import Testing
@testable import ScanKit

@Test func scanBuildsTreeWithRolledUpSizes() async throws {
    let root = try Fixture.makeTree([
        "a/one.dat": 10_000, "a/two.dat": 20_000, "b/three.dat": 4_096, "empty/": 0,
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let a = try #require(result.root.child(named: "a"))
    let expectedA = try Fixture.allocatedSize(of: root.appendingPathComponent("a/one.dat"))
        + Fixture.allocatedSize(of: root.appendingPathComponent("a/two.dat"))
    #expect(a.size == expectedA)
    #expect(a.children.count == 2)
    let b = try #require(result.root.child(named: "b"))
    #expect(result.root.size == a.size + b.size)
    let empty = try #require(result.root.child(named: "empty"))
    #expect(empty.kind == .directory)
    #expect(empty.size == 0)
    #expect(result.inaccessiblePaths.isEmpty)
}

@Test func symbolicLinksAreNotFollowed() async throws {
    let root = try Fixture.makeTree(["real/data.dat": 8_192])
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("link"),
        withDestinationURL: root.appendingPathComponent("real"))

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let expected = try Fixture.allocatedSize(of: root.appendingPathComponent("real/data.dat"))
    #expect(result.root.size == expected)
    let link = try #require(result.root.child(named: "link"))
    #expect(link.kind == .file)
    #expect(link.size == 0)
}

@Test func inaccessibleDirectoryIsFlaggedAndScanContinues() async throws {
    let root = try Fixture.makeTree(["locked/secret.dat": 4_096, "open/file.dat": 4_096])
    let locked = root.appendingPathComponent("locked")
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        try? FileManager.default.removeItem(at: root)
    }

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let lockedNode = try #require(result.root.child(named: "locked"))
    #expect(lockedNode.kind == .inaccessibleDirectory)
    #expect(result.inaccessiblePaths.contains(locked.path))
    let open = try #require(result.root.child(named: "open"))
    #expect(open.size > 0)
}

/// Смонтированные тома (симуляторы, cryptex, внешние диски) не входят в счёт:
/// их содержимое не занимает место на сканируемом диске. /System/Volumes
/// есть на каждой современной macOS — Preboot/VM всегда смонтированы.
@Test func otherVolumeRootsAreNotEntered() async throws {
    let config = ScanConfiguration(
        rootURL: URL(filePath: "/System/Volumes"),
        excludedPaths: ["/System/Volumes/Data"])

    let result = try await DiskScanner().scan(configuration: config)

    #expect(result.root.child(named: "Preboot") == nil)
    #expect(result.root.child(named: "VM") == nil)
}

/// Реестр посещённых каталогов живёт внутри одного скана: повторный скан
/// того же корня должен дать тот же результат, а не нули.
@Test func repeatedScansAreIndependent() async throws {
    let root = try Fixture.makeTree(["a/one.dat": 10_000, "b/two.dat": 4_096])
    defer { try? FileManager.default.removeItem(at: root) }
    let scanner = DiskScanner()
    let configuration = ScanConfiguration(rootURL: root)

    let first = try await scanner.scan(configuration: configuration)
    let second = try await scanner.scan(configuration: configuration)

    #expect(first.root.size > 0)
    #expect(second.root.size == first.root.size)
    #expect(second.root.children.count == first.root.children.count)
}

@Test func excludedPathsAreSkipped() async throws {
    let root = try Fixture.makeTree(["keep/a.dat": 4_096, "skip/b.dat": 4_096])
    defer { try? FileManager.default.removeItem(at: root) }
    let config = ScanConfiguration(
        rootURL: root, excludedPaths: [root.appendingPathComponent("skip").path])

    let result = try await DiskScanner().scan(configuration: config)

    #expect(result.root.child(named: "skip") == nil)
    #expect(result.root.child(named: "keep") != nil)
}
