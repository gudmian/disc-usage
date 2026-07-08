import Foundation
import Testing
@testable import CleanupKit

private final class MockRemover: FileRemoving, @unchecked Sendable {
    private let lock = NSLock()
    var trashed: [String] = []
    var removed: [String] = []
    var failingPaths: Set<String> = []

    func trash(_ url: URL) throws {
        try record(url) { trashed.append(url.path) }
    }
    func removePermanently(_ url: URL) throws {
        try record(url) { removed.append(url.path) }
    }
    private func record(_ url: URL, _ append: () -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        if failingPaths.contains(url.path) {
            throw NSError(domain: "mock", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "нет прав"])
        }
        append()
    }
}

private final class MockRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    var calls: [(String, [String])] = []
    var status: Int32 = 0
    func run(_ executable: String, arguments: [String]) throws -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        calls.append((executable, arguments))
        return status
    }
}

private func makeItem(
    id: String, path: String?, size: Int64 = 100, permanentOnly: Bool = false,
    deletable: Bool = true, command: CommandAction? = nil
) -> CleanupItem {
    let rule = CleanupRule(
        id: id, title: id, category: .systemJunk, safety: .safe,
        pathPatterns: [], permanentOnly: permanentOnly)
    return CleanupItem(
        rule: rule, url: path.map { URL(filePath: $0) }, size: size,
        command: command, deletable: deletable)
}

@Test func trashByDefaultPermanentWhenRequested() async {
    let remover = MockRemover()
    let executor = CleanupExecutor(remover: remover, processRunner: MockRunner())

    let report1 = await executor.execute(
        items: [makeItem(id: "a", path: "/tmp/a")], permanently: false)
    #expect(remover.trashed == ["/tmp/a"])
    #expect(report1.deleted.count == 1)

    let report2 = await executor.execute(
        items: [makeItem(id: "b", path: "/tmp/b")], permanently: true)
    #expect(remover.removed == ["/tmp/b"])
    #expect(report2.freedBytes == 100)
}

@Test func permanentOnlyItemsAlwaysRemovedPermanently() async {
    let remover = MockRemover()
    let executor = CleanupExecutor(remover: remover, processRunner: MockRunner())
    _ = await executor.execute(
        items: [makeItem(id: "trash", path: "/tmp/.Trash/x", permanentOnly: true)],
        permanently: false)
    #expect(remover.removed == ["/tmp/.Trash/x"])
    #expect(remover.trashed.isEmpty)
}

@Test func failuresDoNotStopBatchAndNonDeletableSkipped() async {
    let remover = MockRemover()
    remover.failingPaths = ["/tmp/locked"]
    let executor = CleanupExecutor(remover: remover, processRunner: MockRunner())

    let report = await executor.execute(items: [
        makeItem(id: "a", path: "/tmp/locked"),
        makeItem(id: "b", path: "/tmp/ok", size: 500),
        makeItem(id: "c", path: "/tmp/viewonly", deletable: false),
    ], permanently: false)

    #expect(report.deleted.map(\.ruleID) == ["b"])
    #expect(report.failed.count == 2)
    #expect(report.freedBytes == 500)
    #expect(report.failed.contains { $0.message == "нет прав" })
}

@Test func commandItemRunsProcess() async {
    let runner = MockRunner()
    let executor = CleanupExecutor(remover: MockRemover(), processRunner: runner)
    let command = CommandAction(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"])

    let report = await executor.execute(
        items: [makeItem(id: "sim", path: nil, size: 0, command: command)], permanently: false)

    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].0 == "/usr/bin/xcrun")
    #expect(report.deleted.count == 1)

    runner.status = 1
    let failing = await executor.execute(
        items: [makeItem(id: "sim2", path: nil, size: 0, command: command)], permanently: false)
    #expect(failing.failed.count == 1)
}
