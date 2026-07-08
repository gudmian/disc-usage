# DiscUsage v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS-приложение: анализ всего диска (treemap + большие файлы) и безопасная очистка мусора по белому списку правил.

**Architecture:** SPM-пакет с тремя библиотеками (ScanKit — скан диска, CleanupKit — правила и удаление, DiscUsageUI — SwiftUI) и исполняемым таргетом; .app-бандл собирается скриптом. Спека: `docs/superpowers/specs/2026-07-08-discusage-design.md`.

**Tech Stack:** Swift 6 (tools 6.0, strict concurrency), SwiftUI, Swift Testing (`import Testing`, НЕ XCTest), macOS 15+. Без внешних зависимостей.

## Global Constraints

- Swift 6 strict concurrency; платформа macOS 15+; никаких внешних зависимостей.
- Тесты — Swift Testing (`@Test`, `#expect`, `#require`); запуск `swift test` из корня репо.
- Все строки UI — на русском.
- Удаление файлов ТОЛЬКО через протокол `FileRemoving`; по умолчанию в Корзину; навсегда — только по явному флагу; правила очистки — только белый список путей.
- История/cookies браузеров, iOS-бэкапы, вложения Mail, Xcode Archives: `enabledByDefault: false`.
- `.lproj` из подписанных бандлов не удаляем (`deletable: false`).
- TDD: каждый таск = тест → FAIL → код → PASS → commit. В компилируемом языке «FAIL» на шаге 2 обычно = ошибка компиляции «cannot find X in scope» — это ожидаемо.
- Коммиты — conventional commits (`feat:`, `test:`, `docs:`, `chore:`); перед каждым коммитом `swift test` зелёный.

## File Map

```
Package.swift                        (T1)
.gitignore                           (T1)
Sources/ScanKit/FileNode.swift       (T2)
Sources/ScanKit/ScanConfiguration.swift (T3)
Sources/ScanKit/ScanProgress.swift   (T4)
Sources/ScanKit/ScanContext.swift    (T4; прогресс+inaccessible)
Sources/ScanKit/HardLinkRegistry.swift (T5)
Sources/ScanKit/DiskScanner.swift    (T4, доп. T5/T6)
Sources/ScanKit/TreeRebuilder.swift  (T6)
Sources/ScanKit/LargeFileCollector.swift (T7)
Sources/CleanupKit/CleanupEnvironment.swift (T8)
Sources/CleanupKit/CleanupModels.swift (T8)
Sources/CleanupKit/PathResolver.swift (T8)
Sources/CleanupKit/CleanupRules.swift (T9)
Sources/CleanupKit/DirectorySizing.swift (T9)
Sources/CleanupKit/JunkScanner.swift (T9; + CleanupPlanner)
Sources/CleanupKit/LprojScanner.swift (T10; + SignatureChecking)
Sources/CleanupKit/CleanupExecutor.swift (T11; + FileRemoving/ProcessRunning)
Sources/DiscUsageUI/TreemapLayout.swift (T12)
Sources/DiscUsageUI/ByteFormatter.swift (T13)
Sources/DiscUsageUI/NodeColor.swift  (T13)
Sources/DiscUsageUI/FullDiskAccessChecker.swift (T13)
Sources/DiscUsageUI/AppState.swift   (T14)
Sources/DiscUsageUI/RootView.swift   (T15, правится в T18)
Sources/DiscUsageUI/MainSplitView.swift (T15)
Sources/DiscUsageUI/OverviewView.swift (T15)
Sources/DiscUsageUI/TreemapView.swift (T15)
Sources/DiscUsageUI/LargeFilesViewModel.swift (T16)
Sources/DiscUsageUI/LargeFilesView.swift (T16)
Sources/DiscUsageUI/CleanupViewModel.swift (T17)
Sources/DiscUsageUI/CleanupView.swift (T17)
Sources/DiscUsageUI/OnboardingView.swift (T18)
Sources/DiscUsage/DiscUsageApp.swift (T1, правится в T15)
Scripts/build-app.sh, Scripts/Info.plist, README.md (T18)
Tests/ScanKitTests/*, Tests/CleanupKitTests/*, Tests/DiscUsageUITests/*
```

---

### Task 1: SPM-скаффолд

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/ScanKit/ScanKitInfo.swift`, `Sources/CleanupKit/CleanupKitInfo.swift`, `Sources/DiscUsageUI/DiscUsageUIInfo.swift`, `Sources/DiscUsage/DiscUsageApp.swift`, `Tests/ScanKitTests/SmokeTests.swift`

**Interfaces:**
- Produces: собирающийся пакет с таргетами `ScanKit`, `CleanupKit`, `DiscUsageUI`, `DiscUsage` (exe) и тремя тест-таргетами.

- [ ] **Step 1: Написать Package.swift и заготовки**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiscUsage",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "ScanKit"),
        .target(name: "CleanupKit", dependencies: ["ScanKit"]),
        .target(name: "DiscUsageUI", dependencies: ["ScanKit", "CleanupKit"]),
        .executableTarget(name: "DiscUsage", dependencies: ["DiscUsageUI"]),
        .testTarget(name: "ScanKitTests", dependencies: ["ScanKit"]),
        .testTarget(name: "CleanupKitTests", dependencies: ["CleanupKit"]),
        .testTarget(name: "DiscUsageUITests", dependencies: ["DiscUsageUI"]),
    ]
)
```

`.gitignore`:

```
.build/
build/
.swiftpm/
.DS_Store
```

`Sources/ScanKit/ScanKitInfo.swift` (аналогично `CleanupKitInfo.swift`, `DiscUsageUIInfo.swift` — замени имя):

```swift
public enum ScanKitInfo {
    public static let version = "0.1.0"
}
```

`Sources/DiscUsage/DiscUsageApp.swift`:

```swift
import SwiftUI

@main
struct DiscUsageApp: App {
    var body: some Scene {
        WindowGroup { Text("DiscUsage") }
    }
}
```

`Tests/ScanKitTests/SmokeTests.swift`:

```swift
import Testing
@testable import ScanKit

@Test func packageCompiles() {
    #expect(ScanKitInfo.version == "0.1.0")
}
```

- [ ] **Step 2: Проверить сборку и тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, тест `packageCompiles` PASS.

- [ ] **Step 3: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "chore: SPM-скаффолд DiscUsage (ScanKit, CleanupKit, DiscUsageUI, exe)"
```

---

### Task 2: ScanKit — FileNode

**Files:**
- Create: `Sources/ScanKit/FileNode.swift`
- Test: `Tests/ScanKitTests/FileNodeTests.swift`

**Interfaces:**
- Produces: `FileNode` — immutable Sendable класс: `init(fileNamed:size:)`, `init(inaccessibleDirectoryNamed:)`, `init(directoryNamed:children:)` (сортирует детей по size desc и суммирует size), `child(named:) -> FileNode?`, `Kind { file, directory, inaccessibleDirectory }`, Identifiable (ObjectIdentifier), Equatable (===).

- [ ] **Step 1: Написать падающий тест**

`Tests/ScanKitTests/FileNodeTests.swift`:

```swift
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
```

- [ ] **Step 2: Запустить — убедиться, что падает**

Run: `swift test --filter FileNodeTests`
Expected: FAIL / ошибка компиляции `cannot find 'FileNode' in scope`.

- [ ] **Step 3: Минимальная реализация**

`Sources/ScanKit/FileNode.swift`:

```swift
import Foundation

/// Узел дерева размеров. Иммутабелен после создания.
public final class FileNode: Sendable, Identifiable, Equatable {
    public enum Kind: Sendable, Equatable {
        case file
        case directory
        case inaccessibleDirectory
    }

    public let name: String
    public let kind: Kind
    /// Аллоцированные байты; для директорий — сумма детей.
    public let size: Int64
    /// Отсортированы по размеру по убыванию; пусто для файлов.
    public let children: [FileNode]

    public init(fileNamed name: String, size: Int64) {
        self.name = name
        self.kind = .file
        self.size = size
        self.children = []
    }

    public init(inaccessibleDirectoryNamed name: String) {
        self.name = name
        self.kind = .inaccessibleDirectory
        self.size = 0
        self.children = []
    }

    public init(directoryNamed name: String, children: [FileNode]) {
        self.name = name
        self.kind = .directory
        self.children = children.sorted { $0.size > $1.size }
        self.size = children.reduce(0) { $0 + $1.size }
    }

    public func child(named name: String) -> FileNode? {
        children.first { $0.name == name }
    }

    public static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs === rhs }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter FileNodeTests`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ScanKit/FileNode.swift Tests/ScanKitTests/FileNodeTests.swift
git commit -m "feat: FileNode — иммутабельное дерево размеров"
```

---

### Task 3: ScanKit — ScanConfiguration

**Files:**
- Create: `Sources/ScanKit/ScanConfiguration.swift`
- Test: `Tests/ScanKitTests/ScanConfigurationTests.swift`

**Interfaces:**
- Produces: `ScanConfiguration(rootURL:excludedPaths:)`, `.wholeDisk()`, `isExcluded(_ url: URL) -> Bool`.

- [ ] **Step 1: Написать падающий тест**

`Tests/ScanKitTests/ScanConfigurationTests.swift`:

```swift
import Foundation
import Testing
@testable import ScanKit

@Test func wholeDiskExcludesFirmlinksVolumesAndDev() {
    let config = ScanConfiguration.wholeDisk()
    #expect(config.rootURL.path == "/")
    #expect(config.isExcluded(URL(filePath: "/System/Volumes/Data")))
    #expect(config.isExcluded(URL(filePath: "/Volumes")))
    #expect(config.isExcluded(URL(filePath: "/dev")))
    #expect(!config.isExcluded(URL(filePath: "/Users")))
}

@Test func customExclusionsAreStandardized() {
    let config = ScanConfiguration(rootURL: URL(filePath: "/tmp"), excludedPaths: ["/tmp/skip/"])
    #expect(config.isExcluded(URL(filePath: "/tmp/skip")))
    #expect(!config.isExcluded(URL(filePath: "/tmp/keep")))
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'ScanConfiguration'`)

Run: `swift test --filter ScanConfigurationTests`

- [ ] **Step 3: Реализация**

`Sources/ScanKit/ScanConfiguration.swift`:

```swift
import Foundation

public struct ScanConfiguration: Sendable {
    public let rootURL: URL
    public let excludedPaths: Set<String>

    public init(rootURL: URL, excludedPaths: Set<String> = []) {
        self.rootURL = rootURL
        self.excludedPaths = Set(excludedPaths.map { ($0 as NSString).standardizingPath })
    }

    /// Скан всего диска: исключены firmlink-точки APFS (иначе двойной счёт),
    /// внешние тома и /dev.
    public static func wholeDisk() -> ScanConfiguration {
        ScanConfiguration(rootURL: URL(filePath: "/"), excludedPaths: [
            "/System/Volumes/Data",
            "/System/Volumes/Preboot",
            "/System/Volumes/VM",
            "/System/Volumes/Update",
            "/System/Volumes/Hardware",
            "/System/Volumes/iSCPreboot",
            "/System/Volumes/xarts",
            "/Volumes",
            "/dev",
        ])
    }

    public func isExcluded(_ url: URL) -> Bool {
        excludedPaths.contains(url.standardizedFileURL.path)
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter ScanConfigurationTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/ScanKit/ScanConfiguration.swift Tests/ScanKitTests/ScanConfigurationTests.swift
git commit -m "feat: ScanConfiguration с исключениями firmlink/Volumes/dev"
```

---

### Task 4: ScanKit — DiskScanner (базовый скан)

**Files:**
- Create: `Sources/ScanKit/ScanProgress.swift`, `Sources/ScanKit/ScanContext.swift`, `Sources/ScanKit/DiskScanner.swift`
- Test: `Tests/ScanKitTests/Fixture.swift`, `Tests/ScanKitTests/DiskScannerTests.swift`

**Interfaces:**
- Consumes: `FileNode`, `ScanConfiguration`.
- Produces: `ScanProgress(scannedItems:totalBytes:currentPath:)`; `ScanResult(root:inaccessiblePaths:)`; `DiskScanner(progressInterval: Int = 2048)` c `scan(configuration:onProgress:) async throws -> ScanResult` (`onProgress: (@Sendable (ScanProgress) -> Void)? = nil`). Внутренний `ScanContext` (счётчики + inaccessible, NSLock).

- [ ] **Step 1: Написать падающие тесты**

`Tests/ScanKitTests/Fixture.swift`:

```swift
import Foundation

enum Fixture {
    /// Создаёт временное дерево. Ключ — относительный путь; значение — байты файла.
    /// Ключ с завершающим "/" создаёт пустую директорию. Возвращает корень.
    static func makeTree(_ spec: [String: Int]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("discusage-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (relativePath, byteCount) in spec {
            let url = root.appendingPathComponent(relativePath)
            if relativePath.hasSuffix("/") {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(repeating: 0x61, count: byteCount).write(to: url)
            }
        }
        return root
    }

    /// Аллоцированный размер файла — как его должен посчитать сканер.
    static func allocatedSize(of url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
        return Int64(values.totalFileAllocatedSize ?? 0)
    }
}
```

`Tests/ScanKitTests/DiskScannerTests.swift`:

