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
