import Foundation

struct PathSpec: Sendable {
    let id: String
    let title: String
    let detail: String
    let risk: Risk
    let category: Category
    let relativePaths: [String]
    var action: ToolAction? = nil

    var absolutePaths: [String] {
        relativePaths.map { $0.hasPrefix("/") ? $0 : NSHomeDirectory() + "/" + $0 }
    }
}

enum Catalog {
    static let devCaches: [PathSpec] = [
        PathSpec(id: "pnpm", title: "pnpm store", detail: "Content-addressed package store",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/pnpm/store", ".pnpm-store", "Library/Caches/pnpm"], action: .pnpmStorePrune),
        PathSpec(id: "npm", title: "npm cache", detail: "~/.npm/_cacache",
                 risk: .safe, category: .devCaches, relativePaths: [".npm/_cacache"]),
        PathSpec(id: "yarn", title: "Yarn cache", detail: "Global Yarn package cache",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/Caches/Yarn", ".yarn/cache", ".yarn/berry/cache"]),
        PathSpec(id: "bun", title: "Bun install cache", detail: "~/.bun/install/cache",
                 risk: .safe, category: .devCaches, relativePaths: [".bun/install/cache"]),
        PathSpec(id: "deno", title: "Deno cache", detail: "Downloaded modules and compiled output",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/deno"]),
        PathSpec(id: "nodegyp", title: "node-gyp headers", detail: "Node header archives for native builds",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/node-gyp"]),
        PathSpec(id: "typescript", title: "TypeScript type cache", detail: "Auto-acquired @types packages",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/typescript"]),
        PathSpec(id: "playwright", title: "Playwright browsers", detail: "Chromium/Firefox/WebKit downloads",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: ["Library/Caches/ms-playwright", "Library/Caches/ms-playwright-mcp"]),
        PathSpec(id: "puppeteer", title: "Puppeteer browsers", detail: "~/.cache/puppeteer",
                 risk: .rebuild, category: .devCaches, relativePaths: [".cache/puppeteer"]),
        PathSpec(id: "electron", title: "Electron build cache", detail: "electron and electron-builder downloads",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/Caches/electron", "Library/Caches/electron-builder"]),
        PathSpec(id: "cocoapods", title: "CocoaPods cache", detail: "Downloaded pod specs and sources",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/CocoaPods"]),
        PathSpec(id: "swiftpm", title: "SwiftPM cache", detail: "Cloned package dependencies",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/org.swift.swiftpm"]),
        PathSpec(id: "deriveddata", title: "Xcode DerivedData", detail: "Build products, indexes, module cache",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: ["Library/Developer/Xcode/DerivedData"]),
        PathSpec(id: "devicesupport", title: "iOS DeviceSupport", detail: "Symbols for devices you have attached",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/Developer/Xcode/iOS DeviceSupport",
                                 "Library/Developer/Xcode/watchOS DeviceSupport"]),
        PathSpec(id: "xcarchives", title: "Xcode Archives", detail: "Shipped build archives and dSYMs",
                 risk: .protected, category: .devCaches, relativePaths: ["Library/Developer/Xcode/Archives"]),
        PathSpec(id: "gradle", title: "Gradle cache", detail: "~/.gradle/caches",
                 risk: .safe, category: .devCaches, relativePaths: [".gradle/caches"]),
        PathSpec(id: "maven", title: "Maven repository", detail: "~/.m2/repository",
                 risk: .safe, category: .devCaches, relativePaths: [".m2/repository"]),
        PathSpec(id: "cargo", title: "Cargo registry", detail: "Rust crate sources and caches",
                 risk: .safe, category: .devCaches,
                 relativePaths: [".cargo/registry/cache", ".cargo/registry/src"]),
        PathSpec(id: "gomod", title: "Go module cache", detail: "~/go/pkg/mod",
                 risk: .safe, category: .devCaches, relativePaths: ["go/pkg/mod"], action: .goCleanModcache),
        PathSpec(id: "pip", title: "pip cache", detail: "Downloaded wheels and HTTP cache",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/pip"]),
        PathSpec(id: "uv", title: "uv cache", detail: "Python package cache",
                 risk: .safe, category: .devCaches, relativePaths: [".cache/uv", "Library/Caches/uv"]),
        PathSpec(id: "composer", title: "Composer cache", detail: "PHP dependency cache",
                 risk: .safe, category: .devCaches, relativePaths: [".composer/cache", ".cache/composer"]),
        PathSpec(id: "homebrewcache", title: "Homebrew downloads", detail: "Cached bottles and source tarballs",
                 risk: .safe, category: .devCaches, relativePaths: ["Library/Caches/Homebrew"]),
        PathSpec(id: "androidsdk", title: "Android SDK system images", detail: "Emulator system images and old build-tools",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: ["Library/Android/sdk/system-images"]),
        PathSpec(id: "androidavd", title: "Android emulator devices", detail: "~/.android/avd — virtual device disks",
                 risk: .protected, category: .devCaches, relativePaths: [".android/avd"]),
        PathSpec(id: "androidcache", title: "Android build cache", detail: "~/.android/cache and Gradle daemon logs",
                 risk: .safe, category: .devCaches,
                 relativePaths: [".android/cache", ".gradle/daemon", ".gradle/wrapper/dists"]),
        PathSpec(id: "jetbrains", title: "JetBrains caches", detail: "IntelliJ/WebStorm/PyCharm indexes and logs",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/Caches/JetBrains", "Library/Logs/JetBrains"]),
        PathSpec(id: "vscode", title: "VS Code caches", detail: "Extension VSIXs, CachedData, workspace storage",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/Application Support/Code/CachedData",
                                 "Library/Application Support/Code/CachedExtensionVSIXs",
                                 "Library/Application Support/Code/Cache",
                                 "Library/Application Support/Code/logs"]),
        PathSpec(id: "cursor", title: "Cursor caches", detail: "CachedData and logs from Cursor",
                 risk: .safe, category: .devCaches,
                 relativePaths: ["Library/Application Support/Cursor/CachedData",
                                 "Library/Application Support/Cursor/Cache",
                                 "Library/Application Support/Cursor/logs"]),
        PathSpec(id: "nvm", title: "nvm Node versions", detail: "Every Node release nvm has installed",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: [".nvm/versions/node", ".nvm/.cache"]),
        PathSpec(id: "fnm", title: "fnm Node versions", detail: "Node releases managed by fnm",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: ["Library/Application Support/fnm/node-versions"]),
        PathSpec(id: "pyenv", title: "pyenv Python versions", detail: "Installed interpreters and build cache",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: [".pyenv/versions", ".pyenv/cache"]),
        PathSpec(id: "conda", title: "conda package cache", detail: "Downloaded tarballs and unpacked packages",
                 risk: .safe, category: .devCaches,
                 relativePaths: [".conda/pkgs", "miniconda3/pkgs", "anaconda3/pkgs"]),
        PathSpec(id: "flutter", title: "Flutter/Dart cache", detail: "Pub cache and Flutter engine artifacts",
                 risk: .safe, category: .devCaches,
                 relativePaths: [".pub-cache", "Library/Caches/flutter_engine"]),
        PathSpec(id: "vagrant", title: "Vagrant boxes", detail: "~/.vagrant.d/boxes",
                 risk: .rebuild, category: .devCaches, relativePaths: [".vagrant.d/boxes"]),
        PathSpec(id: "terraform", title: "Terraform plugin cache", detail: "Downloaded providers",
                 risk: .safe, category: .devCaches,
                 relativePaths: [".terraform.d/plugin-cache", "Library/Caches/terraform"]),
        PathSpec(id: "sonar", title: "SonarLint / analysis caches", detail: "Static analysis working data",
                 risk: .safe, category: .devCaches, relativePaths: [".sonarlint"]),
        PathSpec(id: "huggingface", title: "Hugging Face models", detail: "Downloaded model weights",
                 risk: .rebuild, category: .devCaches,
                 relativePaths: [".cache/huggingface", "Library/Caches/huggingface"])
    ]

    static let appJunk: [PathSpec] = [
        PathSpec(id: "logs", title: "Application logs", detail: "~/Library/Logs",
                 risk: .safe, category: .appJunk, relativePaths: ["Library/Logs"]),
        PathSpec(id: "crashes", title: "Crash reports", detail: "Diagnostic reports from crashed apps",
                 risk: .safe, category: .appJunk,
                 relativePaths: ["Library/Logs/DiagnosticReports"]),
        PathSpec(id: "shipit", title: "Stale app updaters", detail: "Downloaded installers apps forgot to delete",
                 risk: .safe, category: .appJunk,
                 relativePaths: ["Library/Caches/com.microsoft.VSCode.ShipIt",
                                 "Library/Caches/com.tinyspeck.slackmacgap.ShipIt",
                                 "Library/Caches/SquirrelTemp"]),
        PathSpec(id: "trash", title: "Trash", detail: "Everything sitting in ~/.Trash",
                 risk: .protected, category: .appJunk, relativePaths: [".Trash"]),
        PathSpec(id: "iosbackups", title: "iPhone/iPad backups", detail: "Local device backups from Finder",
                 risk: .protected, category: .appJunk,
                 relativePaths: ["Library/Application Support/MobileSync/Backup"]),
        PathSpec(id: "maildownloads", title: "Mail attachments", detail: "Attachments Mail.app downloaded",
                 risk: .protected, category: .appJunk,
                 relativePaths: ["Library/Containers/com.apple.mail/Data/Library/Mail Downloads"]),
        PathSpec(id: "quicklook", title: "QuickLook thumbnails", detail: "Regenerates on demand",
                 risk: .safe, category: .appJunk,
                 relativePaths: ["Library/Caches/com.apple.QuickLook.thumbnailcache"]),
        PathSpec(id: "xcodecache", title: "Xcode app cache", detail: "Xcode's own cache directory",
                 risk: .safe, category: .appJunk, relativePaths: ["Library/Caches/com.apple.dt.Xcode"])
    ]

    /// IDs whose paths live under ~/Library/Caches and are already itemised above,
    /// so the generic cache sweep does not list them twice.
    static var explicitCachePaths: Set<String> {
        Set((devCaches + appJunk).flatMap(\.absolutePaths))
    }

    static let toolActions: [(id: String, title: String, detail: String, risk: Risk, action: ToolAction)] = [
        ("docker", "Docker images & containers", "Unused images, stopped containers, networks", .safe, .dockerPrune),
        ("dockerbuild", "Docker build cache", "Layer cache from past builds", .safe, .dockerBuilderPrune),
        ("brew", "Homebrew stale downloads", "Old versions and cached bottles", .safe, .brewCleanup),
        ("simulators", "Unavailable simulators", "Simulator devices whose runtime is gone", .safe, .simctlDeleteUnavailable)
    ]

    /// Media libraries are opaque packages — listing their internals as deletable files would
    /// corrupt them, so file scans skip the whole bundle.
    static let opaqueBundleSuffixes = [
        "photoslibrary", "musiclibrary", "tvlibrary", "imovielibrary",
        "fcpbundle", "logicx", "sparsebundle", "photolibrary", "aplibrary"
    ]

    static let projectArtifactNames = [
        "node_modules", ".next", ".nuxt", ".turbo", ".parcel-cache", ".svelte-kit",
        "dist", "build", "out", ".venv", "venv", "__pycache__", "Pods",
        "DerivedData", ".gradle", "target", ".dart_tool"
    ]

    /// Docker Desktop never shrinks its disk image on its own; surfacing the size explains
    /// why a prune reports GBs freed while the volume stays full.
    static var dockerDiskImagePaths: [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
            "\(home)/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw"
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }

    static var defaultScanRoots: [String] {
        let home = NSHomeDirectory()
        return ["Desktop", "Documents", "Developer", "repos", "projects", "work", "src", "code"]
            .map { "\(home)/\($0)" }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    static var defaultFileRoots: [String] {
        let home = NSHomeDirectory()
        // Pictures and Movies are omitted on purpose: reaching into them trips the Photos and
        // Apple Music privacy prompts, and their libraries are single packages that must never
        // be cleaned piecemeal. Users can still add them explicitly.
        return ["Desktop", "Downloads", "Documents"]
            .map { "\(home)/\($0)" }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }
}

extension Catalog {
    /// The concrete "why" shown next to each row. Naming the command that rebuilds a cache is
    /// what separates an engineer's tool from a cleaner that just asserts things are fine.
    static let rationales: [String: String] = [
        "pnpm": "Rebuilt on the next `pnpm install`. Packages re-download; nothing in your projects changes.",
        "npm": "Rebuilt on the next `npm install`. Only the download cache — installed node_modules are untouched.",
        "yarn": "Rebuilt on the next `yarn install`.",
        "bun": "Rebuilt on the next `bun install`.",
        "deno": "Re-fetched the next time a module is imported.",
        "nodegyp": "Re-downloaded when a native module next compiles.",
        "typescript": "Re-acquired automatically by the TypeScript language server.",
        "playwright": "Requires `npx playwright install` before browser tests run again.",
        "puppeteer": "Re-downloaded on the next Puppeteer launch or install.",
        "electron": "Re-downloaded on the next Electron build.",
        "cocoapods": "Re-downloaded on the next `pod install`.",
        "swiftpm": "Re-cloned on the next package resolve.",
        "deriveddata": "Xcode rebuilds this on the next build. The first build after will be slow and indexing restarts.",
        "devicesupport": "Regenerated the next time you attach that device.",
        "xcarchives": "Your shipped build archives and dSYMs — needed to symbolicate crash reports from released builds.",
        "gradle": "Re-downloaded on the next Gradle build.",
        "maven": "Re-downloaded on the next Maven build.",
        "cargo": "Re-downloaded on the next `cargo build`.",
        "gomod": "Re-downloaded on the next `go build`. Cleared with `go clean -modcache`.",
        "pip": "Re-downloaded on the next `pip install`.",
        "uv": "Re-downloaded on the next `uv` resolve.",
        "composer": "Re-downloaded on the next `composer install`.",
        "homebrewcache": "Already-installed formulae keep working; only the downloaded archives go.",
        "huggingface": "Model weights re-download on next use — potentially several GB over the network.",
        "androidsdk": "Re-downloaded through the SDK manager before those emulators run again.",
        "androidavd": "Your emulator devices and their disk state, including anything installed inside them.",
        "androidcache": "Rebuilt on the next Gradle/Android build.",
        "jetbrains": "Indexes rebuild on next open — the first launch of each project will be slower.",
        "vscode": "Rebuilt by VS Code on next launch. Settings, extensions and workspaces are untouched.",
        "cursor": "Rebuilt by Cursor on next launch. Settings and extensions are untouched.",
        "nvm": "Each Node version must be reinstalled with `nvm install` before it can be selected.",
        "fnm": "Each Node version must be reinstalled with `fnm install`.",
        "pyenv": "Each interpreter must be rebuilt with `pyenv install` — this takes minutes per version.",
        "conda": "Re-downloaded on the next environment solve.",
        "flutter": "Re-downloaded on the next `flutter pub get`.",
        "vagrant": "Boxes re-download on the next `vagrant up` — often gigabytes each.",
        "terraform": "Providers re-download on the next `terraform init`.",
        "sonarlint": "Rebuilt on the next analysis run.",
        "logs": "Diagnostic text written by apps. Nothing depends on it.",
        "crashes": "Crash reports already sent to their vendors. Useful only if you are actively debugging a crash.",
        "shipit": "Installers left behind after an app updated itself. The apps are already updated.",
        "trash": "Everything you have already chosen to delete. Emptying it is the final step.",
        "iosbackups": "Local iPhone/iPad backups. Deleting these removes your ability to restore a device from this Mac.",
        "maildownloads": "Attachments Mail saved to disk. Still downloadable from the server if the message remains.",
        "quicklook": "Finder regenerates previews on demand.",
        "xcodecache": "Xcode rebuilds this on next launch.",
        "docker": "Removes stopped containers and images nothing references. Running containers are never touched.",
        "dockerbuild": "Layer cache from past builds. The next build of each image will be slower.",
        "brew": "Old versions of installed formulae. Current versions keep working.",
        "simulators": "Simulator devices whose runtime is no longer installed — they cannot be booted anyway.",
        "dockerraw": "Docker's disk image. Pruning frees space inside it, but the file itself only shrinks when you reduce the disk image size in Docker Desktop."
    ]

    static func rationale(for id: String, risk: Risk) -> String {
        if let known = rationales[id] { return known }
        switch risk {
        case .safe: return "Cache data. The owning tool regenerates it automatically."
        case .rebuild: return "Regenerates, but the next install or build pays for it."
        case .protected: return "Real content rather than cache — review before removing."
        }
    }
}
