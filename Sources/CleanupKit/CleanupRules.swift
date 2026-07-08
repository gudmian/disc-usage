import Foundation

public enum CleanupRules {
    public static let all: [CleanupRule] =
        systemJunk + developerJunk + browserData + miscellaneous

    public static let localizations = CleanupRule(
        id: "misc.lproj", title: "Неиспользуемые локализации",
        category: .miscellaneous, safety: .caution,
        pathPatterns: [], enabledByDefault: false)

    static let systemJunk: [CleanupRule] = [
        CleanupRule(
            id: "system.userCaches", title: "Кэши приложений",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "system.userLogs", title: "Логи приложений",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Logs"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "system.sharedCaches", title: "Общие кэши (/Library/Caches)",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .root, components: ["Library", "Caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "system.trash", title: "Корзина",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: [".Trash"])],
            deleteContentsOnly: true, permanentOnly: true),
        CleanupRule(
            id: "system.tmp", title: "Временные файлы (/private/tmp)",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .root, components: ["private", "tmp"])],
            deleteContentsOnly: true),
    ]

    static let developerJunk: [CleanupRule] = [
        CleanupRule(
            id: "dev.derivedData", title: "Xcode DerivedData",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "DerivedData"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.iosDeviceSupport", title: "iOS DeviceSupport",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "iOS DeviceSupport"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.watchosDeviceSupport", title: "watchOS DeviceSupport",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "watchOS DeviceSupport"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.simulatorCaches", title: "Кэши симуляторов",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "CoreSimulator", "Caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.unavailableSimulators", title: "Недоступные симуляторы",
            category: .developerJunk, safety: .safe, pathPatterns: [],
            command: CommandAction(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "delete", "unavailable"])),
        CleanupRule(
            id: "dev.spmCache", title: "Кэш Swift Package Manager",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "org.swift.swiftpm"])]),
        CleanupRule(
            id: "dev.cocoapodsCache", title: "Кэш CocoaPods",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "CocoaPods"])]),
        CleanupRule(
            id: "dev.gradleCache", title: "Кэш Gradle",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: [".gradle", "caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.npmCache", title: "Кэш npm",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: [".npm", "_cacache"])]),
        CleanupRule(
            id: "dev.homebrewCache", title: "Кэш Homebrew",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "Homebrew"])]),
        CleanupRule(
            id: "dev.xcodeArchives", title: "Xcode Archives (dSYM релизов!)",
            category: .developerJunk, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "Archives"])],
            deleteContentsOnly: true, enabledByDefault: false),
    ]

    static let browserData: [CleanupRule] = [
        CleanupRule(
            id: "browser.safariCache", title: "Кэш Safari",
            category: .browserData, safety: .caution,
            pathPatterns: [
                PathPattern(base: .home, components: ["Library", "Caches", "com.apple.Safari"]),
                PathPattern(base: .home, components: ["Library", "Containers", "com.apple.Safari", "Data", "Library", "Caches"]),
            ]),
        CleanupRule(
            id: "browser.chromeCache", title: "Кэш Chrome",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "Google", "Chrome"])]),
        CleanupRule(
            id: "browser.arcCache", title: "Кэш Arc",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "company.thebrowser.Browser"])]),
        CleanupRule(
            id: "browser.firefoxCache", title: "Кэш Firefox",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "Firefox", "Profiles", "*", "cache2"])]),
        CleanupRule(
            id: "browser.safariHistory", title: "История Safari",
            category: .browserData, safety: .caution,
            pathPatterns: [
                PathPattern(base: .home, components: ["Library", "Safari", "History.db"]),
                PathPattern(base: .home, components: ["Library", "Safari", "History.db-wal"]),
                PathPattern(base: .home, components: ["Library", "Safari", "History.db-shm"]),
            ],
            enabledByDefault: false),
        CleanupRule(
            id: "browser.chromeHistory", title: "История Chrome",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Application Support", "Google", "Chrome", "*", "History"])],
            enabledByDefault: false),
        CleanupRule(
            id: "browser.cookies", title: "Cookies (системное хранилище)",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Cookies"])],
            deleteContentsOnly: true, enabledByDefault: false),
        CleanupRule(
            id: "browser.chromeCookies", title: "Cookies Chrome",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Application Support", "Google", "Chrome", "*", "Cookies"])],
            enabledByDefault: false),
    ]

    static let miscellaneous: [CleanupRule] = [
        CleanupRule(
            id: "misc.iosBackups", title: "Резервные копии iOS",
            category: .miscellaneous, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Application Support", "MobileSync", "Backup"])],
            deleteContentsOnly: true, enabledByDefault: false),
        CleanupRule(
            id: "misc.mailDownloads", title: "Вложения Mail",
            category: .miscellaneous, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Containers", "com.apple.mail", "Data", "Library", "Mail Downloads"])],
            deleteContentsOnly: true, enabledByDefault: false),
    ]
}
