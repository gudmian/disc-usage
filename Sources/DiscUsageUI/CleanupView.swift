import CleanupKit
import SwiftUI

extension CleanupCategory {
    var title: String {
        switch self {
        case .systemJunk: "Системный мусор"
        case .developerJunk: "Мусор разработчика"
        case .browserData: "Браузеры"
        case .miscellaneous: "Локализации и прочее"
        case .appLeftovers: "Приложения"
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
