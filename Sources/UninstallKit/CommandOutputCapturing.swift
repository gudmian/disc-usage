import Foundation

public protocol CommandOutputCapturing: Sendable {
    func output(_ executable: String, arguments: [String]) async throws -> String
}

public struct SystemCommandOutputCapturing: CommandOutputCapturing {
    public init() {}

    public func output(_ executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        // Читаем до waitUntilExit — иначе на большом выводе процесс блокируется
        // на записи в заполненный pipe-буфер (классический deadlock Process+Pipe).
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
