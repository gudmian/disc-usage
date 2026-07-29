import Foundation
import Testing
@testable import ScanKit

@Test func firstVisitIsAllowedRepeatVisitIsNot() throws {
    let root = try Fixture.makeTree(["dir/": 0, "other/": 0])
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = VisitedDirectoryRegistry()

    #expect(registry.markVisited(root.appendingPathComponent("dir")))
    #expect(!registry.markVisited(root.appendingPathComponent("dir")))
    #expect(registry.markVisited(root.appendingPathComponent("other")))
}

@Test func aliasedPathToSameDirectoryIsDetected() throws {
    let root = try Fixture.makeTree(["dir/": 0])
    defer { try? FileManager.default.removeItem(at: root) }
    let registry = VisitedDirectoryRegistry()

    #expect(registry.markVisited(root.appendingPathComponent("dir")))
    // Тот же каталог через другой путь (лишний "./") — тот же inode.
    #expect(!registry.markVisited(root.appendingPathComponent("./dir")))
}

@Test func unreadablePathIsAllowedThrough() {
    let registry = VisitedDirectoryRegistry()
    // Несуществующий путь: lstat не сработает — пропускаем без блокировки,
    // решение остаётся за сканером.
    let ghost = URL(filePath: "/nonexistent-\(UUID().uuidString)")
    #expect(registry.markVisited(ghost))
    #expect(registry.markVisited(ghost))
}
