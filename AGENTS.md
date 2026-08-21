# Working on Sweep

Instructions for coding agents. Humans want [CONTRIBUTING.md](CONTRIBUTING.md), which covers the same ground with more explanation.

## What this is

A macOS SwiftUI app that finds reclaimable disk space on a developer's machine and deletes what the user selects. Swift 6 toolchain, SwiftPM, **no dependencies** — do not add any without being asked.

macOS 14+. The binary is dual-purpose: a GUI app, and a `--scan` CLI used to verify scanners without the UI.

## Commands

```
swift build                        # debug
swift test                         # 25 tests, all fast, no fixtures
swiftlint lint --strict            # must be clean; CI runs --strict
shellcheck build.sh
bash build.sh                      # release .app into dist/
bash build.sh install              # release .app into /Applications
swift run MacCleaner --scan        # caches, app junk, toolchains
swift run MacCleaner --scan --all  # adds projects, git, large files, duplicates
```

`--scan` never deletes. It is the right way to check scanner changes.

## The rule that overrides everything

**This app deletes files.** `Cleaner.isRemovable()` is the last check before removal. It refuses paths outside the home directory, paths containing `..`, paths shallower than two components unless the catalog named them, and the keychain, preferences, SSH, GPG and iCloud trees.

If you change that function, the protected list, or `Catalog.explicitCachePaths`, **say so explicitly in your summary**. Do not let a widened deletion surface be something the reviewer has to find in the diff. `Tests/MacCleanerTests/CleanerSafetyTests.swift` pins every clause; if you make one of those tests fail, stop and explain rather than editing the test. `Cleaner.isRemovable` is held at **100% line coverage** by `Scripts/coverage.sh` and there is no acceptable reason for that to drop. The whole logic layer is at 100% — adding an untested branch to `Cleaner`, `Catalog`, `Types`, `DuplicateScanner` or `AppState` fails CI. Calls that reach outside the process belong in `Core/SystemServices.swift`, behind the `AppState.System` seam.

## Conventions that reviewers enforce

- **Comments explain why, never what.** A comment restating the code gets deleted. A non-obvious decision without one is the actual gap.
- **Minimal diff.** No refactors, renames, or reformatting outside the task.
- **Error handling at real boundaries only** — user input, external processes, the filesystem. Do not guard against states that cannot occur.
- **No `any` escape hatches**, no force-unwraps outside tests.
- **Never block the main thread.** Scans shell out to `du` and `find`; that work belongs in a background context. `AppState` is `@MainActor`, so be deliberate about what runs where.

## Traps that have already bitten

These are real regressions this codebase has shipped and fixed. Do not reintroduce them.

- **`@AppStorage` does not publish inside an `ObservableObject`.** It writes to disk and silently skips change notification, so the UI never updates. `AppState` uses `@Published` mirrored to `UserDefaults` by hand. Keep it that way.
- **`bool(forKey:)` cannot distinguish unset from `false`.** Read defaults with `object(forKey:) as? T ?? fallback`.
- **`MenuBarExtra(isInserted:)` must take a plain `@State`.** Passing a custom `Binding` that reads the `@StateObject` breaks scene setup and the app launches with zero windows.
- **Never touch `~/Pictures`, `~/Movies`, or any `com.apple.*` cache domain.** Several are TCC-protected and merely measuring their size raises a privacy prompt. The Apple caches worth reclaiming are named explicitly in the catalog.
- **`opacity(0)` still hit-tests.** Invisible keyboard-shortcut buttons need `.allowsHitTesting(false)` or they swallow clicks.
- **Applying appearance during `init()` breaks scene setup.** `@Published` + `didSet` fires on the initializer's own assignment, before `NSApplication` has finished launching.

## Adding a cache location

Most changes are a new entry in `Catalog.devCaches` or `Catalog.appJunk`. Required:

1. A `PathSpec` with a unique `id`, a human title, and relative paths.
2. A `Risk` tier, chosen conservatively — `.safe` only if it regenerates at no user-visible cost, `.rebuild` if it costs a build or download, `.protected` if a human should look. When torn, pick the more cautious one.
3. An entry in `Catalog.rationales` written for someone who does not know the tool. Say what recreates it and what it costs.
4. A `ToolAction` rather than a raw path delete when the tool ships its own cleanup command.

`CatalogTests` enforces 1 and 3 mechanically.

Verify with `swift run MacCleaner --scan` and include the relevant output lines in your summary.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) — release automation reads them. `fix:` is a patch bump, `feat:` a minor, `feat!:` a major; `docs:` and `chore:` do not release. Put the reasoning in the body, not a restatement of the diff.

Never commit to `main` directly. Never commit unless asked.

## Releasing

`release-please` keeps a release PR open against `main` with the next version and changelog. Merging it tags, publishes, builds the DMG, and updates the Homebrew cask. The version lives in `build.sh` and `Brand.swift`, both marked `x-release-please-version` — never edit either by hand.
