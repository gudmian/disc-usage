import Foundation
import Testing
@testable import UninstallKit

@Test func withHomebrewTokenReturnsCopyWithToken() {
    let app = AppInfo(
        url: URL(filePath: "/Applications/Slack.app"), displayName: "Slack",
        bundleIdentifier: "com.tinyspeck.slackmacgap", size: 100,
        isRunning: false, homebrewToken: nil)

    let tagged = app.withHomebrewToken("slack")

    #expect(tagged.homebrewToken == "slack")
    #expect(app.homebrewToken == nil)  // оригинал не изменился
    #expect(tagged.url == app.url)
    #expect(tagged.id == "com.tinyspeck.slackmacgap")
}

@Test func idFallsBackToPathWithoutBundleIdentifier() {
    let app = AppInfo(
        url: URL(filePath: "/Applications/Weird.app"), displayName: "Weird",
        bundleIdentifier: nil, size: 0, isRunning: false, homebrewToken: nil)
    #expect(app.id == "/Applications/Weird.app")
}