```swift
import Foundation
import Testing
@testable import ScanKit

@Test func scanBuildsTreeWithRolledUpSizes() async throws {
    let root = try Fixture.makeTree([
        "a/one.dat": 10_000, "a/two.dat": 20_000, "b/three.dat": 4_096, "empty/": 0,
    ])
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let a = try #require(result.root.child(named: "a"))
    let expectedA = try Fixture.allocatedSize(of: root.appendingPathComponent("a/one.dat"))
        + Fixture.allocatedSize(of: root.appendingPathComponent("a/two.dat"))
    #expect(a.size == expectedA)
    #expect(a.children.count == 2)
    let b = try #require(result.root.child(named: "b"))
    #expect(result.root.size == a.size + b.size)
    let empty = try #require(result.root.child(named: "empty"))
    #expect(empty.kind == .directory)
    #expect(empty.size == 0)
    #expect(result.inaccessiblePaths.isEmpty)
}

@Test func symbolicLinksAreNotFollowed() async throws {
    let root = try Fixture.makeTree(["real/data.dat": 8_192])
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("link"),
        withDestinationURL: root.appendingPathComponent("real"))

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let expected = try Fixture.allocatedSize(of: root.appendingPathComponent("real/data.dat"))
    #expect(result.root.size == expected)
    let link = try #require(result.root.child(named: "link"))
    #expect(link.kind == .file)
    #expect(link.size == 0)
}

@Test func inaccessibleDirectoryIsFlaggedAndScanContinues() async throws {
    let root = try Fixture.makeTree(["locked/secret.dat": 4_096, "open/file.dat": 4_096])
    let locked = root.appendingPathComponent("locked")
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path)
        try? FileManager.default.removeItem(at: root)
    }

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let lockedNode = try #require(result.root.child(named: "locked"))
    #expect(lockedNode.kind == .inaccessibleDirectory)
    #expect(result.inaccessiblePaths.contains(locked.path))
    let open = try #require(result.root.child(named: "open"))
    #expect(open.size > 0)
}

@Test func excludedPathsAreSkipped() async throws {
    let root = try Fixture.makeTree(["keep/a.dat": 4_096, "skip/b.dat": 4_096])
    defer { try? FileManager.default.removeItem(at: root) }
    let config = ScanConfiguration(
        rootURL: root, excludedPaths: [root.appendingPathComponent("skip").path])

    let result = try await DiskScanner().scan(configuration: config)

    #expect(result.root.child(named: "skip") == nil)
    #expect(result.root.child(named: "keep") != nil)
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'DiskScanner'`)

Run: `swift test --filter DiskScannerTests`

- [ ] **Step 3: Реализация**

`Sources/ScanKit/ScanProgress.swift`:

```swift
public struct ScanProgress: Sendable {
    public let scannedItems: Int
    public let totalBytes: Int64
    public let currentPath: String

    public init(scannedItems: Int, totalBytes: Int64, currentPath: String) {
        self.scannedItems = scannedItems
        self.totalBytes = totalBytes
        self.currentPath = currentPath
    }
}
```

`Sources/ScanKit/ScanContext.swift`:

```swift
import Foundation

/// Потокобезопасные счётчики скана: прогресс + недоступные пути.
final class ScanContext: @unchecked Sendable {
    private let lock = NSLock()
    private var items = 0
    private var bytes: Int64 = 0
    private var inaccessible: [String] = []
    private let onProgress: (@Sendable (ScanProgress) -> Void)?
    private let progressInterval: Int

    init(onProgress: (@Sendable (ScanProgress) -> Void)?, progressInterval: Int) {
        self.onProgress = onProgress
        self.progressInterval = max(1, progressInterval)
    }

    func addFile(bytes fileBytes: Int64, path: String) {
        lock.lock()
        items += 1
        bytes += fileBytes
        let snapshot = items % progressInterval == 0
            ? ScanProgress(scannedItems: items, totalBytes: bytes, currentPath: path) : nil
        lock.unlock()
        if let snapshot { onProgress?(snapshot) }
    }

    func recordInaccessible(_ path: String) {
        lock.lock()
        inaccessible.append(path)
        lock.unlock()
    }

    func emitFinal(path: String) {
        lock.lock()
        let snapshot = ScanProgress(scannedItems: items, totalBytes: bytes, currentPath: path)
        lock.unlock()
        onProgress?(snapshot)
    }

    var inaccessiblePaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return inaccessible
    }
}
```

`Sources/ScanKit/DiskScanner.swift`:

```swift
import Foundation

public struct ScanResult: Sendable {
    public let root: FileNode
    public let inaccessiblePaths: [String]

    public init(root: FileNode, inaccessiblePaths: [String]) {
        self.root = root
        self.inaccessiblePaths = inaccessiblePaths
    }
}

public struct DiskScanner: Sendable {
    private let progressInterval: Int

    public init(progressInterval: Int = 2048) {
        self.progressInterval = progressInterval
    }

    public func scan(
        configuration: ScanConfiguration,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async throws -> ScanResult {
        let context = ScanContext(onProgress: onProgress, progressInterval: progressInterval)
        let root = try await scanDirectory(
            configuration.rootURL, configuration: configuration, context: context)
        context.emitFinal(path: configuration.rootURL.path)
        return ScanResult(root: root, inaccessiblePaths: context.inaccessiblePaths)
    }

    private func scanDirectory(
        _ url: URL, configuration: ScanConfiguration, context: ScanContext
    ) async throws -> FileNode {
        try Task.checkCancellation()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey]
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: keys, options: [])
        } catch {
            context.recordInaccessible(url.path)
            return FileNode(inaccessibleDirectoryNamed: url.lastPathComponent)
        }

        var files: [FileNode] = []
        var subdirectories: [URL] = []
        for entry in entries {
            guard let values = try? entry.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                files.append(FileNode(fileNamed: entry.lastPathComponent, size: 0))
            } else if values.isDirectory == true {
                if !configuration.isExcluded(entry) { subdirectories.append(entry) }
            } else {
                let size = Int64(values.totalFileAllocatedSize ?? 0)
                files.append(FileNode(fileNamed: entry.lastPathComponent, size: size))
                context.addFile(bytes: size, path: entry.path)
            }
        }

        var directories: [FileNode] = []
        directories.reserveCapacity(subdirectories.count)
        try await withThrowingTaskGroup(of: FileNode.self) { group in
            for subdirectory in subdirectories {
                group.addTask {
                    try await scanDirectory(subdirectory, configuration: configuration, context: context)
                }
            }
            for try await node in group { directories.append(node) }
        }
        return FileNode(directoryNamed: url.lastPathComponent, children: files + directories)
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter DiskScannerTests`
Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ScanKit Tests/ScanKitTests
git commit -m "feat: DiskScanner — параллельный обход с учётом симлинков и недоступных папок"
```

---

### Task 5: ScanKit — hardlinks, прогресс, отмена

**Files:**
- Create: `Sources/ScanKit/HardLinkRegistry.swift`
- Modify: `Sources/ScanKit/ScanContext.swift` (добавить `let hardLinks = HardLinkRegistry()`), `Sources/ScanKit/DiskScanner.swift` (учёт hardlink)
- Test: `Tests/ScanKitTests/DiskScannerConcurrencyTests.swift`

**Interfaces:**
- Produces: `HardLinkRegistry.countableSize(of url: URL, reportedSize: Int64) -> Int64` — размер при первом вхождении multi-link файла, 0 при повторах.

- [ ] **Step 1: Написать падающие тесты**

`Tests/ScanKitTests/DiskScannerConcurrencyTests.swift`:

```swift
import Foundation
import Testing
@testable import ScanKit

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value
    init(_ value: Value) { storage = value }
    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
    func withLock(_ body: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&storage)
    }
}

@Test func hardLinkedFileIsCountedOnce() async throws {
    let root = try Fixture.makeTree(["a/original.dat": 100_000])
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("b"), withIntermediateDirectories: true)
    try FileManager.default.linkItem(
        at: root.appendingPathComponent("a/original.dat"),
        to: root.appendingPathComponent("b/copy.dat"))

    let result = try await DiskScanner().scan(configuration: ScanConfiguration(rootURL: root))

    let expected = try Fixture.allocatedSize(of: root.appendingPathComponent("a/original.dat"))
    #expect(result.root.size == expected)
}

@Test func progressIsReported() async throws {
    var spec: [String: Int] = [:]
    for index in 0..<50 { spec["dir\(index % 5)/file\(index).dat"] = 4_096 }
    let root = try Fixture.makeTree(spec)
    defer { try? FileManager.default.removeItem(at: root) }

    let collected = Locked<[ScanProgress]>([])
    _ = try await DiskScanner(progressInterval: 10)
        .scan(configuration: ScanConfiguration(rootURL: root)) { progress in
            collected.withLock { $0.append(progress) }
        }

    let snapshots = collected.value
    #expect(!snapshots.isEmpty)
    #expect(snapshots.contains { $0.scannedItems == 50 })
    #expect(snapshots.map(\.scannedItems).max() == 50)
    #expect(snapshots.contains { $0.totalBytes > 0 })
}

@Test func cancellationStopsScan() async throws {
    var spec: [String: Int] = [:]
    for index in 0..<200 { spec["nested/dir\(index)/file.dat"] = 4_096 }
    let root = try Fixture.makeTree(spec)
    defer { try? FileManager.default.removeItem(at: root) }

    let scanner = DiskScanner()
    let config = ScanConfiguration(rootURL: root)
    // cancel() выполняется через наносекунды после старта; скан 200 директорий
    // занимает на порядки дольше, поэтому CancellationError детерминирован.
    let task = Task { try await scanner.scan(configuration: config) }
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
}
```

- [ ] **Step 2: Запустить — FAIL**

Run: `swift test --filter DiskScannerConcurrencyTests`
Expected: `hardLinkedFileIsCountedOnce` падает (размер задвоен); остальные могут пройти.

- [ ] **Step 3: Реализация**

`Sources/ScanKit/HardLinkRegistry.swift`:

```swift
import Foundation

/// Дедупликация жёстких ссылок: файл с nlink > 1 считается один раз.
final class HardLinkRegistry: @unchecked Sendable {
    private struct Key: Hashable {
        let device: Int32
        let inode: UInt64
    }

    private var seen = Set<Key>()
    private let lock = NSLock()

    /// reportedSize для первого вхождения multi-link файла, 0 для повторов.
    /// Для обычных файлов (nlink == 1) — reportedSize без учёта в реестре.
    func countableSize(of url: URL, reportedSize: Int64) -> Int64 {
        var status = stat()
        let success = url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            return lstat(path, &status) == 0
        }
        guard success, status.st_nlink > 1 else { return reportedSize }
        let key = Key(device: status.st_dev, inode: status.st_ino)
        lock.lock()
        defer { lock.unlock() }
        return seen.insert(key).inserted ? reportedSize : 0
    }
}
```

В `ScanContext` добавить поле (первой строкой класса):

```swift
    let hardLinks = HardLinkRegistry()
```

В `DiskScanner.scanDirectory` заменить ветку обычного файла:

```swift
            } else {
                let reported = Int64(values.totalFileAllocatedSize ?? 0)
                let size = context.hardLinks.countableSize(of: entry, reportedSize: reported)
                files.append(FileNode(fileNamed: entry.lastPathComponent, size: size))
                context.addFile(bytes: size, path: entry.path)
            }
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter "DiskScannerTests|DiskScannerConcurrencyTests"`
Expected: все PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/ScanKit Tests/ScanKitTests
git commit -m "feat: дедупликация hardlink, прогресс и отмена скана"
```

---

### Task 6: ScanKit — TreeRebuilder и точечный рескан

**Files:**
- Create: `Sources/ScanKit/TreeRebuilder.swift`
- Modify: `Sources/ScanKit/DiskScanner.swift` (extension `rescanSubtree`)
- Test: `Tests/ScanKitTests/TreeRebuilderTests.swift`

**Interfaces:**
- Produces: `TreeRebuilder.replacing(nodeAt path: [String], with: FileNode, in root: FileNode) -> FileNode?`; `TreeRebuilder.removingNode(at path: [String], in root: FileNode) -> FileNode?` (nil = путь не найден, дерево не менять); `DiskScanner.rescanSubtree(at relativePath: [String], in result: ScanResult, configuration: ScanConfiguration) async throws -> ScanResult`. Пути — имена узлов от корня, БЕЗ имени корня. После удаления с диска рескань РОДИТЕЛЯ удалённого элемента.

- [ ] **Step 1: Написать падающие тесты**

`Tests/ScanKitTests/TreeRebuilderTests.swift`:

```swift
import Foundation
import Testing
@testable import ScanKit

private func sampleTree() -> FileNode {
    FileNode(directoryNamed: "root", children: [
        FileNode(directoryNamed: "a", children: [
            FileNode(fileNamed: "one.dat", size: 100),
            FileNode(fileNamed: "two.dat", size: 200),
        ]),
        FileNode(fileNamed: "top.dat", size: 50),
    ])
}

@Test func replacingRebuildsAncestorSizes() throws {
    let replacement = FileNode(directoryNamed: "a", children: [
        FileNode(fileNamed: "one.dat", size: 100)
    ])
    let updated = try #require(
        TreeRebuilder.replacing(nodeAt: ["a"], with: replacement, in: sampleTree()))
    #expect(updated.size == 150)
    #expect(updated.child(named: "a")?.size == 100)
    #expect(TreeRebuilder.replacing(nodeAt: ["missing"], with: replacement, in: sampleTree()) == nil)
}

@Test func removingNodeRecomputesSizes() throws {
    let updated = try #require(TreeRebuilder.removingNode(at: ["a", "two.dat"], in: sampleTree()))
    #expect(updated.size == 150)
    #expect(updated.child(named: "a")?.children.count == 1)
    #expect(TreeRebuilder.removingNode(at: ["a", "ghost"], in: sampleTree()) == nil)
}

@Test func rescanSubtreePicksUpDeletions() async throws {
    let root = try Fixture.makeTree(["a/one.dat": 10_000, "a/two.dat": 10_000, "b/keep.dat": 4_096])
    defer { try? FileManager.default.removeItem(at: root) }
    let config = ScanConfiguration(rootURL: root)
    let scanner = DiskScanner()
    let before = try await scanner.scan(configuration: config)

    try FileManager.default.removeItem(at: root.appendingPathComponent("a/two.dat"))
    let after = try await scanner.rescanSubtree(at: ["a"], in: before, configuration: config)

    let expectedA = try Fixture.allocatedSize(of: root.appendingPathComponent("a/one.dat"))
    #expect(after.root.child(named: "a")?.size == expectedA)
    let keep = try #require(after.root.child(named: "b"))
    #expect(keep.size > 0)
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'TreeRebuilder'`)

