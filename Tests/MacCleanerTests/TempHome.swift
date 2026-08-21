import Foundation

/// Scratch space for tests that touch the filesystem.
///
/// It lives under the real home directory on purpose: `Cleaner.isRemovable`
/// refuses everything outside it, so a conventional temp directory could never
/// exercise the deletion paths at all.
enum TempHome {
    static func makeDirectory(_ label: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let path = "\(NSHomeDirectory())/.sweep-tests/\(label)-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    static func write(_ contents: String, to path: String) throws {
        try contents.data(using: .utf8)!.write(to: URL(fileURLWithPath: path))
    }

    static func remove(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
