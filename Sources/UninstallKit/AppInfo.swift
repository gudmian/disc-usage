import Foundation

public struct AppInfo: Sendable, Identifiable, Equatable {
    public let url: URL
    public let displayName: String
    public let bundleIdentifier: String?
    public let size: Int64
    public let isRunning: Bool
    public let homebrewToken: String?

    public var id: String { bundleIdentifier ?? url.path }

    public init(
        url: URL, displayName: String, bundleIdentifier: String?,
        size: Int64, isRunning: Bool, homebrewToken: String?
    ) {
        self.url = url
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.size = size
        self.isRunning = isRunning
        self.homebrewToken = homebrewToken
    }

    public func withHomebrewToken(_ token: String?) -> AppInfo {
        AppInfo(
            url: url, displayName: displayName, bundleIdentifier: bundleIdentifier,
            size: size, isRunning: isRunning, homebrewToken: token)
    }
}
