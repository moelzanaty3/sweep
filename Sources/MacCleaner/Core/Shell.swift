import Foundation

struct ShellResult: Sendable {
    var status: Int32
    var out: String
    var ok: Bool { status == 0 }
}

enum Shell {
    /// Blocking. Always call from a background context.
    @discardableResult
    static func run(_ path: String, _ args: [String], timeout: TimeInterval = 120) -> ShellResult {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return ShellResult(status: 127, out: "")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ShellResult(status: 126, out: "\(error)")
        }

        let handle = pipe.fileHandleForReading
        let data = handle.readDataToEndOfFile()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000)
        }
        if process.isRunning {
            process.terminate()
            return ShellResult(status: 124, out: String(bytes: data, encoding: .utf8) ?? "")
        }
        process.waitUntilExit()
        return ShellResult(status: process.terminationStatus, out: String(bytes: data, encoding: .utf8) ?? "")
    }

    /// GUI apps inherit a bare PATH, so tools installed by Homebrew or a version manager
    /// are invisible unless we widen it here.
    private static let environment: [String: String] = {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let extra = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/bin", "/bin",
            "/usr/sbin", "/sbin", "\(home)/.local/bin", "\(home)/Library/pnpm",
            "\(home)/.bun/bin", "\(home)/.cargo/bin", "\(home)/go/bin",
            "/Applications/Docker.app/Contents/Resources/bin"
        ]
        let current = env["PATH"]?.split(separator: ":").map(String.init) ?? []
        var seen = Set<String>()
        env["PATH"] = (current + extra).filter { seen.insert($0).inserted }.joined(separator: ":")
        return env
    }()

    static func which(_ tool: String) -> String? {
        let result = run("/usr/bin/env", ["which", tool], timeout: 10)
        let path = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.ok && !path.isEmpty ? path : nil
    }

    /// `du -sk` beats FileManager enumeration by an order of magnitude on cache trees.
    static func size(ofPath path: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: path) else { return 0 }
        let result = run("/usr/bin/du", ["-sk", path], timeout: 300)
        guard let field = result.out.split(separator: "\n").first?.split(separator: "\t").first,
              let kb = Int64(field.trimmingCharacters(in: .whitespaces)) else { return 0 }
        return kb * 1024
    }

    static func modifiedDate(ofPath path: String) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return nil }
        return attrs[.modificationDate] as? Date
    }
}
