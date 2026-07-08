import Foundation
import Testing
@testable import ScanKit

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
    func withLock(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&storage)
    }
}

@Test func hardLinkedFileIsCountedOnce() async throws {
    let root = try Fixture.makeTree(["a/original.dat": 100_000])
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("b"), withIntermediateDirectories: true)
    try FileManager.default.linkItem(
        at: root.appendingPathComponent("a/original.dat"),
        to: root.appendingPathComponent("b/copy.dat"))

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let expected = try Fixture.allocatedSize(of: root.appendingPathComponent("a/original.dat"))
    #expect(result.root.size == expected)
}

@Test func progressIsReported() async throws {
    var spec: [String: Int] = [:]
    for index in 0..<50 { spec["dir\(index % 5)/file\(index).dat"] = 4_096 }
    let root = try Fixture.makeTree(spec)
    defer { try? FileManager.default.removeItem(at: root) }

    let collected = Locked<[ScanProgress]>([])
    _ = try await DiskScanner(progressInterval: 10)
        .scan(configuration: ScanConfiguration(rootURL: root)) { progress in
            collected.withLock { $0.append(progress) }
        }

    let snapshots = collected.value
    #expect(!snapshots.isEmpty)
    #expect(snapshots.contains { $0.scannedItems == 50 })
    #expect(snapshots.map(\.scannedItems).max() == 50)
    #expect(snapshots.contains { $0.totalBytes > 0 })
}

@Test func cancellationStopsScan() async throws {
    var spec: [String: Int] = [:]
    for index in 0..<200 { spec["nested/dir\(index)/file.dat"] = 4_096 }
    let root = try Fixture.makeTree(spec)
    defer { try? FileManager.default.removeItem(at: root) }

    let scanner = DiskScanner()
    let config = ScanConfiguration(rootURL: root)
    // cancel() выполняется через наносекунды после старта; скан 200 директорий
    // занимает на порядки дольше, поэтому CancellationError детерминирован.
    let task = Task { try await scanner.scan(configuration: config) }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}