Run: `swift test --filter TreeRebuilderTests`

- [ ] **Step 3: Реализация**

`Sources/ScanKit/TreeRebuilder.swift`:

```swift
/// Иммутабельные операции над деревом: замена/удаление узла с пересчётом
/// размеров предков. path — имена узлов от корня (без имени самого корня).
public enum TreeRebuilder {
    public static func replacing(
        nodeAt path: [String], with replacement: FileNode, in root: FileNode
    ) -> FileNode? {
        guard let first = path.first else { return replacement }
        guard let child = root.child(named: first) else { return nil }
        guard let newChild = replacing(nodeAt: Array(path.dropFirst()), with: replacement, in: child)
        else { return nil }
        let newChildren = root.children.map { $0 === child ? newChild : $0 }
        return FileNode(directoryNamed: root.name, children: newChildren)
    }

    public static func removingNode(at path: [String], in root: FileNode) -> FileNode? {
        guard let first = path.first else { return nil }
        guard let child = root.child(named: first) else { return nil }
        if path.count == 1 {
            let newChildren = root.children.filter { $0 !== child }
            return FileNode(directoryNamed: root.name, children: newChildren)
        }
        guard let newChild = removingNode(at: Array(path.dropFirst()), in: child) else { return nil }
        let newChildren = root.children.map { $0 === child ? newChild : $0 }
        return FileNode(directoryNamed: root.name, children: newChildren)
    }
}
```

В `Sources/ScanKit/DiskScanner.swift` добавить:

```swift
extension DiskScanner {
    /// Пересканирует поддиректорию и возвращает новое дерево с заменённым
    /// поддеревом. После удаления элемента с диска вызывайте для его РОДИТЕЛЯ.
    public func rescanSubtree(
        at relativePath: [String],
        in result: ScanResult,
        configuration: ScanConfiguration
    ) async throws -> ScanResult {
        let url = relativePath.reduce(configuration.rootURL) {
            $0.appendingPathComponent($1)
        }
        let subConfiguration = ScanConfiguration(
            rootURL: url, excludedPaths: configuration.excludedPaths)
        let subResult = try await scan(configuration: subConfiguration)
        guard let newRoot = TreeRebuilder.replacing(
            nodeAt: relativePath, with: subResult.root, in: result.root)
        else { return result }
        return ScanResult(root: newRoot, inaccessiblePaths: result.inaccessiblePaths)
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter TreeRebuilderTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/ScanKit Tests/ScanKitTests
git commit -m "feat: TreeRebuilder и точечный рескан поддерева"
```

---

### Task 7: ScanKit — LargeFileCollector

**Files:**
- Create: `Sources/ScanKit/LargeFileCollector.swift`
- Test: `Tests/ScanKitTests/LargeFileCollectorTests.swift`

**Interfaces:**
- Produces: `LargeFileEntry { path: String; size: Int64; id: String }` (Sendable, Identifiable, Equatable); `LargeFileCollector.topFiles(in root: FileNode, rootPath: String, limit: Int = 100, minimumSize: Int64) -> [LargeFileEntry]` — отсортировано по size desc. Обход отсекает директории меньше minimumSize (файл ≥ minimumSize не может лежать в директории меньшего размера).

- [ ] **Step 1: Написать падающий тест**

`Tests/ScanKitTests/LargeFileCollectorTests.swift`:

```swift
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
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'LargeFileCollector'`)

Run: `swift test --filter LargeFileCollectorTests`

- [ ] **Step 3: Реализация**

`Sources/ScanKit/LargeFileCollector.swift`:

```swift
public struct LargeFileEntry: Sendable, Identifiable, Equatable {
    public let path: String
    public let size: Int64
    public var id: String { path }

    public init(path: String, size: Int64) {
        self.path = path
        self.size = size
    }
}

public enum LargeFileCollector {
    public static func topFiles(
        in root: FileNode, rootPath: String, limit: Int = 100, minimumSize: Int64
    ) -> [LargeFileEntry] {
        var entries: [LargeFileEntry] = []
        collect(node: root, path: rootPath, minimumSize: minimumSize, into: &entries)
        return Array(entries.sorted { $0.size > $1.size }.prefix(limit))
    }

    private static func collect(
        node: FileNode, path: String, minimumSize: Int64, into entries: inout [LargeFileEntry]
    ) {
        for child in node.children {
            let childPath = path.hasSuffix("/") ? path + child.name : path + "/" + child.name
            switch child.kind {
            case .file where child.size >= minimumSize:
                entries.append(LargeFileEntry(path: childPath, size: child.size))
            case .directory where child.size >= minimumSize:
                collect(node: child, path: childPath, minimumSize: minimumSize, into: &entries)
            default:
                break
            }
        }
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter LargeFileCollectorTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/ScanKit/LargeFileCollector.swift Tests/ScanKitTests/LargeFileCollectorTests.swift
git commit -m "feat: LargeFileCollector — топ тяжёлых файлов из дерева"
```

---

### Task 8: CleanupKit — модели и PathResolver

**Files:**
- Create: `Sources/CleanupKit/CleanupEnvironment.swift`, `Sources/CleanupKit/CleanupModels.swift`, `Sources/CleanupKit/PathResolver.swift`
- Test: `Tests/CleanupKitTests/PathResolverTests.swift`

**Interfaces:**
- Produces:
  - `CleanupEnvironment(homeDirectory: URL, rootDirectory: URL)`, `.live`.
  - `SafetyLevel { safe, caution }`; `CleanupCategory: String, CaseIterable { systemJunk, developerJunk, browserData, miscellaneous }`.
  - `PathPattern(base: Base, components: [String])`, `Base { home, root }`; компонент `"*"` = любой один уровень.
  - `CommandAction(executable: String, arguments: [String])`.
  - `CleanupRule(id:title:category:safety:pathPatterns:deleteContentsOnly:permanentOnly:enabledByDefault:command:)` — последние 4 параметра имеют дефолты `false/false/true/nil`.
  - `CleanupItem(rule:url:size:command:deletable:)` (Identifiable, Equatable; поля `id, ruleID, title, category, safety, url: URL?, size, permanentOnly, enabledByDefault, deletable, command`); `title` = lastPathComponent url либо rule.title.
  - `PathResolver.resolve(_ pattern: PathPattern, environment: CleanupEnvironment) -> [URL]` — только существующие пути, отсортированы.

- [ ] **Step 1: Написать падающие тесты**

`Tests/CleanupKitTests/PathResolverTests.swift`:

```swift
import Foundation
import Testing
@testable import CleanupKit

/// Копия хелпера из ScanKitTests (тест-таргеты не делят код).
enum Fixture {
    static func makeTree(_ spec: [String: Int]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("discusage-cleanup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for (relativePath, byteCount) in spec {
            let url = root.appendingPathComponent(relativePath)
            if relativePath.hasSuffix("/") {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(repeating: 0x61, count: byteCount).write(to: url)
            }
        }
        return root
    }
}

@Test func resolvesLiteralPathRelativeToHome() throws {
    let home = try Fixture.makeTree(["Library/Caches/App1/data.bin": 100])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)

    let pattern = PathPattern(base: .home, components: ["Library", "Caches"])
    let resolved = PathResolver.resolve(pattern, environment: environment)
    #expect(resolved.map(\.lastPathComponent) == ["Caches"])

    let missing = PathPattern(base: .home, components: ["Library", "Nope"])
    #expect(PathResolver.resolve(missing, environment: environment).isEmpty)
}

@Test func starExpandsOneLevel() throws {
    let home = try Fixture.makeTree([
        "profiles/alpha/cache/x.bin": 10,
        "profiles/beta/cache/y.bin": 10,
        "profiles/gamma/nocache.txt": 10,
    ])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)

    let pattern = PathPattern(base: .home, components: ["profiles", "*", "cache"])
    let resolved = PathResolver.resolve(pattern, environment: environment)
    #expect(resolved.count == 2)
    #expect(resolved.allSatisfy { $0.lastPathComponent == "cache" })
}

@Test func cleanupItemDerivesFieldsFromRule() {
    let rule = CleanupRule(
        id: "test.rule", title: "Тестовое правило", category: .systemJunk, safety: .safe,
        pathPatterns: [], enabledByDefault: false)
    let url = URL(filePath: "/tmp/target")
    let item = CleanupItem(rule: rule, url: url, size: 42)
    #expect(item.id == "test.rule:/tmp/target")
    #expect(item.title == "target")
    #expect(item.enabledByDefault == false)
    #expect(item.deletable == true)
    let commandItem = CleanupItem(
        rule: rule, url: nil, size: 0,
        command: CommandAction(executable: "/usr/bin/true", arguments: []))
    #expect(commandItem.title == "Тестовое правило")
    #expect(commandItem.id == "test.rule:command")
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'CleanupEnvironment'`)

Run: `swift test --filter PathResolverTests`

- [ ] **Step 3: Реализация**

`Sources/CleanupKit/CleanupEnvironment.swift`:

```swift
import Foundation

public struct CleanupEnvironment: Sendable {
    public let homeDirectory: URL
    public let rootDirectory: URL

    public init(homeDirectory: URL, rootDirectory: URL) {
        self.homeDirectory = homeDirectory
        self.rootDirectory = rootDirectory
    }

    public static let live = CleanupEnvironment(
        homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
        rootDirectory: URL(filePath: "/"))
}
```

`Sources/CleanupKit/CleanupModels.swift`:

```swift
import Foundation

public enum SafetyLevel: Sendable, Equatable {
    case safe
    case caution
}

public enum CleanupCategory: String, CaseIterable, Sendable {
    case systemJunk
    case developerJunk
    case browserData
    case miscellaneous
}

public struct PathPattern: Sendable {
    public enum Base: Sendable { case home, root }

    public let base: Base
    /// Компонент "*" раскрывается в любой один уровень вложенности.
    public let components: [String]

    public init(base: Base, components: [String]) {
        self.base = base
        self.components = components
    }
}

public struct CommandAction: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct CleanupRule: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let category: CleanupCategory
    public let safety: SafetyLevel
    public let pathPatterns: [PathPattern]
    /// Удалять содержимое директории, не саму директорию (item на каждого ребёнка).
    public let deleteContentsOnly: Bool
    /// Только безвозвратное удаление (очистка Корзины).
    public let permanentOnly: Bool
    public let enabledByDefault: Bool
    public let command: CommandAction?

    public init(
        id: String, title: String, category: CleanupCategory, safety: SafetyLevel,
        pathPatterns: [PathPattern], deleteContentsOnly: Bool = false,
        permanentOnly: Bool = false, enabledByDefault: Bool = true,
        command: CommandAction? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.safety = safety
        self.pathPatterns = pathPatterns
        self.deleteContentsOnly = deleteContentsOnly
        self.permanentOnly = permanentOnly
        self.enabledByDefault = enabledByDefault
        self.command = command
    }
}

public struct CleanupItem: Sendable, Identifiable, Equatable {
    public let id: String
    public let ruleID: String
    public let title: String
    public let category: CleanupCategory
    public let safety: SafetyLevel
    public let url: URL?
    public let size: Int64
    public let permanentOnly: Bool
    public let enabledByDefault: Bool
    /// false — только просмотр (например, .lproj подписанного приложения).
    public let deletable: Bool
    public let command: CommandAction?

    public init(
        rule: CleanupRule, url: URL?, size: Int64,
        command: CommandAction? = nil, deletable: Bool = true
    ) {
        self.id = rule.id + ":" + (url?.path ?? "command")
        self.ruleID = rule.id
        self.title = url?.lastPathComponent ?? rule.title
        self.category = rule.category
        self.safety = rule.safety
        self.url = url
        self.size = size
        self.permanentOnly = rule.permanentOnly
        self.enabledByDefault = rule.enabledByDefault
        self.deletable = deletable
        self.command = command
    }
}
```

`Sources/CleanupKit/PathResolver.swift`:

```swift
import Foundation

public enum PathResolver {
    /// Раскрывает шаблон в существующие пути. "*" — любой один уровень.
    public static func resolve(_ pattern: PathPattern, environment: CleanupEnvironment) -> [URL] {
        let base = pattern.base == .home ? environment.homeDirectory : environment.rootDirectory
        var current = [base]
        for component in pattern.components {
            var next: [URL] = []
            for url in current {
                if component == "*" {
                    let children = (try? FileManager.default.contentsOfDirectory(
                        at: url, includingPropertiesForKeys: nil, options: [])) ?? []
                    next.append(contentsOf: children)
                } else {
                    let candidate = url.appendingPathComponent(component)
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        next.append(candidate)
                    }
                }
            }
            current = next
        }
        return current.sorted { $0.path < $1.path }
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter PathResolverTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/CleanupKit Tests/CleanupKitTests
git commit -m "feat: модели CleanupKit и PathResolver с '*'-шаблонами"
```

---

### Task 9: CleanupKit — таблица правил, сайзер, JunkScanner

**Files:**
- Create: `Sources/CleanupKit/CleanupRules.swift`, `Sources/CleanupKit/DirectorySizing.swift`, `Sources/CleanupKit/JunkScanner.swift`
- Test: `Tests/CleanupKitTests/JunkScannerTests.swift`

