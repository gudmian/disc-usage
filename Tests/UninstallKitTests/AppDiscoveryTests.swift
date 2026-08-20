import Foundation
import Testing
@testable import UninstallKit

private final class MockRunningApplicationsProvider: RunningApplicationsProviding, @unchecked Sendable {
    var identifiers: Set<String> = []
    func runningBundleIdentifiers() -> Set<String> { identifiers }
}

@Test func scanFindsTopLevelAppsWithBundleIdentifierAndSize() async throws {
    let root = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try Fixture.makeApp(
        at: root, name: "AppOne", bundleIdentifier: "com.example.appone",
        displayName: "App One", payloadBytes: 20_000)

    let discovery = AppDiscovery(directories: [root])
    let result = await discovery.scan()

    #expect(result.apps.count == 1)
    #expect(result.apps[0].displayName == "App One")
    #expect(result.apps[0].bundleIdentifier == "com.example.appone")
    #expect(result.apps[0].size >= 20_000)
    #expect(result.apps[0].isRunning == false)
    #expect(result.unreadableDirectories.isEmpty)
}

@Test func displayNameFallsBackToBundleNameThenFileName() async throws {
    let root = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try Fixture.makeApp(at: root, name: "NoDisplayName", bundleIdentifier: "com.example.nodisplay")

    let discovery = AppDiscovery(directories: [root])
    let result = await discovery.scan()

    #expect(result.apps[0].displayName == "NoDisplayName")  // CFBundleName, т.к. CFBundleDisplayName не задан
}

@Test func runningProviderMarksMatchingAppAsRunning() async throws {
    let root = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try Fixture.makeApp(at: root, name: "AppOne", bundleIdentifier: "com.example.appone")
    let provider = MockRunningApplicationsProvider()
    provider.identifiers = ["com.example.appone"]

    let discovery = AppDiscovery(directories: [root], runningProvider: provider)
    let result = await discovery.scan()

    #expect(result.apps[0].isRunning == true)
}

@Test func nonAppEntriesAreIgnored() async throws {
    let root = try Fixture.makeTree(["readme.txt": 10, "SomeFolder/": 0])
    defer { try? FileManager.default.removeItem(at: root) }

    let discovery = AppDiscovery(directories: [root])
    let result = await discovery.scan()

    #expect(result.apps.isEmpty)
}

@Test func missingDirectoryIsNotReportedAsUnreadable() async throws {
    let discovery = AppDiscovery(directories: [URL(filePath: "/nonexistent-discusage-dir")])
    let result = await discovery.scan()

    #expect(result.apps.isEmpty)
    #expect(result.unreadableDirectories.isEmpty)  // не существует — это нормально, не ошибка
}

@Test func unreadableDirectoryIsReportedSeparatelyFromMissing() async throws {
    let root = try Fixture.makeTree([:])
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: root.path)

    let discovery = AppDiscovery(directories: [root])
    let result = await discovery.scan()

    #expect(result.apps.isEmpty)
    #expect(result.unreadableDirectories == [root])
}

@Test func onProgressReportsIncreasingCountsUpToTotal() async throws {
    let root = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try Fixture.makeApp(at: root, name: "AppOne", bundleIdentifier: "com.example.one")
    _ = try Fixture.makeApp(at: root, name: "AppTwo", bundleIdentifier: "com.example.two")
    _ = try Fixture.makeApp(at: root, name: "AppThree", bundleIdentifier: "com.example.three")

    let discovery = AppDiscovery(directories: [root])
    let reported = LockedBox<[AppDiscoveryProgress]>([])
    let result = await discovery.scan(onProgress: { progress in
        reported.mutate { $0.append(progress) }
    })

    #expect(result.apps.count == 3)
    let progresses = reported.value
    #expect(progresses.count == 3)
    #expect(progresses.allSatisfy { $0.total == 3 })
    #expect(Set(progresses.map(\.scanned)) == [1, 2, 3])
}

/// Простой потокобезопасный контейнер для проверки коллбэков, вызываемых из TaskGroup.
private final class LockedBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: T
    init(_ value: T) { storage = value }
    var value: T { lock.withLock { storage } }
    func mutate(_ body: (inout T) -> Void) { lock.withLock { body(&storage) } }
}
