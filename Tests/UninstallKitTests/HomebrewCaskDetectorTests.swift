import Foundation
import Testing
@testable import UninstallKit

private final class MockOutputCapturing: CommandOutputCapturing, @unchecked Sendable {
    private let lock = NSLock()
    var calls: [(executable: String, arguments: [String])] = []
    var shouldThrow = false
    var responses: [String: String] = [:]  // keyed by joined arguments (без executable)

    func output(_ executable: String, arguments: [String]) async throws -> String {
        try lock.withLock {
            calls.append((executable, arguments))
            if shouldThrow { throw NSError(domain: "mock", code: 1) }
            return responses[arguments.joined(separator: " ")] ?? ""
        }
    }
}

private final class MockExecutableFileChecking: ExecutableFileChecking, @unchecked Sendable {
    var executablePaths: Set<String> = []
    func isExecutableFile(atPath path: String) -> Bool { executablePaths.contains(path) }
}

@Test func mapsCaskTokensToTheirAppPaths() async throws {
    let runner = MockOutputCapturing()
    runner.responses["brew list --cask -1"] = "slack\ndocker\n"
    runner.responses["brew list --cask --verbose slack"] =
        "/opt/homebrew/Caskroom/slack/4.36.140/Slack.app (156 files, 340MB)\n"
    runner.responses["brew list --cask --verbose docker"] =
        "/Applications/Docker.app (1 file, 1.2GB)\n"
    let detector = HomebrewCaskDetector(commandRunner: runner, executableChecker: MockExecutableFileChecking())

    let tokens = await detector.caskTokensByAppPath()

    #expect(tokens["/opt/homebrew/Caskroom/slack/4.36.140/Slack.app"] == "slack")
    #expect(tokens["/Applications/Docker.app"] == "docker")
    #expect(tokens.count == 2)
}

@Test func missingBrewBinaryReturnsEmptyMapNotError() async throws {
    let runner = MockOutputCapturing()
    runner.shouldThrow = true
    let detector = HomebrewCaskDetector(commandRunner: runner, executableChecker: MockExecutableFileChecking())

    let tokens = await detector.caskTokensByAppPath()

    #expect(tokens.isEmpty)
}

@Test func usesEnvToResolveBrewWhenNoKnownPathExists() async throws {
    let runner = MockOutputCapturing()
    let detector = HomebrewCaskDetector(commandRunner: runner, executableChecker: MockExecutableFileChecking())
    _ = await detector.caskTokensByAppPath()
    #expect(runner.calls.first?.executable == "/usr/bin/env")
    #expect(runner.calls.first?.arguments == ["brew", "list", "--cask", "-1"])
}

@Test func prefersKnownBrewPathOverEnvFallback() async throws {
    let runner = MockOutputCapturing()
    runner.responses["list --cask -1"] = "docker\n"
    runner.responses["list --cask --verbose docker"] = "/Applications/Docker.app (1 file, 1.2GB)\n"
    let checker = MockExecutableFileChecking()
    checker.executablePaths = ["/opt/homebrew/bin/brew"]
    let detector = HomebrewCaskDetector(commandRunner: runner, executableChecker: checker)

    let tokens = await detector.caskTokensByAppPath()

    #expect(tokens["/Applications/Docker.app"] == "docker")
    #expect(runner.calls.first?.executable == "/opt/homebrew/bin/brew")
    #expect(runner.calls.first?.arguments == ["list", "--cask", "-1"])
}
