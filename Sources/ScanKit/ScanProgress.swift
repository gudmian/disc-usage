public struct ScanProgress: Sendable {
    public let scannedItems: Int
    public let totalBytes: Int64
    public let currentPath: String

    public init(scannedItems: Int, totalBytes: Int64, currentPath: String) {
        self.scannedItems = scannedItems
        self.totalBytes = totalBytes
        self.currentPath = currentPath
    }
}
