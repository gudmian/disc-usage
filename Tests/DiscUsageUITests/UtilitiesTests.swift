import Foundation
import Testing
import ScanKit
@testable import DiscUsageUI

@Test func byteFormatterProducesHumanReadableString() {
    let formatted = ByteFormatter.string(1_500_000_000)
    #expect(!formatted.isEmpty)
    #expect(ByteFormatter.string(0).contains("0"))
}

@Test func nodeColorCategorizesByExtensionAndKind() {
    #expect(NodeColor.category(for: FileNode(fileNamed: "movie.mp4", size: 1)) == .media)
    #expect(NodeColor.category(for: FileNode(fileNamed: "main.swift", size: 1)) == .code)
    #expect(NodeColor.category(for: FileNode(fileNamed: "backup.zip", size: 1)) == .archive)
    #expect(NodeColor.category(for: FileNode(fileNamed: "report.pdf", size: 1)) == .document)
    #expect(NodeColor.category(for: FileNode(fileNamed: "data.xyz123", size: 1)) == .other)
    #expect(NodeColor.category(for: FileNode(directoryNamed: "Caches", children: [])) == .caches)
    #expect(NodeColor.category(for: FileNode(directoryNamed: "Docs", children: [])) == .directory)
}

@Test func fdaCheckerProbesPaths() throws {
    let readable = FileManager.default.temporaryDirectory
        .appendingPathComponent("fda-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: readable, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: readable) }

    #expect(FullDiskAccessChecker(probePaths: [readable.path]).hasFullDiskAccess())
    #expect(!FullDiskAccessChecker(probePaths: ["/nonexistent-\(UUID().uuidString)"]).hasFullDiskAccess())
}
