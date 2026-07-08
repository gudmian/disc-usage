import Testing
@testable import ScanKit

@Test func topFilesSortedFilteredAndLimited() {
    let tree = FileNode(directoryNamed: "root", children: [
        FileNode(directoryNamed: "movies", children: [
            FileNode(fileNamed: "raw.mov", size: 5_000),
            FileNode(fileNamed: "clip.mov", size: 3_000),
        ]),
        FileNode(directoryNamed: "tiny", children: [
            FileNode(fileNamed: "small.txt", size: 10)
        ]),
        FileNode(fileNamed: "iso.dmg", size: 4_000),
    ])

    let top = LargeFileCollector.topFiles(in: tree, rootPath: "/", minimumSize: 1_000)
    #expect(top.map(\.path) == ["/movies/raw.mov", "/iso.dmg", "/movies/clip.mov"])
    #expect(top.first?.size == 5_000)

    let limited = LargeFileCollector.topFiles(in: tree, rootPath: "/", limit: 2, minimumSize: 1_000)
    #expect(limited.count == 2)

    let subPath = LargeFileCollector.topFiles(in: tree, rootPath: "/data", minimumSize: 4_000)
    #expect(subPath.map(\.path) == ["/data/movies/raw.mov", "/data/iso.dmg"])
}