**Interfaces:**
- Consumes: модели T8.
- Produces:
  - `CleanupRules.all: [CleanupRule]`, `CleanupRules.localizations: CleanupRule` (id `"misc.lproj"`).
  - `DirectorySizing { func size(of url: URL) async -> Int64 }`; `FileSystemSizer()`.
  - `JunkScanner(environment: CleanupEnvironment = .live, sizer: any DirectorySizing = FileSystemSizer())` c `scan(rules: [CleanupRule] = CleanupRules.all) async -> [CleanupItem]`. Для `deleteContentsOnly`-правил — item на каждого ребёнка директории; для остальных — item на разрешённый путь; для `command`-правил — один item с `url == nil, size == 0`.
  - `CleanupPlanner.deduplicate(_ items: [CleanupItem]) -> [CleanupItem]` — убирает точные дубли путей и элементы, лежащие внутри других элементов.

- [ ] **Step 1: Написать падающие тесты**

`Tests/CleanupKitTests/JunkScannerTests.swift`:

```swift
import Foundation
import Testing
@testable import CleanupKit

@Test func sizerSumsAllocatedSizes() async throws {
    let root = try Fixture.makeTree(["dir/a.bin": 10_000, "dir/sub/b.bin": 20_000])
    defer { try? FileManager.default.removeItem(at: root) }
    let size = await FileSystemSizer().size(of: root.appendingPathComponent("dir"))
    #expect(size >= 30_000)
    let fileSize = await FileSystemSizer().size(of: root.appendingPathComponent("dir/a.bin"))
    #expect(fileSize >= 10_000)
}

@Test func contentsOnlyRuleEmitsPerChildItems() async throws {
    let home = try Fixture.makeTree([
        "Library/Caches/AppOne/data.bin": 10_000,
        "Library/Caches/AppTwo/data.bin": 20_000,
    ])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let rule = CleanupRule(
        id: "system.userCaches", title: "Кэши приложений", category: .systemJunk,
        safety: .safe,
        pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches"])],
        deleteContentsOnly: true)

    let items = await JunkScanner(environment: environment).scan(rules: [rule])

    #expect(items.count == 2)
    #expect(Set(items.map(\.title)) == ["AppOne", "AppTwo"])
    #expect(items.allSatisfy { $0.size >= 10_000 })
    #expect(items.allSatisfy { $0.ruleID == "system.userCaches" })
}

@Test func overlappingAndDuplicateItemsAreDeduplicated() async throws {
    let home = try Fixture.makeTree(["Library/Caches/org.swift.swiftpm/manifest.bin": 5_000])
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let parent = CleanupRule(
        id: "system.userCaches", title: "Кэши", category: .systemJunk, safety: .safe,
        pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches"])],
        deleteContentsOnly: true)
    let nested = CleanupRule(
        id: "dev.spmCache", title: "Кэш SPM", category: .developerJunk, safety: .safe,
        pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "org.swift.swiftpm"])])

    let items = await JunkScanner(environment: environment).scan(rules: [parent, nested])

    #expect(items.count == 1)
    #expect(items[0].url?.lastPathComponent == "org.swift.swiftpm")
}

@Test func commandRuleProducesCommandItem() async {
    let environment = CleanupEnvironment(
        homeDirectory: URL(filePath: "/nonexistent"), rootDirectory: URL(filePath: "/nonexistent"))
    let rule = CleanupRule(
        id: "dev.unavailableSimulators", title: "Недоступные симуляторы",
        category: .developerJunk, safety: .safe, pathPatterns: [],
        command: CommandAction(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"]))

    let items = await JunkScanner(environment: environment).scan(rules: [rule])

    #expect(items.count == 1)
    #expect(items[0].url == nil)
    #expect(items[0].command?.arguments == ["simctl", "delete", "unavailable"])
}

@Test func rulesTableInvariants() {
    let rules = CleanupRules.all
    #expect(Set(rules.map(\.id)).count == rules.count)
    let history = rules.first { $0.id == "browser.safariHistory" }
    #expect(history?.enabledByDefault == false)
    let trash = rules.first { $0.id == "system.trash" }
    #expect(trash?.permanentOnly == true)
    let archives = rules.first { $0.id == "dev.xcodeArchives" }
    #expect(archives?.enabledByDefault == false)
    #expect(archives?.safety == .caution)
    #expect(rules.contains { $0.command != nil })
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'FileSystemSizer'`)

Run: `swift test --filter JunkScannerTests`

- [ ] **Step 3: Реализация**

`Sources/CleanupKit/DirectorySizing.swift`:

```swift
import Foundation

public protocol DirectorySizing: Sendable {
    func size(of url: URL) async -> Int64
}

public struct FileSystemSizer: DirectorySizing {
    public init() {}

    public func size(of url: URL) async -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [])
        else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
```

`Sources/CleanupKit/JunkScanner.swift`:

```swift
import Foundation

public struct JunkScanner: Sendable {
    private let environment: CleanupEnvironment
    private let sizer: any DirectorySizing

    public init(
        environment: CleanupEnvironment = .live,
        sizer: any DirectorySizing = FileSystemSizer()
    ) {
        self.environment = environment
        self.sizer = sizer
    }

    public func scan(rules: [CleanupRule] = CleanupRules.all) async -> [CleanupItem] {
        var items: [CleanupItem] = []
        for rule in rules {
            if let command = rule.command {
                items.append(CleanupItem(rule: rule, url: nil, size: 0, command: command))
                continue
            }
            for pattern in rule.pathPatterns {
                let resolved = PathResolver.resolve(pattern, environment: environment)
                let targets: [URL]
                if rule.deleteContentsOnly {
                    targets = resolved.flatMap { url in
                        (try? FileManager.default.contentsOfDirectory(
                            at: url, includingPropertiesForKeys: nil, options: [])) ?? []
                    }
                } else {
                    targets = resolved
                }
                for target in targets {
                    let size = await sizer.size(of: target)
                    items.append(CleanupItem(rule: rule, url: target, size: size))
                }
            }
        }
        return CleanupPlanner.deduplicate(items)
    }
}

public enum CleanupPlanner {
    /// Убирает точные дубли путей и элементы, вложенные в другие элементы.
    public static func deduplicate(_ items: [CleanupItem]) -> [CleanupItem] {
        let allPaths = Set(items.compactMap { $0.url?.path })
        var seen = Set<String>()
        return items.filter { item in
            guard let url = item.url else { return true }
            var parent = url.deletingLastPathComponent()
            while parent.path.count > 1 {
                if allPaths.contains(parent.path) { return false }
                parent = parent.deletingLastPathComponent()
            }
            return seen.insert(url.path).inserted
        }
    }
}
```

`Sources/CleanupKit/CleanupRules.swift`:

```swift
import Foundation

public enum CleanupRules {
    public static let all: [CleanupRule] =
        systemJunk + developerJunk + browserData + miscellaneous

    public static let localizations = CleanupRule(
        id: "misc.lproj", title: "Неиспользуемые локализации",
        category: .miscellaneous, safety: .caution,
        pathPatterns: [], enabledByDefault: false)

    static let systemJunk: [CleanupRule] = [
        CleanupRule(
            id: "system.userCaches", title: "Кэши приложений",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "system.userLogs", title: "Логи приложений",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Logs"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "system.sharedCaches", title: "Общие кэши (/Library/Caches)",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .root, components: ["Library", "Caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "system.trash", title: "Корзина",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: [".Trash"])],
            deleteContentsOnly: true, permanentOnly: true),
        CleanupRule(
            id: "system.tmp", title: "Временные файлы (/private/tmp)",
            category: .systemJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .root, components: ["private", "tmp"])],
            deleteContentsOnly: true),
    ]

    static let developerJunk: [CleanupRule] = [
        CleanupRule(
            id: "dev.derivedData", title: "Xcode DerivedData",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "DerivedData"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.iosDeviceSupport", title: "iOS DeviceSupport",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "iOS DeviceSupport"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.watchosDeviceSupport", title: "watchOS DeviceSupport",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "watchOS DeviceSupport"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.simulatorCaches", title: "Кэши симуляторов",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "CoreSimulator", "Caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.unavailableSimulators", title: "Недоступные симуляторы",
            category: .developerJunk, safety: .safe, pathPatterns: [],
            command: CommandAction(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "delete", "unavailable"])),
        CleanupRule(
            id: "dev.spmCache", title: "Кэш Swift Package Manager",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "org.swift.swiftpm"])]),
        CleanupRule(
            id: "dev.cocoapodsCache", title: "Кэш CocoaPods",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "CocoaPods"])]),
        CleanupRule(
            id: "dev.gradleCache", title: "Кэш Gradle",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: [".gradle", "caches"])],
            deleteContentsOnly: true),
        CleanupRule(
            id: "dev.npmCache", title: "Кэш npm",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: [".npm", "_cacache"])]),
        CleanupRule(
            id: "dev.homebrewCache", title: "Кэш Homebrew",
            category: .developerJunk, safety: .safe,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "Homebrew"])]),
        CleanupRule(
            id: "dev.xcodeArchives", title: "Xcode Archives (dSYM релизов!)",
            category: .developerJunk, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Developer", "Xcode", "Archives"])],
            deleteContentsOnly: true, enabledByDefault: false),
    ]

    static let browserData: [CleanupRule] = [
        CleanupRule(
            id: "browser.safariCache", title: "Кэш Safari",
            category: .browserData, safety: .caution,
            pathPatterns: [
                PathPattern(base: .home, components: ["Library", "Caches", "com.apple.Safari"]),
                PathPattern(base: .home, components: ["Library", "Containers", "com.apple.Safari", "Data", "Library", "Caches"]),
            ]),
        CleanupRule(
            id: "browser.chromeCache", title: "Кэш Chrome",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "Google", "Chrome"])]),
        CleanupRule(
            id: "browser.arcCache", title: "Кэш Arc",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "company.thebrowser.Browser"])]),
        CleanupRule(
            id: "browser.firefoxCache", title: "Кэш Firefox",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Caches", "Firefox", "Profiles", "*", "cache2"])]),
        CleanupRule(
            id: "browser.safariHistory", title: "История Safari",
            category: .browserData, safety: .caution,
            pathPatterns: [
                PathPattern(base: .home, components: ["Library", "Safari", "History.db"]),
                PathPattern(base: .home, components: ["Library", "Safari", "History.db-wal"]),
                PathPattern(base: .home, components: ["Library", "Safari", "History.db-shm"]),
            ],
            enabledByDefault: false),
        CleanupRule(
            id: "browser.chromeHistory", title: "История Chrome",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Application Support", "Google", "Chrome", "*", "History"])],
            enabledByDefault: false),
        CleanupRule(
            id: "browser.cookies", title: "Cookies (системное хранилище)",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Cookies"])],
            deleteContentsOnly: true, enabledByDefault: false),
        CleanupRule(
            id: "browser.chromeCookies", title: "Cookies Chrome",
            category: .browserData, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Application Support", "Google", "Chrome", "*", "Cookies"])],
            enabledByDefault: false),
    ]

    static let miscellaneous: [CleanupRule] = [
        CleanupRule(
            id: "misc.iosBackups", title: "Резервные копии iOS",
            category: .miscellaneous, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Application Support", "MobileSync", "Backup"])],
            deleteContentsOnly: true, enabledByDefault: false),
        CleanupRule(
            id: "misc.mailDownloads", title: "Вложения Mail",
            category: .miscellaneous, safety: .caution,
            pathPatterns: [PathPattern(base: .home, components: ["Library", "Containers", "com.apple.mail", "Data", "Library", "Mail Downloads"])],
            deleteContentsOnly: true, enabledByDefault: false),
    ]
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter JunkScannerTests`
Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CleanupKit Tests/CleanupKitTests
git commit -m "feat: таблица правил очистки, FileSystemSizer и JunkScanner с дедупликацией"
```

---

### Task 10: CleanupKit — LprojScanner

**Files:**
- Create: `Sources/CleanupKit/LprojScanner.swift`
- Test: `Tests/CleanupKitTests/LprojScannerTests.swift`

**Interfaces:**
- Consumes: `CleanupRules.localizations`, `CleanupItem`, `DirectorySizing`.
- Produces: `SignatureChecking { func isSigned(_ url: URL) -> Bool }`; `CodesignChecker()` (через `/usr/bin/codesign --verify`); `LprojScanner(applicationsDirectory: URL = URL(filePath: "/Applications"), keptLanguages: Set<String> = LprojScanner.defaultKeptLanguages(), signatureChecker: any SignatureChecking = CodesignChecker(), sizer: any DirectorySizing = FileSystemSizer())` c `scan() async -> [CleanupItem]`. Подписанный бандл → `deletable: false`.

- [ ] **Step 1: Написать падающие тесты**

`Tests/CleanupKitTests/LprojScannerTests.swift`:

```swift
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
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'LprojScanner'`)

Run: `swift test --filter LprojScannerTests`

- [ ] **Step 3: Реализация**

`Sources/CleanupKit/LprojScanner.swift`:

```swift
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
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter LprojScannerTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/CleanupKit/LprojScanner.swift Tests/CleanupKitTests/LprojScannerTests.swift
git commit -m "feat: LprojScanner — локализации с защитой подписанных бандлов"
```

---

### Task 11: CleanupKit — CleanupExecutor

**Files:**
- Create: `Sources/CleanupKit/CleanupExecutor.swift`
- Test: `Tests/CleanupKitTests/CleanupExecutorTests.swift`

**Interfaces:**
- Consumes: `CleanupItem`, `CommandAction`.
- Produces:
  - `FileRemoving { func trash(_ url: URL) throws; func removePermanently(_ url: URL) throws }`; `SystemFileRemover()` (`FileManager.trashItem` / `removeItem`).
  - `ProcessRunning { @discardableResult func run(_ executable: String, arguments: [String]) throws -> Int32 }`; `SystemProcessRunner()`.
  - `CleanupFailure { item: CleanupItem; message: String }`; `CleanupReport { deleted: [CleanupItem]; failed: [CleanupFailure]; freedBytes: Int64 }`.
  - `CleanupExecutor(remover: any FileRemoving = SystemFileRemover(), processRunner: any ProcessRunning = SystemProcessRunner())` c `execute(items: [CleanupItem], permanently: Bool) async -> CleanupReport`. Ошибка одного элемента не прерывает пакет; `permanentOnly` всегда удаляется навсегда; `deletable == false` попадает в failed.

- [ ] **Step 1: Написать падающие тесты**

`Tests/CleanupKitTests/CleanupExecutorTests.swift`:

```swift
import Foundation
import Testing
@testable import CleanupKit

