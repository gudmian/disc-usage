import Foundation
import Testing
@testable import UninstallKit

@Test func ownFileIsOwnedByCurrentUser() throws {
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("discusage-ownership-\(UUID().uuidString).txt")
    try Data("x".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    #expect(SystemFileOwnershipChecking().isOwnedByCurrentUser(file) == true)
}

@Test func missingPathDefaultsToOwnedToAvoidFalsePositiveBlocking() {
    let missing = URL(filePath: "/nonexistent/discusage-ownership-check")
    #expect(SystemFileOwnershipChecking().isOwnedByCurrentUser(missing) == true)
}
