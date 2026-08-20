import AppKit
import CleanupKit
import SwiftUI
import UninstallKit

struct AppsView: View {
    @State private var viewModel = AppsViewModel()
    @State private var confirming = false
    @State private var reportMessage: String?

    var body: some View {
        @Bindable var viewModel = viewModel
        HStack(spacing: 0) {
            appList
                .frame(width: 260)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem {
                Button("Найти приложения", systemImage: "magnifyingglass") {
                    Task { await viewModel.scanApps() }
                }
                .disabled(viewModel.isScanningApps)
            }
        }
        .confirmationDialog(
            viewModel.confirmationMessage, isPresented: $confirming, titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) { Task { await runDelete() } }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Удаление завершено", isPresented: .init(
            get: { reportMessage != nil }, set: { if !$0 { reportMessage = nil } })
        ) {
            Button("OK") { reportMessage = nil }
        } message: {
            Text(reportMessage ?? "")
        }
    }

    private var appList: some View {
        Group {
            if viewModel.apps.isEmpty, !viewModel.isScanningApps {
                ContentUnavailableView(
                    "Приложения ещё не искали", systemImage: "app.dashed",
                    description: Text("Нажмите «Найти приложения»."))
            } else if viewModel.isScanningApps {
                ProgressView("Ищем приложения…")
            } else {
                List(viewModel.apps, selection: Binding(
                    get: { viewModel.selectedAppID },
                    set: { id in
                        guard let id, let app = viewModel.apps.first(where: { $0.id == id }) else { return }
                        Task { await viewModel.selectApp(app) }
                    })
                ) { app in
                    AppRow(app: app).tag(app.id)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if viewModel.selectedAppID == nil {
            ContentUnavailableView("Выберите приложение", systemImage: "arrow.left")
        } else if viewModel.isScanningLeftovers {
            ProgressView("Ищем связанные файлы…")
        } else {
            VStack(spacing: 0) {
                List(viewModel.leftoverItems) { item in
                    AppLeftoverItemRow(
                        item: item, isRunning: viewModel.selectedApp?.isRunning ?? false,
                        homebrewToken: item.url == viewModel.selectedApp?.url
                            ? viewModel.selectedApp?.homebrewToken : nil,
                        viewModel: viewModel)
                }
                Divider()
                HStack {
                    if let app = viewModel.selectedApp, app.isRunning {
                        Button("Закрыть приложение", systemImage: "xmark.circle") {
                            NSRunningApplication
                                .runningApplications(withBundleIdentifier: app.bundleIdentifier ?? "")
                                .first?.terminate()
                        }
                    }
                    Spacer()
                    Toggle("Удалять навсегда", isOn: $viewModel.deletePermanently)
                    Button(
                        "Удалить (\(ByteFormatter.string(viewModel.selectedLeftoverTotalBytes)))",
                        role: .destructive
                    ) { confirming = true }
                    .disabled(viewModel.selectedLeftoverIDs.isEmpty)
                }
                .padding(12)
            }
        }
    }

    private func runDelete() async {
        let report = await viewModel.executeSelected()
        var message = "Удалено: \(report.deleted.count) (\(ByteFormatter.string(report.freedBytes)))."
        if !report.failed.isEmpty {
            message += " Пропущено: \(report.failed.count) — \(report.failed.map { $0.message }.prefix(3).joined(separator: "; "))."
        }
        reportMessage = message
    }
}

private struct AppRow: View {
    let app: AppInfo

    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable().frame(width: 24, height: 24)
            VStack(alignment: .leading) {
                Text(app.displayName)
                if app.isRunning || app.homebrewToken != nil {
                    HStack(spacing: 4) {
                        if app.isRunning {
                            Text("Запущено").font(.caption2).foregroundStyle(.orange)
                        }
                        if let token = app.homebrewToken {
                            Text("Homebrew: \(token)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            Text(ByteFormatter.string(app.size)).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}

struct AppLeftoverItemRow: View {
    let item: CleanupItem
    let isRunning: Bool
    let homebrewToken: String?
    @Bindable var viewModel: AppsViewModel

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { viewModel.selectedLeftoverIDs.contains(item.id) },
                set: { selected in
                    if selected {
                        viewModel.selectedLeftoverIDs.insert(item.id)
                    } else {
                        viewModel.selectedLeftoverIDs.remove(item.id)
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
                }
            }
            Spacer()
            if let token = homebrewToken {
                Button("Скопировать команду brew", systemImage: "doc.on.doc") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("brew uninstall --zap --cask \(token)", forType: .string)
                }
                .buttonStyle(.borderless)
            }
            if !item.deletable {
                Text("только просмотр").font(.caption).foregroundStyle(.secondary)
            }
            Text(item.size > 0 ? ByteFormatter.string(item.size) : "—").monospacedDigit()
        }
    }
}