private final class MockRemover: FileRemoving, @unchecked Sendable {
    private let lock = NSLock()
    var trashed: [String] = []
    var removed: [String] = []
    var failingPaths: Set<String> = []

    func trash(_ url: URL) throws {
        try record(url) { trashed.append(url.path) }
    }
    func removePermanently(_ url: URL) throws {
        try record(url) { removed.append(url.path) }
    }
    private func record(_ url: URL, _ append: () -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        if failingPaths.contains(url.path) {
            throw NSError(domain: "mock", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "нет прав"])
        }
        append()
    }
}

private final class MockRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    var calls: [(String, [String])] = []
    var status: Int32 = 0
    func run(_ executable: String, arguments: [String]) throws -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        calls.append((executable, arguments))
        return status
    }
}

private func makeItem(
    id: String, path: String?, size: Int64 = 100, permanentOnly: Bool = false,
    deletable: Bool = true, command: CommandAction? = nil
) -> CleanupItem {
    let rule = CleanupRule(
        id: id, title: id, category: .systemJunk, safety: .safe,
        pathPatterns: [], permanentOnly: permanentOnly)
    return CleanupItem(
        rule: rule, url: path.map { URL(filePath: $0) }, size: size,
        command: command, deletable: deletable)
}

@Test func trashByDefaultPermanentWhenRequested() async {
    let remover = MockRemover()
    let executor = CleanupExecutor(remover: remover, processRunner: MockRunner())

    let report1 = await executor.execute(
        items: [makeItem(id: "a", path: "/tmp/a")], permanently: false)
    #expect(remover.trashed == ["/tmp/a"])
    #expect(report1.deleted.count == 1)

    let report2 = await executor.execute(
        items: [makeItem(id: "b", path: "/tmp/b")], permanently: true)
    #expect(remover.removed == ["/tmp/b"])
    #expect(report2.freedBytes == 100)
}

@Test func permanentOnlyItemsAlwaysRemovedPermanently() async {
    let remover = MockRemover()
    let executor = CleanupExecutor(remover: remover, processRunner: MockRunner())
    _ = await executor.execute(
        items: [makeItem(id: "trash", path: "/tmp/.Trash/x", permanentOnly: true)],
        permanently: false)
    #expect(remover.removed == ["/tmp/.Trash/x"])
    #expect(remover.trashed.isEmpty)
}

@Test func failuresDoNotStopBatchAndNonDeletableSkipped() async {
    let remover = MockRemover()
    remover.failingPaths = ["/tmp/locked"]
    let executor = CleanupExecutor(remover: remover, processRunner: MockRunner())

    let report = await executor.execute(items: [
        makeItem(id: "a", path: "/tmp/locked"),
        makeItem(id: "b", path: "/tmp/ok", size: 500),
        makeItem(id: "c", path: "/tmp/viewonly", deletable: false),
    ], permanently: false)

    #expect(report.deleted.map(\.ruleID) == ["b"])
    #expect(report.failed.count == 2)
    #expect(report.freedBytes == 500)
    #expect(report.failed.contains { $0.message == "нет прав" })
}

