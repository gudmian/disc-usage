import CleanupKit
import Foundation
import Testing
@testable import UninstallKit

private final class MockOutputCapturing: CommandOutputCapturing, @unchecked Sendable {
    private let lock = NSLock()
    var calls: [(String, [String])] = []
    var outputsByExecutable: [String: String] = [:]

    func output(_ executable: String, arguments: [String]) async throws -> String {
        lock.withLock {
            calls.append((executable, arguments))
            return outputsByExecutable[executable] ?? ""
        }
    }
}

private final class MockOwnershipChecking: FileOwnershipChecking, @unchecked Sendable {
    var unownedPaths: Set<String> = []
    func isOwnedByCurrentUser(_ url: URL) -> Bool { !unownedPaths.contains(url.path) }
}

private func makeApp(url: URL, bundleIdentifier: String) -> AppInfo {
    AppInfo(
        url: url, displayName: url.deletingPathExtension().lastPathComponent,
        bundleIdentifier: bundleIdentifier, size: 1_000, isRunning: false, homebrewToken: nil)
}

@Test func findsTypedPathLeftoversWithCorrectSafety() async throws {
    let bundleID = "com.example.appone"
    let home = try Fixture.makeTree([
        "Library/Preferences/\(bundleID).plist": 10,
        "Library/Caches/\(bundleID)/data.bin": 5_000,
    ])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let finder = BundleLeftoverFinder(
        environment: environment, commandRunner: MockOutputCapturing(),
        ownership: MockOwnershipChecking())
    let app = makeApp(url: home.appendingPathComponent("AppOne.app"), bundleIdentifier: bundleID)

    let items = await finder.findLeftovers(for: app)

    let prefs = items.first { $0.url?.lastPathComponent == "\(bundleID).plist" }
    #expect(prefs?.safety == .caution)
    #expect(prefs?.enabledByDefault == true)
    let caches = items.first { $0.url?.lastPathComponent == bundleID }
    #expect(caches?.safety == .safe)
    #expect(caches?.enabledByDefault == true)
}

@Test func includesTheAppBundleItselfAsCautionEnabledByDefault() async throws {
    let home = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let finder = BundleLeftoverFinder(
        environment: environment, commandRunner: MockOutputCapturing(),
        ownership: MockOwnershipChecking())
    let appURL = home.appendingPathComponent("AppOne.app")
    let app = makeApp(url: appURL, bundleIdentifier: "com.example.appone")

    let items = await finder.findLeftovers(for: app)

    let bundleItem = items.first { $0.url == appURL }
    #expect(bundleItem?.safety == .caution)
    #expect(bundleItem?.enabledByDefault == true)
}

@Test func mdfindResultsAreCautionAndDisabledByDefault() async throws {
    let home = try Fixture.makeTree(["SupportData/Weird Folder Name": 0])
    defer { try? FileManager.default.removeItem(at: home) }
    let supportPath = home.appendingPathComponent("SupportData/Weird Folder Name").path
    let runner = MockOutputCapturing()
    runner.outputsByExecutable["/usr/bin/mdfind"] = supportPath + "\n"
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let finder = BundleLeftoverFinder(
        environment: environment, commandRunner: runner, ownership: MockOwnershipChecking())
    let app = makeApp(url: home.appendingPathComponent("AppOne.app"), bundleIdentifier: "com.example.appone")

    let items = await finder.findLeftovers(for: app)

    let mdfindItem = items.first { $0.url?.path == supportPath }
    #expect(mdfindItem?.safety == .caution)
    #expect(mdfindItem?.enabledByDefault == false)
    #expect(runner.calls.contains { $0.0 == "/usr/bin/mdfind" })
}

@Test func mdfindRediscoveringTheAppBundleDoesNotDuplicateIt() async throws {
    let home = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: home) }
    let appURL = home.appendingPathComponent("AppOne.app")
    try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
    let runner = MockOutputCapturing()
    runner.outputsByExecutable["/usr/bin/mdfind"] = appURL.path + "\n"
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let finder = BundleLeftoverFinder(
        environment: environment, commandRunner: runner, ownership: MockOwnershipChecking())
    let app = makeApp(url: appURL, bundleIdentifier: "com.example.appone")

    let items = await finder.findLeftovers(for: app)

    #expect(items.filter { $0.url == appURL }.count == 1)
}

@Test func unownedPathsAreMarkedNotDeletable() async throws {
    let home = try Fixture.makeTree(["Library/Preferences/com.example.appone.plist": 10])
    defer { try? FileManager.default.removeItem(at: home) }
    let prefsPath = home.appendingPathComponent("Library/Preferences/com.example.appone.plist").path
    let ownership = MockOwnershipChecking()
    ownership.unownedPaths = [prefsPath]
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let finder = BundleLeftoverFinder(
        environment: environment, commandRunner: MockOutputCapturing(), ownership: ownership)
    let app = makeApp(url: home.appendingPathComponent("AppOne.app"), bundleIdentifier: "com.example.appone")

    let items = await finder.findLeftovers(for: app)

    #expect(items.first { $0.url?.path == prefsPath }?.deletable == false)
}
