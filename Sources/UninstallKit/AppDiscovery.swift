import CleanupKit
import Foundation

public struct AppDiscovery: Sendable {
    private let directories: [URL]
    private let sizer: any DirectorySizing
    private let runningProvider: any RunningApplicationsProviding

    public init(
        directories: [URL] = [
            URL(filePath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ],
        sizer: any DirectorySizing = FileSystemSizer(),
        runningProvider: any RunningApplicationsProviding = SystemRunningApplicationsProvider()
    ) {
        self.directories = directories
        self.sizer = sizer
        self.runningProvider = runningProvider
    }

    public func scan() async -> [AppInfo] {
        let runningIDs = runningProvider.runningBundleIdentifiers()
        var apps: [AppInfo] = []
        for directory in directories {
            let entries = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: [])) ?? []
            for url in entries where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                let info = bundle?.infoDictionary
                let displayName = (info?["CFBundleDisplayName"] as? String)
                    ?? (info?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let bundleIdentifier = bundle?.bundleIdentifier
                let size = await sizer.size(of: url)
                apps.append(AppInfo(
                    url: url, displayName: displayName, bundleIdentifier: bundleIdentifier,
                    size: size, isRunning: bundleIdentifier.map(runningIDs.contains) ?? false,
                    homebrewToken: nil))
            }
        }
        return apps
    }
}
