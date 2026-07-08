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

private final class UIMockRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    var calls: [(String, [String])] = []
    func run(_ executable: String, arguments: [String]) throws -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        calls.append((executable, arguments))
        return 0
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
        executor: CleanupExecutor(remover: UIMockRemover(), processRunner: UIMockRunner()))

    await viewModel.scan()

    // AppOne из фикстуры + командный элемент «Недоступные симуляторы»,
    // который не зависит от окружения.
    #expect(viewModel.items.count == 2)
    #expect(viewModel.items.contains { $0.title == "AppOne" })
    #expect(viewModel.selectedIDs == Set(viewModel.items.map(\.id)))
    #expect(viewModel.totalSize(in: .systemJunk) >= 50_000)
    #expect(viewModel.items(in: .developerJunk).allSatisfy { $0.command != nil })
    #expect(viewModel.selectedTotalBytes >= 50_000)
    #expect(viewModel.confirmationMessage.contains("2"))
}

@MainActor @Test func executeSelectedRemovesDeletedItems() async throws {
    let home = try makeFixtureHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let remover = UIMockRemover()
    let runner = UIMockRunner()
    let viewModel = CleanupViewModel(
        junkScanner: JunkScanner(environment: environment),
        lprojScanner: LprojScanner(applicationsDirectory: home.appendingPathComponent("Applications")),
        executor: CleanupExecutor(remover: remover, processRunner: runner))
    await viewModel.scan()

    let report = await viewModel.executeSelected()

    // AppOne — в Корзину, командный элемент — через мок-runner.
    #expect(report.deleted.count == 2)
    #expect(report.failed.isEmpty)
    #expect(remover.trashed.count == 1)
    #expect(runner.calls.count == 1)
    #expect(viewModel.items.isEmpty)
    #expect(viewModel.selectedIDs.isEmpty)
    #expect(viewModel.lastReport?.deleted.count == 2)
}

@MainActor @Test func confirmationMessageWarnsAboutPermanent() async throws {
    let viewModel = CleanupViewModel()
    viewModel.deletePermanently = true
    #expect(viewModel.confirmationMessage.contains("навсегда"))
}
