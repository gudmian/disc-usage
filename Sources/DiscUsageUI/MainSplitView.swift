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