@Test func commandItemRunsProcess() async {
    let runner = MockRunner()
    let executor = CleanupExecutor(remover: MockRemover(), processRunner: runner)
    let command = CommandAction(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"])

    let report = await executor.execute(
        items: [makeItem(id: "sim", path: nil, size: 0, command: command)], permanently: false)

    #expect(runner.calls.count == 1)
    #expect(runner.calls[0].0 == "/usr/bin/xcrun")
    #expect(report.deleted.count == 1)

    runner.status = 1
    let failing = await executor.execute(
        items: [makeItem(id: "sim2", path: nil, size: 0, command: command)], permanently: false)
    #expect(failing.failed.count == 1)
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'CleanupExecutor'`)

Run: `swift test --filter CleanupExecutorTests`

- [ ] **Step 3: Реализация**

`Sources/CleanupKit/CleanupExecutor.swift`:

```swift
import Foundation

public protocol FileRemoving: Sendable {
    func trash(_ url: URL) throws
    func removePermanently(_ url: URL) throws
}

public struct SystemFileRemover: FileRemoving {
    public init() {}

    public func trash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public func removePermanently(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

public protocol ProcessRunning: Sendable {
    @discardableResult
    func run(_ executable: String, arguments: [String]) throws -> Int32
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    @discardableResult
    public func run(_ executable: String, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

public struct CleanupFailure: Sendable {
    public let item: CleanupItem
    public let message: String
}

public struct CleanupReport: Sendable {
    public let deleted: [CleanupItem]
    public let failed: [CleanupFailure]

    public var freedBytes: Int64 { deleted.reduce(0) { $0 + $1.size } }

    public init(deleted: [CleanupItem], failed: [CleanupFailure]) {
        self.deleted = deleted
        self.failed = failed
    }
}

enum CleanupError: LocalizedError {
    case commandFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let status): "команда завершилась с кодом \(status)"
        }
    }
}

public struct CleanupExecutor: Sendable {
    private let remover: any FileRemoving
    private let processRunner: any ProcessRunning

    public init(
        remover: any FileRemoving = SystemFileRemover(),
        processRunner: any ProcessRunning = SystemProcessRunner()
    ) {
        self.remover = remover
        self.processRunner = processRunner
    }

    public func execute(items: [CleanupItem], permanently: Bool) async -> CleanupReport {
        var deleted: [CleanupItem] = []
        var failed: [CleanupFailure] = []
        for item in items {
            guard item.deletable else {
                failed.append(CleanupFailure(item: item, message: "элемент только для просмотра"))
                continue
            }
            do {
                if let command = item.command {
                    let status = try processRunner.run(command.executable, arguments: command.arguments)
                    guard status == 0 else { throw CleanupError.commandFailed(status) }
                } else if let url = item.url {
                    if permanently || item.permanentOnly {
                        try remover.removePermanently(url)
                    } else {
                        try remover.trash(url)
                    }
                }
                deleted.append(item)
            } catch {
                failed.append(CleanupFailure(item: item, message: error.localizedDescription))
            }
        }
        return CleanupReport(deleted: deleted, failed: failed)
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter CleanupExecutorTests`
Expected: 4 tests PASS. Затем полный прогон: `swift test` — всё зелёное.

- [ ] **Step 5: Commit**

```bash
git add Sources/CleanupKit/CleanupExecutor.swift Tests/CleanupKitTests/CleanupExecutorTests.swift
git commit -m "feat: CleanupExecutor — пакетное удаление с отчётом и командные элементы"
```

---

### Task 12: DiscUsageUI — TreemapLayout (squarified)

**Files:**
- Create: `Sources/DiscUsageUI/TreemapLayout.swift`
- Test: `Tests/DiscUsageUITests/TreemapLayoutTests.swift`

**Interfaces:**
- Produces: `TreemapLayout.squarify(values: [Double], in rect: CGRect) -> [CGRect]`. Вход ДОЛЖЕН быть отсортирован по убыванию (дети FileNode уже такие); выход выровнен по индексам входа; нулевые значения дают нулевые прямоугольники.

- [ ] **Step 1: Написать падающие тесты**

`Tests/DiscUsageUITests/TreemapLayoutTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import DiscUsageUI

private let container = CGRect(x: 0, y: 0, width: 400, height: 300)

@Test func areasAreProportionalToValues() {
    let values: [Double] = [600, 300, 60, 30, 10]
    let rects = TreemapLayout.squarify(values: values, in: container)
    #expect(rects.count == values.count)
    let total = values.reduce(0, +)
    for (value, rect) in zip(values, rects) {
        let expected = value / total * (400 * 300)
        #expect(abs(rect.width * rect.height - expected) < 0.5)
    }
}

@Test func rectsDoNotOverlapAndStayInBounds() {
    let values: [Double] = [500, 400, 300, 200, 100, 50, 25]
    let rects = TreemapLayout.squarify(values: values, in: container)
    for rect in rects {
        #expect(container.insetBy(dx: -0.01, dy: -0.01).contains(rect))
    }
    for i in rects.indices {
        for j in rects.indices where i < j {
            let overlap = rects[i].intersection(rects[j])
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            #expect(area < 0.01)
        }
    }
}

@Test func degenerateInputsAreHandled() {
    #expect(TreemapLayout.squarify(values: [], in: container).isEmpty)
    let withZeros = TreemapLayout.squarify(values: [100, 0, 0], in: container)
    #expect(withZeros.count == 3)
    #expect(withZeros[0].width * withZeros[0].height > 0)
    #expect(withZeros[1].width * withZeros[1].height == 0)
    let zeroRect = TreemapLayout.squarify(values: [1, 2], in: .zero)
    #expect(zeroRect.count == 2)
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'TreemapLayout'`)

Run: `swift test --filter TreemapLayoutTests`

- [ ] **Step 3: Реализация**

`Sources/DiscUsageUI/TreemapLayout.swift`:

```swift
import CoreGraphics

/// Squarified treemap (Bruls, Huizing, van Wijk).
/// values — по убыванию; выход выровнен по индексам входа.
public enum TreemapLayout {
    public static func squarify(values: [Double], in rect: CGRect) -> [CGRect] {
        guard !values.isEmpty else { return [] }
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else {
            return Array(repeating: CGRect(origin: rect.origin, size: .zero), count: values.count)
        }
        let scale = rect.width * rect.height / total
        let areas = values.map { $0 * scale }

        var result: [CGRect] = []
        var remaining = rect
        var row: [Double] = []
        var index = 0
        while index < areas.count {
            let area = areas[index]
            if area <= 0 { break }
            let side = min(remaining.width, remaining.height)
            if row.isEmpty || worstAspect(row + [area], side) <= worstAspect(row, side) {
                row.append(area)
                index += 1
            } else {
                result.append(contentsOf: layoutRow(row, in: &remaining))
                row = []
            }
        }
        if !row.isEmpty {
            result.append(contentsOf: layoutRow(row, in: &remaining))
        }
        while result.count < values.count {
            result.append(CGRect(origin: remaining.origin, size: .zero))
        }
        return result
    }

    private static func worstAspect(_ row: [Double], _ side: Double) -> Double {
        guard !row.isEmpty, side > 0 else { return .infinity }
        let sum = row.reduce(0, +)
        guard sum > 0, let maxArea = row.max(), let minArea = row.min(), minArea > 0 else {
            return .infinity
        }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return Swift.max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    private static func layoutRow(_ row: [Double], in remaining: inout CGRect) -> [CGRect] {
        let sum = row.reduce(0, +)
        var rects: [CGRect] = []
        if remaining.width >= remaining.height {
            let stripWidth = sum / remaining.height
            var y = remaining.minY
            for area in row {
                let height = area / stripWidth
                rects.append(CGRect(x: remaining.minX, y: y, width: stripWidth, height: height))
                y += height
            }
            remaining = CGRect(
                x: remaining.minX + stripWidth, y: remaining.minY,
                width: remaining.width - stripWidth, height: remaining.height)
        } else {
            let stripHeight = sum / remaining.width
            var x = remaining.minX
            for area in row {
                let width = area / stripHeight
                rects.append(CGRect(x: x, y: remaining.minY, width: width, height: stripHeight))
                x += width
            }
            remaining = CGRect(
                x: remaining.minX, y: remaining.minY + stripHeight,
                width: remaining.width, height: remaining.height - stripHeight)
        }
        return rects
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter TreemapLayoutTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/DiscUsageUI/TreemapLayout.swift Tests/DiscUsageUITests/TreemapLayoutTests.swift
git commit -m "feat: squarified-раскладка для treemap"
```

---

### Task 13: DiscUsageUI — утилиты (форматтер, цвета, FDA)

**Files:**
- Create: `Sources/DiscUsageUI/ByteFormatter.swift`, `Sources/DiscUsageUI/NodeColor.swift`, `Sources/DiscUsageUI/FullDiskAccessChecker.swift`
- Test: `Tests/DiscUsageUITests/UtilitiesTests.swift`

**Interfaces:**
- Consumes: `FileNode` (ScanKit).
- Produces: `ByteFormatter.string(_ bytes: Int64) -> String`; `ContentCategory { media, code, archive, document, caches, directory, other }`; `NodeColor.category(for node: FileNode) -> ContentCategory`, `NodeColor.color(for: ContentCategory) -> Color`; `FullDiskAccessChecker(probePaths: [String] = <дефолт>)` c `hasFullDiskAccess() -> Bool`.

- [ ] **Step 1: Написать падающие тесты**

`Tests/DiscUsageUITests/UtilitiesTests.swift`:

```swift
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
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'ByteFormatter'`)

Run: `swift test --filter UtilitiesTests`

- [ ] **Step 3: Реализация**

`Sources/DiscUsageUI/ByteFormatter.swift`:

```swift
import Foundation

public enum ByteFormatter {
    public static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
```

`Sources/DiscUsageUI/NodeColor.swift`:

```swift
import ScanKit
import SwiftUI

public enum ContentCategory: Sendable, Equatable {
    case media, code, archive, document, caches, directory, other
}

public enum NodeColor {
    private static let mediaExtensions: Set<String> = [
        "mp4", "mov", "mkv", "avi", "jpg", "jpeg", "png", "heic", "gif", "mp3",
        "wav", "aac", "flac", "raw", "tiff", "webp", "webm",
    ]
    private static let codeExtensions: Set<String> = [
        "swift", "kt", "java", "ts", "tsx", "js", "py", "go", "rs", "c", "cpp",
        "h", "m", "rb", "sh", "json", "yaml", "yml", "xml", "html", "css",
    ]
    private static let archiveExtensions: Set<String> = [
        "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "iso", "xip", "pkg", "jar",
    ]
    private static let documentExtensions: Set<String> = [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "pages",
        "numbers", "key", "rtf", "csv",
    ]
    private static let cacheDirectoryNames: Set<String> = [
        "caches", "cache", "deriveddata", "tmp", "temp", ".trash", "logs",
    ]

    public static func category(for node: FileNode) -> ContentCategory {
        if node.kind != .file {
            return cacheDirectoryNames.contains(node.name.lowercased()) ? .caches : .directory
        }
        let ext = (node.name as NSString).pathExtension.lowercased()
        if mediaExtensions.contains(ext) { return .media }
        if codeExtensions.contains(ext) { return .code }
        if archiveExtensions.contains(ext) { return .archive }
        if documentExtensions.contains(ext) { return .document }
        return .other
    }

    public static func color(for category: ContentCategory) -> Color {
        switch category {
        case .media: .purple
        case .code: .teal
        case .archive: .orange
        case .document: .blue
        case .caches: .brown
        case .directory: .indigo
        case .other: .gray
        }
    }
}
```

`Sources/DiscUsageUI/FullDiskAccessChecker.swift`:

```swift
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
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter UtilitiesTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/DiscUsageUI Tests/DiscUsageUITests
git commit -m "feat: форматтер размеров, цвета категорий и проверка Full Disk Access"
```

---

### Task 14: DiscUsageUI — AppState

**Files:**
- Create: `Sources/DiscUsageUI/AppState.swift`
- Test: `Tests/DiscUsageUITests/AppStateTests.swift`

**Interfaces:**
- Consumes: `DiskScanner`, `ScanConfiguration`, `ScanResult`, `ScanProgress`, `FileNode`, `TreeRebuilder`.
- Produces (`@MainActor @Observable public final class AppState`):
  - `Phase { idle, scanning(ScanProgress?), finished(ScanResult), failed(String) }`, `phase: Phase` (private(set)).
  - `SidebarSection: String, CaseIterable, Identifiable { overview, largeFiles, cleanup }`; `sidebarSelection: SidebarSection?` (= .overview).
  - `configuration: ScanConfiguration`; `init(configuration: ScanConfiguration = .wholeDisk(), scanner: DiskScanner = DiskScanner())`.
  - `rootNode: FileNode?`, `currentNode: FileNode?`, `breadcrumb: [FileNode]` (цепочка НИЖЕ корня), `currentRelativePath: [String]`, `currentPathString: String`.
  - `startScan()`, `cancelScan()`, `drillDown(into:)`, `navigateToBreadcrumb(index:)`, `navigateToRoot()`.
  - `replaceResult(_ result: ScanResult)` — переустанавливает дерево и пере-резолвит breadcrumb по именам.
  - `removeNodes(atAbsolutePaths: [String])` — выкидывает узлы из дерева через `TreeRebuilder.removingNode`.
  - `rescanCurrentDirectory()` — точечный рескан текущей директории в фоне.

- [ ] **Step 1: Написать падающие тесты**

`Tests/DiscUsageUITests/AppStateTests.swift`:

```swift
import Foundation
import Testing
import ScanKit
@testable import DiscUsageUI

private func makeFixtureTree() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("discusage-ui-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
    try Data(repeating: 0x61, count: 10_000)
        .write(to: root.appendingPathComponent("docs/report.dat"))
    try Data(repeating: 0x61, count: 5_000)
        .write(to: root.appendingPathComponent("top.dat"))
    return root
}

@MainActor
private func finishedState(root: URL) async throws -> AppState {
    let state = AppState(configuration: ScanConfiguration(rootURL: root))
    state.startScan()
    for _ in 0..<200 {
        if case .finished = state.phase { break }
        try await Task.sleep(for: .milliseconds(25))
    }
    guard case .finished = state.phase else {
        Issue.record("скан не завершился за 5 секунд")
        throw CancellationError()
    }
    return state
}

@MainActor @Test func scanReachesFinishedPhase() async throws {
    let root = try makeFixtureTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try await finishedState(root: root)
    #expect(state.rootNode != nil)
    #expect(state.rootNode?.child(named: "docs") != nil)
}

@MainActor @Test func drillDownAndBreadcrumbNavigation() async throws {
    let root = try makeFixtureTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try await finishedState(root: root)
    let docs = try #require(state.rootNode?.child(named: "docs"))

    state.drillDown(into: docs)
    #expect(state.currentNode === docs)
    #expect(state.currentRelativePath == ["docs"])
    #expect(state.currentPathString == root.path + "/docs")

    state.navigateToRoot()
    #expect(state.currentNode === state.rootNode)

    let file = try #require(docs.child(named: "report.dat"))
    state.drillDown(into: file)  // файлы не открываются
    #expect(state.currentNode === state.rootNode)
}

@MainActor @Test func removeNodesUpdatesTreeAndReplaceResultReresolvesBreadcrumb() async throws {
    let root = try makeFixtureTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let state = try await finishedState(root: root)
    let sizeBefore = try #require(state.rootNode?.size)
    let docs = try #require(state.rootNode?.child(named: "docs"))
    state.drillDown(into: docs)

    state.removeNodes(atAbsolutePaths: [root.path + "/docs/report.dat"])

    let newDocs = try #require(state.rootNode?.child(named: "docs"))
    #expect(newDocs.children.isEmpty)
    #expect(try #require(state.rootNode?.size) < sizeBefore)
    // breadcrumb пере-резолвился на новый узел с тем же именем
    #expect(state.currentNode === newDocs)
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'AppState'`)

Run: `swift test --filter AppStateTests`

- [ ] **Step 3: Реализация**

`Sources/DiscUsageUI/AppState.swift`:

```swift
import Foundation
import Observation
import ScanKit

@MainActor
@Observable
public final class AppState {
    public enum Phase {
        case idle
        case scanning(ScanProgress?)
        case finished(ScanResult)
        case failed(String)
    }

    public enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
        case overview, largeFiles, cleanup
        public var id: String { rawValue }
    }

    public private(set) var phase: Phase = .idle
    public var sidebarSelection: SidebarSection? = .overview
    public private(set) var breadcrumb: [FileNode] = []
    public let configuration: ScanConfiguration

    private let scanner: DiskScanner
    private var scanTask: Task<Void, Never>?

    public init(
        configuration: ScanConfiguration = .wholeDisk(),
        scanner: DiskScanner = DiskScanner()
    ) {
        self.configuration = configuration
        self.scanner = scanner
    }

    public var rootNode: FileNode? {
        if case .finished(let result) = phase { return result.root }
        return nil
    }

    public var currentNode: FileNode? { breadcrumb.last ?? rootNode }

    public var currentRelativePath: [String] { breadcrumb.map(\.name) }

    public var currentPathString: String {
        let rootPath = configuration.rootURL.path
        let names = currentRelativePath
        guard !names.isEmpty else { return rootPath }
        let joined = names.joined(separator: "/")
        return rootPath == "/" ? "/" + joined : rootPath + "/" + joined
    }

    public func startScan() {
        guard scanTask == nil else { return }
        phase = .scanning(nil)
        breadcrumb = []
        let scanner = self.scanner
        let configuration = self.configuration
        scanTask = Task { [weak self] in
            do {
                let result = try await scanner.scan(configuration: configuration) { progress in
                    Task { @MainActor [weak self] in
                        if case .scanning = self?.phase { self?.phase = .scanning(progress) }
                    }
                }
                self?.phase = .finished(result)
            } catch is CancellationError {
                self?.phase = .idle
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
            self?.scanTask = nil
        }
    }

    public func cancelScan() { scanTask?.cancel() }

    public func drillDown(into node: FileNode) {
        guard node.kind == .directory else { return }
        breadcrumb.append(node)
    }

    public func navigateToBreadcrumb(index: Int) {
        breadcrumb = Array(breadcrumb.prefix(index + 1))
    }

    public func navigateToRoot() { breadcrumb = [] }

    public func replaceResult(_ result: ScanResult) {
        var node = result.root
        var resolved: [FileNode] = []
        for name in breadcrumb.map(\.name) {
            guard let child = node.child(named: name), child.kind == .directory else { break }
            resolved.append(child)
            node = child
        }
        phase = .finished(result)
        breadcrumb = resolved
    }

    public func removeNodes(atAbsolutePaths paths: [String]) {
        guard case .finished(let result) = phase else { return }
        var root = result.root
        let rootPath = configuration.rootURL.path
        for path in paths {
            guard path.hasPrefix(rootPath) else { continue }
            let relative = path.dropFirst(rootPath.count)
                .split(separator: "/").map(String.init)
            guard !relative.isEmpty else { continue }
            if let updated = TreeRebuilder.removingNode(at: relative, in: root) {
                root = updated
            }
        }
        replaceResult(ScanResult(root: root, inaccessiblePaths: result.inaccessiblePaths))
    }

    public func rescanCurrentDirectory() {
        guard case .finished(let result) = phase else { return }
        let path = currentRelativePath
        let scanner = self.scanner
        let configuration = self.configuration
        Task { [weak self] in
            guard let updated = try? await scanner.rescanSubtree(
                at: path, in: result, configuration: configuration) else { return }
            self?.replaceResult(updated)
        }
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test --filter AppStateTests`

- [ ] **Step 5: Commit**

```bash
git add Sources/DiscUsageUI/AppState.swift Tests/DiscUsageUITests/AppStateTests.swift
git commit -m "feat: AppState — фазы скана, drill-down и обновление дерева"
```

---

### Task 15: DiscUsageUI — каркас приложения и экран «Обзор»

UI-таск: логика уже покрыта тестами (T12–T14), вьюхи проверяются сборкой и ручным запуском.

**Files:**
- Create: `Sources/DiscUsageUI/RootView.swift`, `Sources/DiscUsageUI/MainSplitView.swift`, `Sources/DiscUsageUI/OverviewView.swift`, `Sources/DiscUsageUI/TreemapView.swift`
- Modify: `Sources/DiscUsage/DiscUsageApp.swift`

**Interfaces:**
- Consumes: `AppState`, `TreemapLayout`, `NodeColor`, `ByteFormatter`, `SystemFileRemover` (CleanupKit).
- Produces: `public struct RootView: View` (единственная публичная вьюха — точка входа для exe); внутренние `MainSplitView`, `OverviewView`, `BreadcrumbBar`, `TreemapView`, `TreemapCell` + временные заглушки `LargeFilesView`, `CleanupView` (заменяются в T16/T17).

- [ ] **Step 1: Реализация**

`Sources/DiscUsage/DiscUsageApp.swift` (заменить целиком):

```swift
import DiscUsageUI
import SwiftUI

@main
struct DiscUsageApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}
```

`Sources/DiscUsageUI/RootView.swift`:

```swift
import SwiftUI

public struct RootView: View {
    @State private var appState = AppState()

    public init() {}

    public var body: some View {
        MainSplitView()
            .environment(appState)
            .frame(minWidth: 900, minHeight: 600)
    }
}
```

`Sources/DiscUsageUI/MainSplitView.swift`:

```swift
import SwiftUI

extension AppState.SidebarSection {
    var title: String {
        switch self {
        case .overview: "Обзор"
        case .largeFiles: "Большие файлы"
        case .cleanup: "Очистка"
        }
    }

    var icon: String {
        switch self {
        case .overview: "chart.pie"
        case .largeFiles: "doc.zipper"
        case .cleanup: "trash"
        }
    }
}

struct MainSplitView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            List(AppState.SidebarSection.allCases, selection: $appState.sidebarSelection) { section in
                Label(section.title, systemImage: section.icon).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch appState.sidebarSelection ?? .overview {
            case .overview: OverviewView()
            case .largeFiles: LargeFilesView()
            case .cleanup: CleanupView()
            }
        }
        .navigationTitle("DiscUsage")
        .toolbar {
            ToolbarItem {
                switch appState.phase {
                case .scanning:
                    Button("Остановить", systemImage: "stop.circle") { appState.cancelScan() }
                default:
                    Button("Сканировать диск", systemImage: "arrow.clockwise") {
                        appState.startScan()
                    }
                }
            }
        }
    }
}

// Заглушки — заменяются в Task 16 и Task 17 отдельными файлами.
struct LargeFilesView: View {
    var body: some View {
        ContentUnavailableView("Большие файлы", systemImage: "doc.zipper",
                               description: Text("Появится в Task 16"))
    }
}

struct CleanupView: View {
    var body: some View {
        ContentUnavailableView("Очистка", systemImage: "trash",
                               description: Text("Появится в Task 17"))
    }
}
```

`Sources/DiscUsageUI/OverviewView.swift`:

```swift
import AppKit
import CleanupKit
import ScanKit
import SwiftUI

struct OverviewView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: (node: FileNode, path: String)?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            switch appState.phase {
            case .idle:
                ContentUnavailableView(
                    "Нет данных", systemImage: "externaldrive",
                    description: Text("Нажмите «Сканировать диск», чтобы построить карту диска."))
            case .scanning(let progress):
                VStack(spacing: 12) {
                    ProgressView()
                    if let progress {
                        Text("\(progress.scannedItems) объектов · \(ByteFormatter.string(progress.totalBytes))")
                            .monospacedDigit()
                        Text(progress.currentPath)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                            .frame(maxWidth: 500)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView(
                    "Ошибка сканирования", systemImage: "exclamationmark.triangle",
                    description: Text(message))
            case .finished(let result):
                finishedBody(result)
            }
        }
        .alert("Не удалось удалить", isPresented: .init(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func finishedBody(_ result: ScanResult) -> some View {
        VStack(spacing: 0) {
            BreadcrumbBar()
            if let node = appState.currentNode {
                TreemapView(
                    node: node,
                    parentPath: appState.currentPathString,
                    onOpen: { appState.drillDown(into: $0); selection = nil },
                    onSelect: { node, path in selection = (node, path) },
                    onTrash: { trash(path: $1) })
                .padding(8)
            }
            if let selection {
                Divider()
                HStack(spacing: 12) {
                    Text(selection.path).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(ByteFormatter.string(selection.node.size)).monospacedDigit()
                    Button("Показать в Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: selection.path)])
                    }
                    Button("В Корзину", role: .destructive) { trash(path: selection.path) }
                }
                .padding(8)
            }
            if !result.inaccessiblePaths.isEmpty {
                Text("Нет доступа к \(result.inaccessiblePaths.count) папкам — они посчитаны как 0 байт.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
    }

    private func trash(path: String) {
        do {
            try SystemFileRemover().trash(URL(filePath: path))
            appState.removeNodes(atAbsolutePaths: [path])
            selection = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BreadcrumbBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 4) {
            Button(appState.configuration.rootURL.path) { appState.navigateToRoot() }
                .buttonStyle(.link)
            ForEach(Array(appState.breadcrumb.enumerated()), id: \.offset) { index, node in
                Text("›").foregroundStyle(.secondary)
                Button(node.name) { appState.navigateToBreadcrumb(index: index) }
                    .buttonStyle(.link)
            }
            Spacer()
            if let node = appState.currentNode {
                Text(ByteFormatter.string(node.size))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
```

`Sources/DiscUsageUI/TreemapView.swift`:

```swift
import AppKit
import ScanKit
import SwiftUI

struct TreemapView: View {
    let node: FileNode
    let parentPath: String
    let onOpen: (FileNode) -> Void
    let onSelect: (FileNode, String) -> Void
    let onTrash: (FileNode, String) -> Void

    @State private var hoveredID: FileNode.ID?

    var body: some View {
        GeometryReader { proxy in
            let children = node.children.filter { $0.size > 0 }
            let rects = TreemapLayout.squarify(
                values: children.map { Double($0.size) },
                in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(children, rects)), id: \.0.id) { child, rect in
                    if rect.width >= 1, rect.height >= 1 {
                        cell(for: child, rect: rect)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for child: FileNode, rect: CGRect) -> some View {
        let path = absolutePath(of: child)
        TreemapCell(node: child, rect: rect, isHovered: hoveredID == child.id)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onHover { hovering in
                if hovering {
                    hoveredID = child.id
                } else if hoveredID == child.id {
                    hoveredID = nil
                }
            }
            .onTapGesture {
                if child.kind == .directory { onOpen(child) } else { onSelect(child, path) }
            }
            .contextMenu {
                Button("Показать в Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
                }
                Button("Скопировать путь") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
                Divider()
                Button("В Корзину", role: .destructive) { onTrash(child, path) }
            }
            .help("\(path) — \(ByteFormatter.string(child.size))")
    }

    private func absolutePath(of child: FileNode) -> String {
        parentPath == "/" ? "/" + child.name : parentPath + "/" + child.name
    }
}

struct TreemapCell: View {
    let node: FileNode
    let rect: CGRect
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(NodeColor.color(for: NodeColor.category(for: node))
                .opacity(isHovered ? 1.0 : 0.8))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.background, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                if rect.width > 64, rect.height > 30 {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(node.name).font(.caption).bold().lineLimit(1)
                        Text(ByteFormatter.string(node.size)).font(.caption2).opacity(0.85)
                    }
                    .padding(4)
                    .foregroundStyle(.white)
                }
            }
    }
}
```

- [ ] **Step 2: Собрать и прогнать тесты**

Run: `swift build && swift test`
Expected: сборка и все тесты зелёные.

- [ ] **Step 3: Ручная проверка**

Run: `swift run DiscUsage` (скан всего диска без FDA даст много «нет доступа» — для проверки достаточно домашней папки; альтернативно временно поменять конфигурацию не нужно — просто убедиться, что:)
- окно открывается, сайдбар из трёх разделов;
- «Сканировать диск» запускает скан, виден прогресс (счётчик + текущий путь);
- по окончании — treemap; клик по папке проваливается, хлебные крошки возвращают;
- клик по файлу показывает нижнюю панель; контекстное меню работает («Показать в Finder», «Скопировать путь»);
- «Остановить» прерывает скан без падения.

Завершить приложение Cmd+Q.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiscUsage Sources/DiscUsageUI
git commit -m "feat: каркас приложения — сайдбар, обзор с treemap и drill-down"
```

---

### Task 16: DiscUsageUI — экран «Большие файлы»

**Files:**
- Create: `Sources/DiscUsageUI/LargeFilesViewModel.swift`, `Sources/DiscUsageUI/LargeFilesView.swift`
- Modify: `Sources/DiscUsageUI/MainSplitView.swift` — удалить заглушку `LargeFilesView`
- Test: `Tests/DiscUsageUITests/LargeFilesViewModelTests.swift`

**Interfaces:**
- Consumes: `LargeFileCollector`, `LargeFileEntry`, `FileNode`, `SystemFileRemover`, `AppState.removeNodes`.
- Produces (`@MainActor @Observable public final class LargeFilesViewModel`): `minimumSize: Int64` (= 50 МБ), `entries: [LargeFileEntry]` (private(set)), `selectedPaths: Set<String>`, `refresh(root: FileNode?, rootPath: String)`, `selectedTotalBytes: Int64`, `entriesToDelete() -> [LargeFileEntry]`.

- [ ] **Step 1: Написать падающие тесты**

`Tests/DiscUsageUITests/LargeFilesViewModelTests.swift`:

```swift
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
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'LargeFilesViewModel'`)

Run: `swift test --filter LargeFilesViewModelTests`

- [ ] **Step 3: Реализация**

`Sources/DiscUsageUI/LargeFilesViewModel.swift`:

```swift
import Foundation
import Observation
import ScanKit

@MainActor
@Observable
public final class LargeFilesViewModel {
    public var minimumSize: Int64 = 50 * 1024 * 1024
    public private(set) var entries: [LargeFileEntry] = []
    public var selectedPaths: Set<String> = []

    public init() {}

    public func refresh(root: FileNode?, rootPath: String) {
        guard let root else {
            entries = []
            selectedPaths = []
            return
        }
        entries = LargeFileCollector.topFiles(
            in: root, rootPath: rootPath, minimumSize: minimumSize)
        selectedPaths = selectedPaths.intersection(Set(entries.map(\.path)))
    }

    public var selectedTotalBytes: Int64 {
        entries.filter { selectedPaths.contains($0.path) }.reduce(0) { $0 + $1.size }
    }

    public func entriesToDelete() -> [LargeFileEntry] {
        entries.filter { selectedPaths.contains($0.path) }
    }
}
```

В `Sources/DiscUsageUI/MainSplitView.swift` удалить заглушку `struct LargeFilesView` (блок из ~5 строк с `ContentUnavailableView("Большие файлы"...)`).

`Sources/DiscUsageUI/LargeFilesView.swift`:

```swift
import CleanupKit
import ScanKit
import SwiftUI

struct LargeFilesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = LargeFilesViewModel()
    @State private var confirmingDeletion = false
    @State private var errorMessage: String?

    private static let sizeOptions: [Int64] = [
        50 * 1024 * 1024, 100 * 1024 * 1024, 500 * 1024 * 1024, 1024 * 1024 * 1024,
    ]

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            HStack {
                Picker("Не меньше", selection: $viewModel.minimumSize) {
                    ForEach(Self.sizeOptions, id: \.self) { option in
                        Text(ByteFormatter.string(option)).tag(option)
                    }
                }
                .frame(maxWidth: 220)
                Spacer()
                Button("В Корзину (\(ByteFormatter.string(viewModel.selectedTotalBytes)))",
                       role: .destructive) {
                    confirmingDeletion = true
                }
                .disabled(viewModel.selectedPaths.isEmpty)
            }
            .padding(12)
            if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "Нет больших файлов", systemImage: "doc.zipper",
                    description: Text("Сначала просканируйте диск на вкладке «Обзор»."))
            } else {
                Table(viewModel.entries) {
                    TableColumn("✓") { entry in
                        Toggle("", isOn: selectionBinding(for: entry.path)).labelsHidden()
                    }
                    .width(28)
                    TableColumn("Путь") { entry in
                        Text(entry.path).lineLimit(1).truncationMode(.middle)
                    }
                    TableColumn("Размер") { entry in
                        Text(ByteFormatter.string(entry.size)).monospacedDigit()
                    }
                    .width(110)
                }
            }
        }
        .onAppear { refresh() }
        .onChange(of: viewModel.minimumSize) { refresh() }
        .onChange(of: appState.rootNode) { refresh() }
        .confirmationDialog(
            "Переместить в Корзину \(viewModel.entriesToDelete().count) файлов (\(ByteFormatter.string(viewModel.selectedTotalBytes)))?",
            isPresented: $confirmingDeletion, titleVisibility: .visible
        ) {
            Button("В Корзину", role: .destructive) { deleteSelected() }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Часть файлов не удалена", isPresented: .init(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func selectionBinding(for path: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.selectedPaths.contains(path) },
            set: { selected in
                if selected {
                    viewModel.selectedPaths.insert(path)
                } else {
                    viewModel.selectedPaths.remove(path)
                }
            })
    }

    private func refresh() {
        viewModel.refresh(root: appState.rootNode, rootPath: appState.configuration.rootURL.path)
    }

    private func deleteSelected() {
        let remover = SystemFileRemover()
        var deletedPaths: [String] = []
        var failures: [String] = []
        for entry in viewModel.entriesToDelete() {
            do {
                try remover.trash(URL(filePath: entry.path))
                deletedPaths.append(entry.path)
            } catch {
                failures.append(entry.path)
            }
        }
        appState.removeNodes(atAbsolutePaths: deletedPaths)
        viewModel.selectedPaths.removeAll()
        refresh()
        if !failures.isEmpty {
            errorMessage = "Не удалось удалить: \(failures.joined(separator: ", "))"
        }
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test && swift build`
Expected: все тесты зелёные, сборка успешна.

- [ ] **Step 5: Ручная проверка и Commit**

Run: `swift run DiscUsage` — просканировать, открыть «Большие файлы»: таблица заполнена, фильтр размера меняет список, чекбоксы считают сумму на кнопке.

```bash
git add Sources/DiscUsageUI Tests/DiscUsageUITests
git commit -m "feat: экран больших файлов с фильтром и массовым удалением"
```

---

### Task 17: DiscUsageUI — экран «Очистка»

**Files:**
- Create: `Sources/DiscUsageUI/CleanupViewModel.swift`, `Sources/DiscUsageUI/CleanupView.swift`
- Modify: `Sources/DiscUsageUI/MainSplitView.swift` — удалить заглушку `CleanupView`
- Test: `Tests/DiscUsageUITests/CleanupViewModelTests.swift`

**Interfaces:**
- Consumes: `JunkScanner`, `LprojScanner`, `CleanupExecutor`, `CleanupItem`, `CleanupCategory`, `CleanupReport`, `AppState.removeNodes`.
- Produces (`@MainActor @Observable public final class CleanupViewModel`):
  - `init(junkScanner: JunkScanner = JunkScanner(), lprojScanner: LprojScanner = LprojScanner(), executor: CleanupExecutor = CleanupExecutor())`.
  - `items: [CleanupItem]` (private(set), sorted size desc), `selectedIDs: Set<String>`, `isScanning: Bool` (private(set)), `deletePermanently: Bool`, `lastReport: CleanupReport?` (private(set)).
  - `scan() async` — junk + lproj; дефолтный выбор = `enabledByDefault && deletable`.
  - `items(in: CleanupCategory) -> [CleanupItem]`, `totalSize(in: CleanupCategory) -> Int64`, `selectedItems: [CleanupItem]`, `selectedTotalBytes: Int64`, `confirmationMessage: String`.
  - `executeSelected() async -> CleanupReport` — удаляет, выкидывает удалённые из `items`/`selectedIDs`.

- [ ] **Step 1: Написать падающие тесты**

`Tests/DiscUsageUITests/CleanupViewModelTests.swift`:

```swift
import Foundation
import Testing
import CleanupKit
@testable import DiscUsageUI

private final class UIMockRemover: FileRemoving, @unchecked Sendable {
    private let lock = NSLock()
    var trashed: [String] = []
    func trash(_ url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        trashed.append(url.path)
    }
    func removePermanently(_ url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        trashed.append("PERM:" + url.path)
    }
}

private func makeFixtureHome() throws -> URL {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("discusage-cvm-\(UUID().uuidString)")
    let caches = home.appendingPathComponent("Library/Caches/AppOne")
    try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    try Data(repeating: 0x61, count: 50_000).write(to: caches.appendingPathComponent("blob.bin"))
    return home
}

@MainActor @Test func scanSelectsDefaultsAndComputesTotals() async throws {
    let home = try makeFixtureHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let viewModel = CleanupViewModel(
        junkScanner: JunkScanner(environment: environment),
        lprojScanner: LprojScanner(applicationsDirectory: home.appendingPathComponent("Applications")),
        executor: CleanupExecutor(remover: UIMockRemover()))

    await viewModel.scan()

    #expect(viewModel.items.count == 1)
    #expect(viewModel.items[0].title == "AppOne")
    #expect(viewModel.selectedIDs == Set(viewModel.items.map(\.id)))
    #expect(viewModel.totalSize(in: .systemJunk) >= 50_000)
    #expect(viewModel.items(in: .developerJunk).isEmpty)
    #expect(viewModel.selectedTotalBytes >= 50_000)
    #expect(viewModel.confirmationMessage.contains("1"))
}

@MainActor @Test func executeSelectedRemovesDeletedItems() async throws {
    let home = try makeFixtureHome()
    defer { try? FileManager.default.removeItem(at: home) }
    let environment = CleanupEnvironment(homeDirectory: home, rootDirectory: home)
    let remover = UIMockRemover()
    let viewModel = CleanupViewModel(
        junkScanner: JunkScanner(environment: environment),
        lprojScanner: LprojScanner(applicationsDirectory: home.appendingPathComponent("Applications")),
        executor: CleanupExecutor(remover: remover))
    await viewModel.scan()

    let report = await viewModel.executeSelected()

    #expect(report.deleted.count == 1)
    #expect(report.failed.isEmpty)
    #expect(remover.trashed.count == 1)
    #expect(viewModel.items.isEmpty)
    #expect(viewModel.selectedIDs.isEmpty)
    #expect(viewModel.lastReport?.deleted.count == 1)
}

@MainActor @Test func confirmationMessageWarnsAboutPermanentAndTrash() async throws {
    let viewModel = CleanupViewModel()
    viewModel.deletePermanently = true
    #expect(viewModel.confirmationMessage.contains("навсегда"))
}
```

- [ ] **Step 2: Запустить — FAIL** (`cannot find 'CleanupViewModel'`)

Run: `swift test --filter CleanupViewModelTests`

- [ ] **Step 3: Реализация**

`Sources/DiscUsageUI/CleanupViewModel.swift`:

```swift
import CleanupKit
import Foundation
import Observation

@MainActor
@Observable
public final class CleanupViewModel {
    public private(set) var items: [CleanupItem] = []
    public var selectedIDs: Set<String> = []
    public private(set) var isScanning = false
    public var deletePermanently = false
    public private(set) var lastReport: CleanupReport?

    private let junkScanner: JunkScanner
    private let lprojScanner: LprojScanner
    private let executor: CleanupExecutor

    public init(
        junkScanner: JunkScanner = JunkScanner(),
        lprojScanner: LprojScanner = LprojScanner(),
        executor: CleanupExecutor = CleanupExecutor()
    ) {
        self.junkScanner = junkScanner
        self.lprojScanner = lprojScanner
        self.executor = executor
    }

    public func scan() async {
        isScanning = true
        defer { isScanning = false }
        var found = await junkScanner.scan()
        found += await lprojScanner.scan()
        items = found.sorted { $0.size > $1.size }
        selectedIDs = Set(items.filter { $0.enabledByDefault && $0.deletable }.map(\.id))
    }

    public func items(in category: CleanupCategory) -> [CleanupItem] {
        items.filter { $0.category == category }
    }

    public func totalSize(in category: CleanupCategory) -> Int64 {
        items(in: category).reduce(0) { $0 + $1.size }
    }

    public var selectedItems: [CleanupItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    public var selectedTotalBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    public var confirmationMessage: String {
        var message = "Будет удалено \(selectedItems.count) элементов"
            + " (\(ByteFormatter.string(selectedTotalBytes)))."
        if deletePermanently {
            message += " Удаление навсегда — мимо Корзины!"
        }
        if selectedItems.contains(where: { $0.permanentOnly }) {
            message += " Очистка Корзины необратима."
        }
        if selectedItems.contains(where: { $0.category == .browserData }) {
            message += " Перед очисткой закройте браузеры."
        }
        return message
    }

    public func executeSelected() async -> CleanupReport {
        let report = await executor.execute(items: selectedItems, permanently: deletePermanently)
        let deletedIDs = Set(report.deleted.map(\.id))
        items.removeAll { deletedIDs.contains($0.id) }
        selectedIDs.subtract(deletedIDs)
        lastReport = report
        return report
    }
}
```

В `Sources/DiscUsageUI/MainSplitView.swift` удалить заглушку `struct CleanupView`.

`Sources/DiscUsageUI/CleanupView.swift`:

```swift
import CleanupKit
import SwiftUI

extension CleanupCategory {
    var title: String {
        switch self {
        case .systemJunk: "Системный мусор"
        case .developerJunk: "Мусор разработчика"
        case .browserData: "Браузеры"
        case .miscellaneous: "Локализации и прочее"
        }
    }
}

struct CleanupView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CleanupViewModel()
    @State private var confirming = false
    @State private var reportMessage: String?

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            if viewModel.items.isEmpty, !viewModel.isScanning {
                ContentUnavailableView(
                    "Мусор ещё не искали", systemImage: "trash",
                    description: Text("Нажмите «Найти мусор» — поиск идёт только по известным безопасным расположениям."))
            } else if viewModel.isScanning {
                ProgressView("Ищем мусор…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(CleanupCategory.allCases, id: \.self) { category in
                        let categoryItems = viewModel.items(in: category)
                        if !categoryItems.isEmpty {
                            Section("\(category.title) — \(ByteFormatter.string(viewModel.totalSize(in: category)))") {
                                ForEach(categoryItems) { item in
                                    CleanupItemRow(item: item, viewModel: viewModel)
                                }
                            }
                        }
                    }
                }
            }
            Divider()
            HStack {
                Button("Найти мусор", systemImage: "magnifyingglass") {
                    Task { await viewModel.scan() }
                }
                .disabled(viewModel.isScanning)
                Spacer()
                Toggle("Удалять навсегда", isOn: $viewModel.deletePermanently)
                Button("Очистить (\(ByteFormatter.string(viewModel.selectedTotalBytes)))",
                       role: .destructive) {
                    confirming = true
                }
                .disabled(viewModel.selectedItems.isEmpty)
            }
            .padding(12)
        }
        .confirmationDialog(
            viewModel.confirmationMessage, isPresented: $confirming, titleVisibility: .visible
        ) {
            Button("Очистить", role: .destructive) { Task { await runCleanup() } }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Очистка завершена", isPresented: .init(
            get: { reportMessage != nil }, set: { if !$0 { reportMessage = nil } })
        ) {
            Button("OK") { reportMessage = nil }
        } message: {
            Text(reportMessage ?? "")
        }
    }

    private func runCleanup() async {
        let report = await viewModel.executeSelected()
        appState.removeNodes(atAbsolutePaths: report.deleted.compactMap { $0.url?.path })
        var message = "Удалено: \(report.deleted.count) (\(ByteFormatter.string(report.freedBytes)))."
        if !report.failed.isEmpty {
            message += " Пропущено: \(report.failed.count) — \(report.failed.map { $0.message }.prefix(3).joined(separator: "; "))."
        }
        reportMessage = message
    }
}

struct CleanupItemRow: View {
    let item: CleanupItem
    @Bindable var viewModel: CleanupViewModel

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { viewModel.selectedIDs.contains(item.id) },
                set: { selected in
                    if selected {
                        viewModel.selectedIDs.insert(item.id)
                    } else {
                        viewModel.selectedIDs.remove(item.id)
                    }
                }))
            .labelsHidden()
            .disabled(!item.deletable)
            Text(item.safety == .safe ? "🟢" : "🟡")
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                if let url = item.url {
                    Text(url.path)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                } else if let command = item.command {
                    Text("Команда: \(command.executable) \(command.arguments.joined(separator: " "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !item.deletable {
                Text("только просмотр").font(.caption).foregroundStyle(.secondary)
            }
            Text(item.size > 0 ? ByteFormatter.string(item.size) : "—").monospacedDigit()
        }
    }
}
```

- [ ] **Step 4: Запустить — PASS**

Run: `swift test && swift build`

- [ ] **Step 5: Ручная проверка и Commit**

Run: `swift run DiscUsage` — вкладка «Очистка»: «Найти мусор» заполняет категории; история/cookies и Archives сняты по умолчанию; диалог подтверждения содержит объём; НЕ выполняйте реальную очистку на живой машине при проверке (или выбери один маленький кэш).

```bash
git add Sources/DiscUsageUI Tests/DiscUsageUITests
git commit -m "feat: экран очистки — категории, бейджи безопасности, отчёт"
```

---

### Task 18: онбординг FDA, сборка .app, README, покрытие

**Files:**
- Create: `Sources/DiscUsageUI/OnboardingView.swift`, `Scripts/build-app.sh`, `Scripts/Info.plist`, `README.md`
- Modify: `Sources/DiscUsageUI/RootView.swift`

**Interfaces:**
- Consumes: `FullDiskAccessChecker`.
- Produces: гейт FDA в `RootView`; `Scripts/build-app.sh` → `build/DiscUsage.app` (ad-hoc подпись).

- [ ] **Step 1: OnboardingView и гейт в RootView**

`Sources/DiscUsageUI/OnboardingView.swift`:

```swift
import AppKit
import Combine
import SwiftUI

struct OnboardingView: View {
    let checker: FullDiskAccessChecker
    let onGranted: () -> Void

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Нужен полный доступ к диску").font(.title2).bold()
            Text("Чтобы анализировать весь диск и чистить кэши, выдай DiscUsage право «Полный доступ к диску» в Системных настройках. Приложение продолжит само, как только доступ появится.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Button("Открыть Системные настройки") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            if checker.hasFullDiskAccess() { onGranted() }
        }
    }
}
```

`Sources/DiscUsageUI/RootView.swift` (заменить целиком):

```swift
import SwiftUI

public struct RootView: View {
    @State private var appState = AppState()
    @State private var hasAccess: Bool
    private let checker: FullDiskAccessChecker

    public init(checker: FullDiskAccessChecker = FullDiskAccessChecker()) {
        self.checker = checker
        _hasAccess = State(initialValue: checker.hasFullDiskAccess())
    }

    public var body: some View {
        Group {
            if hasAccess {
                MainSplitView().environment(appState)
            } else {
                OnboardingView(checker: checker) { hasAccess = true }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
```

- [ ] **Step 2: Скрипт сборки .app**

`Scripts/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>ru.dguba.discusage</string>
    <key>CFBundleName</key>
    <string>DiscUsage</string>
    <key>CFBundleExecutable</key>
    <string>DiscUsage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

`Scripts/build-app.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/DiscUsage.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DiscUsage "$APP/Contents/MacOS/DiscUsage"
cp Scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Готово: $APP"
echo "Full Disk Access: Системные настройки → Конфиденциальность и безопасность →"
echo "Полный доступ к диску → добавить $PWD/$APP"
```

Run: `chmod +x Scripts/build-app.sh && ./Scripts/build-app.sh`
Expected: `Готово: build/DiscUsage.app`; `codesign --verify build/DiscUsage.app` — без ошибок; `open build/DiscUsage.app` — приложение запускается (при первом запуске показывает онбординг FDA, если доступ не выдан).

- [ ] **Step 3: README**

`README.md`:

```markdown
# DiscUsage

Бесплатный аналог CleanDiskGo: анализ занятого места на всём диске (treemap)
и безопасная очистка мусора для macOS 15+.

## Возможности

- **Обзор** — treemap всего диска, drill-down по папкам, удаление в Корзину.
- **Большие файлы** — топ-100 тяжёлых файлов с фильтром по размеру.
- **Очистка** — системный мусор, мусор разработчика (DerivedData, симуляторы,
  кэши Gradle/npm/Homebrew), браузерные данные, старые iOS-бэкапы.
  Только белый список путей; по умолчанию — в Корзину.

## Сборка

```bash
./Scripts/build-app.sh   # → build/DiscUsage.app
```

Для разработки: `swift run DiscUsage`; тесты: `swift test`.

## Full Disk Access

Приложению нужен «Полный доступ к диску»: Системные настройки →
Конфиденциальность и безопасность → Полный доступ к диску → добавьте
`build/DiscUsage.app`. Без него часть диска будет видна как «нет доступа».

## Архитектура

SPM-пакет: `ScanKit` (скан диска), `CleanupKit` (правила очистки и удаление),
`DiscUsageUI` (SwiftUI), `DiscUsage` (исполняемый таргет).
Дизайн: `docs/superpowers/specs/2026-07-08-discusage-design.md`.
```

- [ ] **Step 4: Полные тесты + покрытие**

```bash
swift test --enable-code-coverage
BIN=$(swift build --show-bin-path)
xcrun llvm-cov report \
  "$BIN/DiscUsagePackageTests.xctest/Contents/MacOS/DiscUsagePackageTests" \
  -instr-profile "$BIN/codecov/default.profdata" \
  -ignore-filename-regex 'Tests/|Sources/DiscUsage/|View|Info\.swift'
```

Expected: все тесты PASS; для файлов ScanKit и CleanupKit покрытие строк ≥ 80% (UI-вьюхи исключены). Если ниже — дописать тесты на непокрытые ветки (обычно это error-пути) до порога.

- [ ] **Step 5: Финальная ручная проверка и Commit**

Чеклист на собранном `build/DiscUsage.app` (после выдачи FDA):

- [ ] онбординг пропадает сам после выдачи FDA;
- [ ] скан `/` завершается, размеры правдоподобны (сравнить порядок с «Об этом Mac → Хранилище»);
- [ ] treemap: drill-down, крошки, «Показать в Finder», «В Корзину» (проверить на ненужном файле — файл оказывается в Корзине);
- [ ] «Большие файлы»: список, фильтр, массовое удаление в Корзину;
- [ ] «Очистка»: «Найти мусор» находит DerivedData/кэши; удалить один маленький кэш — отчёт корректен;
- [ ] после удаления дерево на «Обзоре» уменьшилось на размер удалённого.

```bash
git add Sources Scripts README.md
git commit -m "feat: онбординг Full Disk Access, сборка .app и README"
```

---

## Порядок и зависимости

T1 → T2 → T3 → T4 → T5 → T6 → T7 (ScanKit) → T8 → T9 → T10 → T11 (CleanupKit)
→ T12 → T13 → T14 (логика UI) → T15 → T16 → T17 → T18 (вьюхи и упаковка).
Каждый таск заканчивается зелёным `swift test` и коммитом.
