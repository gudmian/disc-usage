import Foundation

public protocol ExecutableFileChecking: Sendable {
    func isExecutableFile(atPath path: String) -> Bool
}

public struct SystemExecutableFileChecking: ExecutableFileChecking {
    public init() {}

    public func isExecutableFile(atPath path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}
