import Foundation
import Testing
@testable import UninstallKit

private final class MockOutputCapturing: CommandOutputCapturing, @unchecked Sendable {
    private let lock = NSLock()
    var calls: [[String]] = []
    var shouldThrow = false
    var responses: [String: String] = [:]  // keyed by joined arguments

    func output(_ executable: String, arguments: [String]) async throws -> String {
        try lock.withLock {
            calls.append(arguments)
            if shouldThrow { throw NSError(domain: "mock", code: 1) }
            return responses[arguments.joined(separator: " ")] ?? ""
        }
    }
}

@Test func mapsCaskTokensToTheirAppPaths() async throws {
    let runner = MockOutputCapturing()
    runner.responses["brew list --cask -1"] = "slack\ndocker\n"
    runner.responses["brew list --cask --verbose slack"] =
        "/opt/homebrew/Caskroom/slack/4.36.140/Slack.app (156 files, 340MB)\n"
    runner.responses["brew list --cask --verbose docker"] =
        "/Applications/Docker.app (1 file, 1.2GB)\n"
    let detector = HomebrewCaskDetector(commandRunner: runner)

    let tokens = await detector.caskTokensByAppPath()

    #expect(tokens["/opt/homebrew/Caskroom/slack/4.36.140/Slack.app"] == "slack")
    #expect(tokens["/Applications/Docker.app"] == "docker")
    #expect(tokens.count == 2)
}

@Test func missingBrewBinaryReturnsEmptyMapNotError() async throws {
    let runner = MockOutputCapturing()
    runner.shouldThrow = true
    let detector = HomebrewCaskDetector(commandRunner: runner)

    let tokens = await detector.caskTokensByAppPath()

    #expect(tokens.isEmpty)
}

@Test func usesEnvToResolveBrewRegardlessOfArchitecture() async throws {
    let runner = MockOutputCapturing()
    let detector = HomebrewCaskDetector(commandRunner: runner)
    _ = await detector.caskTokensByAppPath()
    #expect(runner.calls.first == ["brew", "list", "--cask", "-1"])
}
