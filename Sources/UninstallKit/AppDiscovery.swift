import CleanupKit
import Foundation

public struct AppDiscoveryProgress: Sendable {
    public let scanned: Int
    public let total: Int

    public init(scanned: Int, total: Int) {
        self.scanned = scanned
        self.total = total
    }
}

public struct AppDiscoveryResult: Sendable {
    public let apps: [AppInfo]
    public let unreadableDirectories: [URL]

    public init(apps: [AppInfo], unreadableDirectories: [URL]) {
        self.apps = apps
        self.unreadableDirectories = unreadableDirectories
    }
}

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

    public func scan(
        onProgress: (@Sendable (AppDiscoveryProgress) -> Void)? = nil
    ) async -> AppDiscoveryResult {
        let runningIDs = runningProvider.runningBundleIdentifiers()
        var appURLs: [URL] = []
        var unreadableDirectories: [URL] = []
        for directory in directories {
            // Отсутствие директории (например, у большинства пользователей нет ~/Applications) —
            // это норма, не ошибка. А вот "есть, но прочитать не вышло" — стоит показать в UI,
            // а не тихо прятать, как раньше делал `try?`.
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            do {
                let entries = try FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: nil, options: [])
                appURLs.append(contentsOf: entries.filter { $0.pathExtension == "app" })
            } catch {
                unreadableDirectories.append(directory)
            }
        }

        let total = appURLs.count
        let sizer = self.sizer
        let apps: [AppInfo] = await withTaskGroup(of: AppInfo.self) { group in
            for url in appURLs {
                group.addTask {
                    let bundle = Bundle(url: url)
                    let info = bundle?.infoDictionary
                    let displayName = (info?["CFBundleDisplayName"] as? String)
                        ?? (info?["CFBundleName"] as? String)
                        ?? url.deletingPathExtension().lastPathComponent
                    let bundleIdentifier = bundle?.bundleIdentifier
                    let size = await sizer.size(of: url)
                    return AppInfo(
                        url: url, displayName: displayName, bundleIdentifier: bundleIdentifier,
                        size: size, isRunning: bundleIdentifier.map(runningIDs.contains) ?? false,
                        homebrewToken: nil)
                }
            }
            var results: [AppInfo] = []
            results.reserveCapacity(total)
            var scanned = 0
            for await appInfo in group {
                results.append(appInfo)
                scanned += 1
                onProgress?(AppDiscoveryProgress(scanned: scanned, total: total))
            }
            return results
        }
        return AppDiscoveryResult(apps: apps, unreadableDirectories: unreadableDirectories)
    }
}
