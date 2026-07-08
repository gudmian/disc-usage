import Foundation

public protocol SignatureChecking: Sendable {
    func isSigned(_ url: URL) -> Bool
}

/// Проверка подписи через codesign; ошибка запуска трактуется как «подписан»
/// (безопасный дефолт — не удалять).
public struct CodesignChecker: SignatureChecking {
    public init() {}

    public func isSigned(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = ["--verify", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return true
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

public struct LprojScanner: Sendable {
    private let applicationsDirectory: URL
    private let keptLanguages: Set<String>
    private let signatureChecker: any SignatureChecking
    private let sizer: any DirectorySizing

    public init(
        applicationsDirectory: URL = URL(filePath: "/Applications"),
        keptLanguages: Set<String> = LprojScanner.defaultKeptLanguages(),
        signatureChecker: any SignatureChecking = CodesignChecker(),
        sizer: any DirectorySizing = FileSystemSizer()
    ) {
        self.applicationsDirectory = applicationsDirectory
        self.keptLanguages = keptLanguages
        self.signatureChecker = signatureChecker
        self.sizer = sizer
    }

    public static func defaultKeptLanguages() -> Set<String> {
        var kept: Set<String> = ["Base", "en", "English"]
        for language in Locale.preferredLanguages {
            kept.insert(language)
            kept.insert(String(language.prefix(while: { $0 != "-" })))
        }
        return kept
    }

    public func scan() async -> [CleanupItem] {
        let fm = FileManager.default
        let apps = ((try? fm.contentsOfDirectory(
            at: applicationsDirectory, includingPropertiesForKeys: nil, options: [])) ?? [])
            .filter { $0.pathExtension == "app" }
        var items: [CleanupItem] = []
        for app in apps {
            let resources = app.appendingPathComponent("Contents/Resources")
            let lprojs = ((try? fm.contentsOfDirectory(
                at: resources, includingPropertiesForKeys: nil, options: [])) ?? [])
                .filter { $0.pathExtension == "lproj" }
            guard !lprojs.isEmpty else { continue }
            let unused = lprojs.filter {
                !keptLanguages.contains($0.deletingPathExtension().lastPathComponent)
            }
            guard !unused.isEmpty else { continue }
            let deletable = !signatureChecker.isSigned(app)
            for lproj in unused {
                let size = await sizer.size(of: lproj)
                items.append(CleanupItem(
                    rule: CleanupRules.localizations, url: lproj, size: size,
                    deletable: deletable))
            }
        }
        return items
    }
}
