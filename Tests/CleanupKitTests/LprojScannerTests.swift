import Foundation
import Testing
@testable import CleanupKit

private struct StubSignatureChecker: SignatureChecking {
    let signedPaths: Set<String>
    func isSigned(_ url: URL) -> Bool { signedPaths.contains(url.path) }
}

@Test func reportsUnusedLprojAndRespectsSignature() async throws {
    let apps = try Fixture.makeTree([
        "Signed.app/Contents/Resources/ru.lproj/Localizable.strings": 1_000,
        "Signed.app/Contents/Resources/de.lproj/Localizable.strings": 1_000,
        "Unsigned.app/Contents/Resources/fr.lproj/Localizable.strings": 1_000,
        "Unsigned.app/Contents/Resources/en.lproj/Localizable.strings": 1_000,
    ])
    defer { try? FileManager.default.removeItem(at: apps) }

    let scanner = LprojScanner(
        applicationsDirectory: apps,
        keptLanguages: ["Base", "en", "ru"],
        signatureChecker: StubSignatureChecker(
            signedPaths: [apps.appendingPathComponent("Signed.app").path]))
    let items = await scanner.scan()

    // ru и en — в keptLanguages, поэтому только de (signed) и fr (unsigned)
    #expect(items.count == 2)
    let de = try #require(items.first { $0.url?.lastPathComponent == "de.lproj" })
    #expect(de.deletable == false)
    let fr = try #require(items.first { $0.url?.lastPathComponent == "fr.lproj" })
    #expect(fr.deletable == true)
    #expect(items.allSatisfy { $0.ruleID == "misc.lproj" })
    #expect(items.allSatisfy { $0.size > 0 })
}

@Test func defaultKeptLanguagesIncludeBaseEnglishAndPreferred() {
    let kept = LprojScanner.defaultKeptLanguages()
    #expect(kept.contains("Base"))
    #expect(kept.contains("en"))
}
