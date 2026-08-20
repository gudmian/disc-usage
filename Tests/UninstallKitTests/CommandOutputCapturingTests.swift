import Foundation
import Testing
@testable import UninstallKit

@Test func systemCapturingReturnsProcessStdout() async throws {
    let capturing = SystemCommandOutputCapturing()
    let output = try await capturing.output("/bin/echo", arguments: ["hello", "world"])
    #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello world")
}
