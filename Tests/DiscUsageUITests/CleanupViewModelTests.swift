import Foundation
import Testing
import CleanupKit
@testable import DiscUsageUI

private final class UIMockRemover: FileRemoving, @unchecked Sendable {
    private let lock = NSLock()
    var trashed: [String] = []
    func trash(_ url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        trashed.append(url.path)
    }
    func removePermanently(_ url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        trashed.append("PERM:" + url.path)
    }
}

private func makeFixtureHome() throws -> URL {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("discusage-cvm-\(UUID().uuidString)")
    let caches = home.appendingPathComponent("Library/Caches/AppOne")
    try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    try Data(repeating: 0x61, count: 50_000).write(to: caches.appendingPathComponent("blob.bin"))
    return home
}

@MainActor @Test func scanSelectsDefaultsAndComputesTotals() async throws {
    let home = try makeFixtureHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let viewModel = CleanupViewModel(
        junkScanner: JunkScanner(environment: environment),
        lprojScanner: LprojScanner(applicationsDirectory: home.appendingPathComponent("Applications")),
        executor: CleanupExecutor(remover: UIMockRemover()))

    await viewModel.scan()

    #expect(viewModel.items.count == 1)
    #expect(viewModel.items[0].title == "AppOne")
    #expect(viewModel.selectedIDs == Set(viewModel.items.map(\.id)))
    #expect(viewModel.totalSize(in: .systemJunk) >= 50_000)
    #expect(viewModel.items(in: .developerJunk).isEmpty)
    #expect(viewModel.selectedTotalBytes >= 50_000)
    #expect(viewModel.confirmationMessage.contains("1"))
}

@MainActor @Test func executeSelectedRemovesDeletedItems() async throws {
    let home = try makeFixtureHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let remover = UIMockRemover()
    let viewModel = CleanupViewModel(
        junkScanner: JunkScanner(environment: environment),
        lprojScanner: LprojScanner(applicationsDirectory: home.appendingPathComponent("Applications")),
        executor: CleanupExecutor(remover: remover))
    await viewModel.scan()

    let report = await viewModel.executeSelected()

    #expect(report.deleted.count == 1)
    #expect(report.failed.isEmpty)
    #expect(remover.trashed.count == 1)
    #expect(viewModel.items.isEmpty)
    #expect(viewModel.selectedIDs.isEmpty)
    #expect(viewModel.lastReport?.deleted.count == 1)
}

@MainActor @Test func confirmationMessageWarnsAboutPermanent() async throws {
    let viewModel = CleanupViewModel()
    viewModel.deletePermanently = true
    #expect(viewModel.confirmationMessage.contains("навсегда"))
}
