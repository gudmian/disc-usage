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
