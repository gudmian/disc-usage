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
            guard let self else { return }
            do {
                let result = try await scanner.scan(configuration: configuration) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        if case .scanning = self?.phase { self?.phase = .scanning(progress) }
                    }
                }
                self.phase = .finished(result)
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(error.localizedDescription)
            }
            self.scanTask = nil
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
