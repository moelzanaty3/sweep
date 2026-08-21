import Foundation

enum DiskInfo {
    static func snapshot() -> DiskSnapshot {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return DiskSnapshot() }
        return DiskSnapshot(
            total: Int64(values.volumeTotalCapacity ?? 0),
            free: values.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }
}
