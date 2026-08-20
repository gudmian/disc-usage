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
    let apps = await discovery.scan()

    #expect(apps.count == 1)
    #expect(apps[0].displayName == "App One")
    #expect(apps[0].bundleIdentifier == "com.example.appone")
    #expect(apps[0].size >= 20_000)
    #expect(apps[0].isRunning == false)
}

@Test func displayNameFallsBackToBundleNameThenFileName() async throws {
    let root = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try Fixture.makeApp(at: root, name: "NoDisplayName", bundleIdentifier: "com.example.nodisplay")

    let discovery = AppDiscovery(directories: [root])
    let apps = await discovery.scan()

    #expect(apps[0].displayName == "NoDisplayName")  // CFBundleName, т.к. CFBundleDisplayName не задан
}

@Test func runningProviderMarksMatchingAppAsRunning() async throws {
    let root = try Fixture.makeTree([:])
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try Fixture.makeApp(at: root, name: "AppOne", bundleIdentifier: "com.example.appone")
    let provider = MockRunningApplicationsProvider()
    provider.identifiers = ["com.example.appone"]

    let discovery = AppDiscovery(directories: [root], runningProvider: provider)
    let apps = await discovery.scan()

    #expect(apps[0].isRunning == true)
}

@Test func nonAppEntriesAreIgnored() async throws {
    let root = try Fixture.makeTree(["readme.txt": 10, "SomeFolder/": 0])
    defer { try? FileManager.default.removeItem(at: root) }

    let discovery = AppDiscovery(directories: [root])
    let apps = await discovery.scan()

    #expect(apps.isEmpty)
}
