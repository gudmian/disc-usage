import CleanupKit
import Foundation
import Testing
import UninstallKit
@testable import DiscUsageUI

private final class UIMockRemover: FileRemoving, @unchecked Sendable {
    private let lock = NSLock()
    var trashed: [String] = []
    func trash(_ url: URL) throws {
        lock.withLock { trashed.append(url.path) }
    }
    func removePermanently(_ url: URL) throws {
        lock.withLock { trashed.append("PERM:" + url.path) }
    }
}

private struct StubRunningApplicationsProvider: RunningApplicationsProviding {
    let identifiers: Set<String>
    func runningBundleIdentifiers() -> Set<String> { identifiers }
}

/// `/tmp`/`temporaryDirectory` — симлинк на `/private/...`; резолвим, иначе пути,
/// которые обходит FileManager, не совпадают буквально с тем, что мы здесь строим руками.
private func makeFixtureRoot() throws -> URL {
    let unresolved = FileManager.default.temporaryDirectory
        .appendingPathComponent("discusage-appsvm-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: unresolved, withIntermediateDirectories: true)
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
    return realpath(unresolved.path, &buffer).map { URL(filePath: String(cString: $0)) } ?? unresolved
}

private func makeFixtureApp(in directory: URL) throws -> (url: URL, bundleID: String) {
    let bundleID = "com.example.appone"
    let appURL = directory.appendingPathComponent("AppOne.app")
    let contents = appURL.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist = try PropertyListSerialization.data(
        fromPropertyList: ["CFBundleIdentifier": bundleID, "CFBundleName": "AppOne"],
        format: .xml, options: 0)
    try plist.write(to: contents.appendingPathComponent("Info.plist"))
    return (appURL, bundleID)
}

@MainActor @Test func scanAppsPopulatesListSortedBySize() async throws {
    let root = try makeFixtureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try makeFixtureApp(in: root)

    let viewModel = AppsViewModel(discovery: AppDiscovery(directories: [root]))
    await viewModel.scanApps()

    #expect(viewModel.apps.count == 1)
    #expect(viewModel.apps[0].displayName == "AppOne")
}

@MainActor @Test func selectAppScansLeftoversAndPreselectsDefaults() async throws {
    let root = try makeFixtureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (appURL, bundleID) = try makeFixtureApp(in: root)
    let environment = CleanupEnvironment(homeDirectory: root, rootDirectory: root)

    let viewModel = AppsViewModel(
        discovery: AppDiscovery(directories: [root]),
        leftoverFinder: BundleLeftoverFinder(environment: environment))
    await viewModel.scanApps()
    await viewModel.selectApp(viewModel.apps[0])

    #expect(viewModel.leftoverItems.contains { $0.url?.path == appURL.path })
    #expect(viewModel.selectedLeftoverIDs.count == viewModel.leftoverItems.filter { $0.enabledByDefault }.count)
    _ = bundleID
}

@MainActor @Test func executeSelectedTrashesItemsAndRemovesDeletedAppFromList() async throws {
    let root = try makeFixtureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (appURL, _) = try makeFixtureApp(in: root)
    let environment = CleanupEnvironment(homeDirectory: root, rootDirectory: root)
    let remover = UIMockRemover()

    let viewModel = AppsViewModel(
        discovery: AppDiscovery(directories: [root]),
        leftoverFinder: BundleLeftoverFinder(environment: environment),
        executor: CleanupExecutor(remover: remover))
    await viewModel.scanApps()
    await viewModel.selectApp(viewModel.apps[0])

    let report = await viewModel.executeSelected()

    #expect(report.deleted.contains { $0.url?.path == appURL.path })
    #expect(remover.trashed.contains(appURL.path))
    #expect(viewModel.apps.isEmpty)  // приложение целиком удалено — исчезает из списка
}

@MainActor @Test func confirmationMessageWarnsWhenSelectedAppIsRunning() async throws {
    let root = try makeFixtureRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let (_, bundleID) = try makeFixtureApp(in: root)
    let runningProvider = StubRunningApplicationsProvider(identifiers: [bundleID])
    let environment = CleanupEnvironment(homeDirectory: root, rootDirectory: root)

    let viewModel = AppsViewModel(
        discovery: AppDiscovery(directories: [root], runningProvider: runningProvider),
        leftoverFinder: BundleLeftoverFinder(environment: environment))
    await viewModel.scanApps()
    await viewModel.selectApp(viewModel.apps[0])

    #expect(viewModel.confirmationMessage.contains("запущено"))
}

@MainActor @Test func confirmationMessageOmitsRunningWarningWithoutSelection() {
    let viewModel = AppsViewModel()
    #expect(!viewModel.confirmationMessage.contains("запущено"))
}
