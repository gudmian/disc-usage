import Foundation

/// FDA есть, если хотя бы один из защищённых путей читается.
public struct FullDiskAccessChecker: Sendable {
    private let probePaths: [String]

    public init(probePaths: [String] = [
        NSHomeDirectory() + "/Library/Safari",
        NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
    ]) {
        self.probePaths = probePaths
    }

    public func hasFullDiskAccess() -> Bool {
        for path in probePaths {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                continue
            }
            if isDirectory.boolValue {
                if (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil {
                    return true
                }
            } else if FileHandle(forReadingAtPath: path) != nil {
                return true
            }
        }
        return false
    }
}
