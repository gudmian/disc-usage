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
