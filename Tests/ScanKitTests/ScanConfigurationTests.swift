import Foundation
import Testing
@testable import ScanKit

@Test func wholeDiskExcludesFirmlinksVolumesAndDev() {
    let config = ScanConfiguration.wholeDisk()
    #expect(config.rootURL.path == "/")
    #expect(config.isExcluded(URL(filePath: "/System/Volumes/Data")))
    #expect(config.isExcluded(URL(filePath: "/Volumes")))
    #expect(config.isExcluded(URL(filePath: "/dev")))
    #expect(!config.isExcluded(URL(filePath: "/Users")))
}

@Test func customExclusionsAreStandardized() {
    let config = ScanConfiguration(rootURL: URL(filePath: "/tmp"), excludedPaths: ["/tmp/skip/"])
    #expect(config.isExcluded(URL(filePath: "/tmp/skip")))
    #expect(!config.isExcluded(URL(filePath: "/tmp/keep")))
}
