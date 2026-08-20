import AppKit

public protocol RunningApplicationsProviding: Sendable {
    func runningBundleIdentifiers() -> Set<String>
}

public struct SystemRunningApplicationsProvider: RunningApplicationsProviding {
    public init() {}

    public func runningBundleIdentifiers() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}
