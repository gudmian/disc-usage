import Testing
@testable import UninstallKit

@Test func systemCheckerRecognizesRealExecutable() {
    #expect(SystemExecutableFileChecking().isExecutableFile(atPath: "/bin/ls") == true)
}

@Test func systemCheckerRejectsNonexistentPath() {
    #expect(SystemExecutableFileChecking().isExecutableFile(atPath: "/nonexistent/discusage-binary") == false)
}
