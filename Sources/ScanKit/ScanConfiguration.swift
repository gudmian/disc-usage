import Foundation

public struct ScanConfiguration: Sendable {
    public let rootURL: URL
    public let excludedPaths: Set<String>

    public init(rootURL: URL, excludedPaths: Set<String> = []) {
        self.rootURL = rootURL
        self.excludedPaths = Set(excludedPaths.map { ($0 as NSString).standardizingPath })
    }

    /// Скан всего диска: исключены firmlink-точки APFS (иначе двойной счёт),
    /// внешние тома и /dev.
    public static func wholeDisk() -> ScanConfiguration {
        ScanConfiguration(rootURL: URL(filePath: "/"), excludedPaths: [
            "/System/Volumes/Data",
            "/System/Volumes/Preboot",
            "/System/Volumes/VM",
            "/System/Volumes/Update",
            "/System/Volumes/Hardware",
            "/System/Volumes/iSCPreboot",
            "/System/Volumes/xarts",
            "/Volumes",
            "/dev",
        ])
    }

    public func isExcluded(_ url: URL) -> Bool {
        excludedPaths.contains(url.standardizedFileURL.path)
    }
}
