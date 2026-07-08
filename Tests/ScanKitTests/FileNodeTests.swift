import Testing
@testable import ScanKit

@Test func directorySumsAndSortsChildren() {
    let dir = FileNode(directoryNamed: "root", children: [
        FileNode(fileNamed: "small.txt", size: 10),
        FileNode(fileNamed: "big.mov", size: 1_000),
        FileNode(directoryNamed: "sub", children: [FileNode(fileNamed: "mid.dat", size: 100)]),
    ])
    #expect(dir.size == 1_110)
    #expect(dir.kind == .directory)
    #expect(dir.children.map(\.name) == ["big.mov", "sub", "small.txt"])
}

@Test func childLookupAndKinds() {
    let locked = FileNode(inaccessibleDirectoryNamed: "locked")
    let dir = FileNode(directoryNamed: "root", children: [locked])
    #expect(locked.kind == .inaccessibleDirectory)
    #expect(locked.size == 0)
    #expect(dir.child(named: "locked") === locked)
    #expect(dir.child(named: "nope") == nil)
}
