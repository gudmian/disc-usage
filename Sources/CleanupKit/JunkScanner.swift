import Foundation

public struct JunkScanner: Sendable {
    private let environment: CleanupEnvironment
    private let sizer: any DirectorySizing

    public init(
        environment: CleanupEnvironment = .live,
        sizer: any DirectorySizing = FileSystemSizer()
    ) {
        self.environment = environment
        self.sizer = sizer
    }

    public func scan(rules: [CleanupRule] = CleanupRules.all) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for rule in rules {
            if let command = rule.command {
                items.append(CleanupItem(rule: rule, url: nil, size: 0, command: command))
                continue
            }
            for pattern in rule.pathPatterns {
                let resolved = PathResolver.resolve(pattern, environment: environment)
                let targets: [URL]
                if rule.deleteContentsOnly {
                    targets = resolved.flatMap { url in
                        (try? FileManager.default.contentsOfDirectory(
                            at: url, includingPropertiesForKeys: nil, options: [])) ?? []
                    }
                } else {
                    targets = resolved
                }
                for target in targets {
                    let size = await sizer.size(of: target)
                    items.append(CleanupItem(rule: rule, url: target, size: size))
                }
            }
        }
        return CleanupPlanner.deduplicate(items)
    }
}

public enum CleanupPlanner {
    /// Убирает точные дубли путей и элементы, вложенные в другие элементы.
    public static func deduplicate(_ items: [CleanupItem]) -> [CleanupItem] {
        let allPaths = Set(items.compactMap { $0.url?.path })
        var seen = Set<String>()
        return items.filter { item in
            guard let url = item.url else { return true }
            var parent = url.deletingLastPathComponent()
            while parent.path.count > 1 {
                if allPaths.contains(parent.path) { return false }
                parent = parent.deletingLastPathComponent()
            }
            return seen.insert(url.path).inserted
        }
    }
}
