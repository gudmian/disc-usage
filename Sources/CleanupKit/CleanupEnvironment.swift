import Foundation

public struct CleanupEnvironment: Sendable {
    public let homeDirectory: URL
    public let rootDirectory: URL

    public init(homeDirectory: URL, rootDirectory: URL) {
        self.homeDirectory = homeDirectory
        self.rootDirectory = rootDirectory
    }

    public static let live = CleanupEnvironment(
        homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
        rootDirectory: URL(filePath: "/"))
}
