import Foundation
import Testing
@testable import ScanKit

private func sampleTree() -> FileNode {
    FileNode(directoryNamed: "root", children: [
        FileNode(directoryNamed: "a", children: [
            FileNode(fileNamed: "one.dat", size: 100),
            FileNode(fileNamed: "two.dat", size: 200),
        ]),
        FileNode(fileNamed: "top.dat", size: 50),
    ])
}

@Test func replacingRebuildsAncestorSizes() throws {
    let replacement = FileNode(directoryNamed: "a", children: [
        FileNode(fileNamed: "one.dat", size: 100)
    ])
    let updated = try #require(
        TreeRebuilder.replacing(nodeAt: ["a"], with: replacement, in: sampleTree()))
    #expect(updated.size == 150)
    #expect(updated.child(named: "a")?.size == 100)
    #expect(TreeRebuilder.replacing(nodeAt: ["missing"], with: replacement, in: sampleTree()) == nil)
}

@Test func removingNodeRecomputesSizes() throws {
    let updated = try #require(TreeRebuilder.removingNode(at: ["a", "two.dat"], in: sampleTree()))
    #expect(updated.size == 150)
    #expect(updated.child(named: "a")?.children.count == 1)
    #expect(TreeRebuilder.removingNode(at: ["a", "ghost"], in: sampleTree()) == nil)
}

@Test func rescanSubtreePicksUpDeletions() async throws {
    let root = try Fixture.makeTree(["a/one.dat": 10_000, "a/two.dat": 10_000, "b/keep.dat": 4_096])
    defer { try? FileManager.default.removeItem(at: root) }
    let config = ScanConfiguration(rootURL: root)
    let scanner = DiskScanner()
    let before = try await scanner.scan(configuration: config)

    try FileManager.default.removeItem(at: root.appendingPathComponent("a/two.dat"))
    let after = try await scanner.rescanSubtree(at: ["a"], in: before, configuration: config)

    let expectedA = try Fixture.allocatedSize(of: root.appendingPathComponent("a/one.dat"))
    #expect(after.root.child(named: "a")?.size == expectedA)
    let keep = try #require(after.root.child(named: "b"))
    #expect(keep.size > 0)
}
