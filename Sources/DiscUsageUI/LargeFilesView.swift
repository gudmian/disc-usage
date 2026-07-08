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
