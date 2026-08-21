import Foundation

// A main.swift file takes over as the entry point, which lets the same binary serve the
// SwiftUI app and a headless scan for scripting or CI.
if CommandLine.arguments.dropFirst().contains(where: { $0 == "--scan" || $0 == "-s" }) {
    CLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
} else {
    SweepApp.main()
}
