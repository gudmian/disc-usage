import Testing
import ScanKit
@testable import DiscUsageUI

private func sampleTree() -> FileNode {
    FileNode(directoryNamed: "root", children: [
        FileNode(fileNamed: "big.mov", size: 200_000_000),
        FileNode(fileNamed: "mid.dmg", size: 80_000_000),
        FileNode(fileNamed: "small.txt", size: 1_000),
    ])
}

@MainActor @Test func refreshFiltersByMinimumSizeAndPrunesSelection() {
    let viewModel = LargeFilesViewModel()
    viewModel.minimumSize = 50_000_000

    viewModel.refresh(root: sampleTree(), rootPath: "/")
    #expect(viewModel.entries.map(\.path) == ["/big.mov", "/mid.dmg"])

    viewModel.selectedPaths = ["/big.mov", "/mid.dmg"]
    #expect(viewModel.selectedTotalBytes == 280_000_000)
    #expect(viewModel.entriesToDelete().count == 2)

    viewModel.minimumSize = 100_000_000
    viewModel.refresh(root: sampleTree(), rootPath: "/")
    #expect(viewModel.entries.map(\.path) == ["/big.mov"])
    // выбор чистится от исчезнувших записей
    #expect(viewModel.selectedPaths == ["/big.mov"])

    viewModel.refresh(root: nil, rootPath: "/")
    #expect(viewModel.entries.isEmpty)
    #expect(viewModel.selectedPaths.isEmpty)
}
