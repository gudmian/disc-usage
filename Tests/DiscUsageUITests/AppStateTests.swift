import Foundation
import Testing
import ScanKit
@testable import DiscUsageUI

private func makeFixtureTree() throws -> URL {
    let unresolved = FileManager.default.temporaryDirectory
        .appendingPathComponent("discusage-ui-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: unresolved.appendingPathComponent("docs"), withIntermediateDirectories: true)
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    let root = realpath(unresolved.path, &buffer).map { URL(filePath: String(cString: $0)) }
        ?? unresolved
    try Data(repeating: 0x61, count: 10_000)
        .write(to: root.appendingPathComponent("docs/report.dat"))
    try Data(repeating: 0x61, count: 5_000)
        .write(to: root.appendingPathComponent("top.dat"))
    return root
}

@MainActor
private func finishedState(root: URL) async throws -> AppState {
    let state = AppState(configuration: ScanConfiguration(rootURL: root))
    state.startScan()
    for _ in 0..<200 {
        if case .finished = state.phase { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    guard case .finished = state.phase else {
        Issue.record("скан не завершился за 5 секунд")
        throw CancellationError()
    }
    return state
}

@MainActor @Test func scanReachesFinishedPhase() async throws {
    let root = try makeFixtureTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try await finishedState(root: root)
    #expect(state.rootNode != nil)
    #expect(state.rootNode?.child(named: "docs") != nil)
}

@MainActor @Test func drillDownAndBreadcrumbNavigation() async throws {
    let root = try makeFixtureTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try await finishedState(root: root)
    let docs = try #require(state.rootNode?.child(named: "docs"))

    state.drillDown(into: docs)
    #expect(state.currentNode === docs)
    #expect(state.currentRelativePath == ["docs"])
    #expect(state.currentPathString == root.path + "/docs")

    state.navigateToRoot()
    #expect(state.currentNode === state.rootNode)

    let file = try #require(docs.child(named: "report.dat"))
    state.drillDown(into: file)  // файлы не открываются
    #expect(state.currentNode === state.rootNode)
}

@MainActor @Test func removeNodesUpdatesTreeAndReplaceResultReresolvesBreadcrumb() async throws {
    let root = try makeFixtureTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try await finishedState(root: root)
    let sizeBefore = try #require(state.rootNode?.size)
    let docs = try #require(state.rootNode?.child(named: "docs"))
    state.drillDown(into: docs)

    state.removeNodes(atAbsolutePaths: [root.path + "/docs/report.dat"])

    let newDocs = try #require(state.rootNode?.child(named: "docs"))
    #expect(newDocs.children.isEmpty)
    #expect(try #require(state.rootNode?.size) < sizeBefore)
    // breadcrumb пере-резолвился на новый узел с тем же именем
    #expect(state.currentNode === newDocs)
}
