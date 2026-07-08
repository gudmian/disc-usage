import AppKit
import Combine
import SwiftUI

struct OnboardingView: View {
    let checker: FullDiskAccessChecker
    let onGranted: () -> Void

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("Нужен полный доступ к диску").font(.title2).bold()
            Text("Чтобы анализировать весь диск и чистить кэши, выдай DiscUsage право «Полный доступ к диску» в Системных настройках. Приложение продолжит само, как только доступ появится.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Button("Открыть Системные настройки") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            if checker.hasFullDiskAccess() { onGranted() }
        }
    }
}
