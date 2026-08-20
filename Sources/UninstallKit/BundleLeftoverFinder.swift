import CleanupKit
import Foundation

public struct BundleLeftoverFinder: Sendable {
    private let environment: CleanupEnvironment
    private let sizer: any DirectorySizing
    private let commandRunner: any CommandOutputCapturing
    private let ownership: any FileOwnershipChecking

    public init(
        environment: CleanupEnvironment = .live,
        sizer: any DirectorySizing = FileSystemSizer(),
        commandRunner: any CommandOutputCapturing = SystemCommandOutputCapturing(),
        ownership: any FileOwnershipChecking = SystemFileOwnershipChecking()
    ) {
        self.environment = environment
        self.sizer = sizer
        self.commandRunner = commandRunner
        self.ownership = ownership
    }

    /// Типовые пути, жёстко ключуемые macOS по bundle ID (не по имени приложения — см. спеку).
    private static func typedTemplates(bundleID: String) -> [(id: String, components: [String], safety: SafetyLevel)] {
        [
            ("preferences", ["Library", "Preferences", "\(bundleID).plist"], .caution),
            ("caches", ["Library", "Caches", bundleID], .safe),
            ("savedState", ["Library", "Saved Application State", "\(bundleID).savedState"], .safe),
            ("httpStorages", ["Library", "HTTPStorages", bundleID], .safe),
            ("webkit", ["Library", "WebKit", bundleID], .safe),
            ("containers", ["Library", "Containers", bundleID], .caution),
        ]
    }

    public func findLeftovers(for app: AppInfo) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        items.append(makeItem(
            id: "app.\(app.id).bundle", title: app.displayName, url: app.url, size: app.size,
            safety: .caution, enabledByDefault: true))

        guard let bundleID = app.bundleIdentifier else {
            return CleanupPlanner.deduplicate(items)
        }

        for template in Self.typedTemplates(bundleID: bundleID) {
            let pattern = PathPattern(base: .home, components: template.components)
            for url in PathResolver.resolve(pattern, environment: environment) {
                let size = await sizer.size(of: url)
                items.append(makeItem(
                    id: "app.\(bundleID).\(template.id)", title: url.lastPathComponent,
                    url: url, size: size, safety: template.safety, enabledByDefault: true))
            }
        }

        if let output = try? await commandRunner.output(
            "/usr/bin/mdfind", arguments: ["kMDItemCFBundleIdentifier == '\(bundleID)'"])
        {
            for line in output.split(separator: "\n") {
                let path = String(line)
                guard !path.isEmpty else { continue }
                let url = URL(filePath: path)
                let size = await sizer.size(of: url)
                items.append(makeItem(
                    id: "app.\(bundleID).mdfind", title: url.lastPathComponent,
                    url: url, size: size, safety: .caution, enabledByDefault: false))
            }
        }

        return CleanupPlanner.deduplicate(items).map { item in
            guard let url = item.url, !ownership.isOwnedByCurrentUser(url) else { return item }
            return makeItem(
                id: item.ruleID, title: item.title, url: url, size: item.size,
                safety: item.safety, enabledByDefault: item.enabledByDefault, deletable: false)
        }
    }

    private func makeItem(
        id: String, title: String, url: URL, size: Int64,
        safety: SafetyLevel, enabledByDefault: Bool, deletable: Bool = true
    ) -> CleanupItem {
        let rule = CleanupRule(
            id: id, title: title, category: .appLeftovers, safety: safety,
            pathPatterns: [], enabledByDefault: enabledByDefault)
        return CleanupItem(rule: rule, url: url, size: size, deletable: deletable)
    }
}
