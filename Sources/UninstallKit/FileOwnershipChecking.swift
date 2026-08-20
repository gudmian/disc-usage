import Foundation

public protocol FileOwnershipChecking: Sendable {
    func isOwnedByCurrentUser(_ url: URL) -> Bool
}

public struct SystemFileOwnershipChecking: FileOwnershipChecking {
    public init() {}

    public func isOwnedByCurrentUser(_ url: URL) -> Bool {
        guard let owner = try? FileManager.default.attributesOfItem(atPath: url.path)[.ownerAccountID]
            as? NSNumber
        else { return true }  // не смогли определить — не блокируем без причины
        return owner.intValue == Int(getuid())
    }
}
