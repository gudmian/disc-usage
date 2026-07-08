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
