import Foundation

public enum SafetyLevel: Sendable, Equatable {
    case safe
    case caution
}

public enum CleanupCategory: String, CaseIterable, Sendable {
    case systemJunk
    case developerJunk
    case browserData
    case miscellaneous
}

public struct PathPattern: Sendable {
    public enum Base: Sendable { case home, root }

    public let base: Base
    /// Компонент "*" раскрывается в любой один уровень вложенности.
    public let components: [String]

    public init(base: Base, components: [String]) {
        self.base = base
        self.components = components
    }
}

public struct CommandAction: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct CleanupRule: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let category: CleanupCategory
    public let safety: SafetyLevel
    public let pathPatterns: [PathPattern]
    /// Удалять содержимое директории, не саму директорию (item на каждого ребёнка).
    public let deleteContentsOnly: Bool
    /// Только безвозвратное удаление (очистка Корзины).
    public let permanentOnly: Bool
    public let enabledByDefault: Bool
    public let command: CommandAction?

    public init(
        id: String, title: String, category: CleanupCategory, safety: SafetyLevel,
        pathPatterns: [PathPattern], deleteContentsOnly: Bool = false,
        permanentOnly: Bool = false, enabledByDefault: Bool = true,
        command: CommandAction? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.safety = safety
        self.pathPatterns = pathPatterns
        self.deleteContentsOnly = deleteContentsOnly
        self.permanentOnly = permanentOnly
        self.enabledByDefault = enabledByDefault
        self.command = command
    }
}

public struct CleanupItem: Sendable, Identifiable, Equatable {
    public let id: String
    public let ruleID: String
    public let title: String
    public let category: CleanupCategory
    public let safety: SafetyLevel
    public let url: URL?
    public let size: Int64
    public let permanentOnly: Bool
    public let enabledByDefault: Bool
    /// false — только просмотр (например, .lproj подписанного приложения).
    public let deletable: Bool
    public let command: CommandAction?

    public init(
        rule: CleanupRule, url: URL?, size: Int64,
        command: CommandAction? = nil, deletable: Bool = true
    ) {
        self.id = rule.id + ":" + (url?.path ?? "command")
        self.ruleID = rule.id
        self.title = url?.lastPathComponent ?? rule.title
        self.category = rule.category
        self.safety = rule.safety
        self.url = url
        self.size = size
        self.permanentOnly = rule.permanentOnly
        self.enabledByDefault = rule.enabledByDefault
        self.deletable = deletable
        self.command = command
    }
}
