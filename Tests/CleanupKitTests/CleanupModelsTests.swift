import Testing
@testable import CleanupKit

@Test func appLeftoversCategoryExists() {
    #expect(CleanupCategory.allCases.contains(.appLeftovers))
}
