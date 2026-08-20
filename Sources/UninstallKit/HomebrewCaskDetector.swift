import Foundation

public struct HomebrewCaskDetector: Sendable {
    private let commandRunner: any CommandOutputCapturing

    public init(commandRunner: any CommandOutputCapturing = SystemCommandOutputCapturing()) {
        self.commandRunner = commandRunner
    }

    /// `/usr/bin/env brew ...` — не хардкодим /opt/homebrew vs /usr/local, находим brew через PATH,
    /// как это сделал бы шелл.
    public func caskTokensByAppPath() async -> [String: String] {
        guard let tokenList = try? await commandRunner.output(
            "/usr/bin/env", arguments: ["brew", "list", "--cask", "-1"])
        else { return [:] }

        let tokens = tokenList.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        var result: [String: String] = [:]
        for token in tokens {
            guard let verbose = try? await commandRunner.output(
                "/usr/bin/env", arguments: ["brew", "list", "--cask", "--verbose", token])
            else { continue }
            for line in verbose.split(separator: "\n") {
                guard let appPath = line.split(separator: " ").first, appPath.hasSuffix(".app")
                else { continue }
                result[String(appPath)] = token
            }
        }
        return result
    }
}
