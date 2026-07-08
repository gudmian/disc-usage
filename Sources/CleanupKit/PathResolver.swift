import Foundation

public enum PathResolver {
    /// Раскрывает шаблон в существующие пути. "*" — любой один уровень.
    public static func resolve(_ pattern: PathPattern, environment: CleanupEnvironment) -> [URL] {
        let base = pattern.base == .home ? environment.homeDirectory : environment.rootDirectory
        var current = [base]
        for component in pattern.components {
            var next: [URL] = []
            for url in current {
                if component == "*" {
                    let children = (try? FileManager.default.contentsOfDirectory(
                        at: url, includingPropertiesForKeys: nil, options: [])) ?? []
                    next.append(contentsOf: children)
                } else {
                    let candidate = url.appendingPathComponent(component)
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        next.append(candidate)
                    }
                }
            }
            current = next
        }
        return current.sorted { $0.path < $1.path }
    }
}
