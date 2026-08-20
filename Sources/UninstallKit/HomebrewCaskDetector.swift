import Foundation

public struct HomebrewCaskDetector: Sendable {
    private let commandRunner: any CommandOutputCapturing
    private let executableChecker: any ExecutableFileChecking

    private static let knownBrewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    public init(
        commandRunner: any CommandOutputCapturing = SystemCommandOutputCapturing(),
        executableChecker: any ExecutableFileChecking = SystemExecutableFileChecking()
    ) {
        self.commandRunner = commandRunner
        self.executableChecker = executableChecker
    }

    /// GUI-приложения (запущенные не из Terminal) получают урезанный системный $PATH
    /// без /opt/homebrew/bin — поэтому сначала пробуем известные места установки Homebrew,
    /// и только если нигде не нашли — падаем на `/usr/bin/env brew` (сработает в Terminal).
    private func resolveBrewInvocation() -> (executable: String, prefixArguments: [String]) {
        for path in Self.knownBrewPaths where executableChecker.isExecutableFile(atPath: path) {
            return (path, [])
        }
        return ("/usr/bin/env", ["brew"])
    }

    public func caskTokensByAppPath() async -> [String: String] {
        let (executable, prefixArguments) = resolveBrewInvocation()
        guard let tokenList = try? await commandRunner.output(
            executable, arguments: prefixArguments + ["list", "--cask", "-1"])
        else { return [:] }

        let tokens = tokenList.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        var result: [String: String] = [:]
        for token in tokens {
            guard let verbose = try? await commandRunner.output(
                executable, arguments: prefixArguments + ["list", "--cask", "--verbose", token])
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
