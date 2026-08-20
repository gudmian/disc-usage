import CleanupKit
import Foundation
import Observation
import UninstallKit

@MainActor
@Observable
public final class AppsViewModel {
    public private(set) var apps: [AppInfo] = []
    public var selectedAppID: String?
    public private(set) var isScanningApps = false
    public private(set) var leftoverItems: [CleanupItem] = []
    public var selectedLeftoverIDs: Set<String> = []
    public private(set) var isScanningLeftovers = false
    public var deletePermanently = false
    public private(set) var lastReport: CleanupReport?

    private let discovery: AppDiscovery
    private let caskDetector: HomebrewCaskDetector
    private let leftoverFinder: BundleLeftoverFinder
    private let executor: CleanupExecutor

    public init(
        discovery: AppDiscovery = AppDiscovery(),
        caskDetector: HomebrewCaskDetector = HomebrewCaskDetector(),
        leftoverFinder: BundleLeftoverFinder = BundleLeftoverFinder(),
        executor: CleanupExecutor = CleanupExecutor()
    ) {
        self.discovery = discovery
        self.caskDetector = caskDetector
        self.leftoverFinder = leftoverFinder
        self.executor = executor
    }

    public var selectedApp: AppInfo? { apps.first { $0.id == selectedAppID } }

    public func scanApps() async {
        isScanningApps = true
        defer { isScanningApps = false }
        let found = await discovery.scan()
        let tokens = await caskDetector.caskTokensByAppPath()
        apps = found
            .map { $0.withHomebrewToken(tokens[$0.url.path]) }
            .sorted { $0.size > $1.size }
    }

    public func selectApp(_ app: AppInfo) async {
        selectedAppID = app.id
        isScanningLeftovers = true
        defer { isScanningLeftovers = false }
        leftoverItems = await leftoverFinder.findLeftovers(for: app)
        selectedLeftoverIDs = Set(leftoverItems.filter { $0.enabledByDefault && $0.deletable }.map(\.id))
    }

    public var selectedLeftoverTotalBytes: Int64 {
        leftoverItems.filter { selectedLeftoverIDs.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    public var confirmationMessage: String {
        var message = "Будет удалено \(selectedLeftoverIDs.count) элементов"
            + " (\(ByteFormatter.string(selectedLeftoverTotalBytes)))."
        if deletePermanently {
            message += " Удаление навсегда — мимо Корзины!"
        }
        if selectedApp?.isRunning == true {
            message += " Приложение сейчас запущено — рекомендуется закрыть перед удалением."
        }
        return message
    }

    public func executeSelected() async -> CleanupReport {
        let toDelete = leftoverItems.filter { selectedLeftoverIDs.contains($0.id) }
        let report = await executor.execute(items: toDelete, permanently: deletePermanently)
        let deletedIDs = Set(report.deleted.map(\.id))
        leftoverItems.removeAll { deletedIDs.contains($0.id) }
        selectedLeftoverIDs.subtract(deletedIDs)
        lastReport = report
        if let app = selectedApp, report.deleted.contains(where: { $0.url == app.url }) {
            apps.removeAll { $0.id == app.id }
            selectedAppID = nil
        }
        return report
    }
}
