import Foundation
import Testing
@testable import CleanupKit

@Test func sizerSumsAllocatedSizes() async throws {
    let root = try Fixture.makeTree(["dir/a.bin": 10_000, "dir/sub/b.bin": 20_000])
    defer { try? FileManager.default.removeItem(at: root) }
    let size = await FileSystemSizer().size(of: root.appendingPathComponent("dir"))
    #expect(size >= 30_000)
    let fileSize = await FileSystemSizer().size(of: root.appendingPathComponent("dir/a.bin"))
    #expect(fileSize >= 10_000)
}

@Test func contentsOnlyRuleEmitsPerChildItems() async throws {
    let home = try Fixture.makeTree([
        "Library/Caches/AppOne/data.bin": 10_000,
        "Library/Caches/AppTwo/data.bin": 20_000,
    ])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let rule = CleanupRule(
        id: "system.userCaches", title: "Кэши приложений", category: .systemJunk,
        safety: .safe,
        pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches"])],
        deleteContentsOnly: true)

    let items = await JunkScanner(environment: environment).scan(rules: [rule])

    #expect(items.count == 2)
    #expect(Set(items.map(\.title)) == ["AppOne", "AppTwo"])
    #expect(items.allSatisfy { $0.size >= 10_000 })
    #expect(items.allSatisfy { $0.ruleID == "system.userCaches" })
}

@Test func overlappingAndDuplicateItemsAreDeduplicated() async throws {
    let home = try Fixture.makeTree(["Library/Caches/org.swift.swiftpm/manifest.bin": 5_000])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let parent = CleanupRule(
        id: "system.userCaches", title: "Кэши", category: .systemJunk, safety: .safe,
        pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches"])],
        deleteContentsOnly: true)
    let nested = CleanupRule(
        id: "dev.spmCache", title: "Кэш SPM", category: .developerJunk, safety: .safe,
        pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "org.swift.swiftpm"])])

    let items = await JunkScanner(environment: environment).scan(rules: [parent, nested])

    #expect(items.count == 1)
    #expect(items[0].url?.lastPathComponent == "org.swift.swiftpm")
}

@Test func commandRuleProducesCommandItem() async {
    let environment = CleanupEnvironment(
        homeDirectory: URL(filePath: "/nonexistent"), rootDirectory: URL(filePath: "/nonexistent"))
    let rule = CleanupRule(
        id: "dev.unavailableSimulators", title: "Недоступные симуляторы",
        category: .developerJunk, safety: .safe, pathPatterns: [],
        command: CommandAction(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"]))

    let items = await JunkScanner(environment: environment).scan(rules: [rule])

    #expect(items.count == 1)
    #expect(items[0].url == nil)
    #expect(items[0].command?.arguments == ["simctl", "delete", "unavailable"])
}

@Test func rulesTableInvariants() {
    let rules = CleanupRules.all
    #expect(Set(rules.map(\.id)).count == rules.count)
    let history = rules.first { $0.id == "browser.safariHistory" }
    #expect(history?.enabledByDefault == false)
    let trash = rules.first { $0.id == "system.trash" }
    #expect(trash?.permanentOnly == true)
    let archives = rules.first { $0.id == "dev.xcodeArchives" }
    #expect(archives?.enabledByDefault == false)
    #expect(archives?.safety == .caution)
    #expect(rules.contains { $0.command != nil })
}
