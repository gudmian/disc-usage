import Foundation

public protocol FileRemoving: Sendable {
    func trash(_ url: URL) throws
    func removePermanently(_ url: URL) throws
}

public struct SystemFileRemover: FileRemoving {
    public init() {}

    public func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public func removePermanently(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

public protocol ProcessRunning: Sendable {
    @discardableResult
    func run(_ executable: String, arguments: [String]) throws -> Int32
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    @discardableResult
    public func run(_ executable: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

public struct CleanupFailure: Sendable {
    public let item: CleanupItem
    public let message: String

    public init(item: CleanupItem, message: String) {
        self.item = item
        self.message = message
    }
}

public struct CleanupReport: Sendable {
    public let deleted: [CleanupItem]
    public let failed: [CleanupFailure]

    public var freedBytes: Int64 { deleted.reduce(0) { $0 + $1.size } }

    public init(deleted: [CleanupItem], failed: [CleanupFailure]) {
        self.deleted = deleted
        self.failed = failed
    }
}

enum CleanupError: LocalizedError {
    case commandFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let status): "команда завершилась с кодом \(status)"
        }
    }
}

public struct CleanupExecutor: Sendable {
    private let remover: any FileRemoving
    private let processRunner: any ProcessRunning

    public init(
        remover: any FileRemoving = SystemFileRemover(),
        processRunner: any ProcessRunning = SystemProcessRunner()
    ) {
        self.remover = remover
        self.processRunner = processRunner
    }

    public func execute(items: [CleanupItem], permanently: Bool) async -> CleanupReport {
        var deleted: [CleanupItem] = []
        var failed: [CleanupFailure] = []
        for item in items {
            guard item.deletable else {
                failed.append(CleanupFailure(item: item, message: "элемент только для просмотра"))
                continue
            }
            do {
                if let command = item.command {
                    let status = try processRunner.run(command.executable, arguments: command.arguments)
                    guard status == 0 else { throw CleanupError.commandFailed(status) }
                } else if let url = item.url {
                    if permanently || item.permanentOnly {
                        try remover.removePermanently(url)
                    } else {
                        try remover.trash(url)
                    }
                }
                deleted.append(item)
            } catch {
                failed.append(CleanupFailure(item: item, message: error.localizedDescription))
            }
        }
        return CleanupReport(deleted: deleted, failed: failed)
    }
}
