# Contributing to Sweep

Sweep deletes files off people's machines. That single fact sets the bar for everything below: a bug here does not render a button in the wrong place, it loses someone's work. Contributions are welcome, and they get read carefully.

## Getting set up

```
git clone https://github.com/moelzanaty3/sweep.git
cd sweep
swift build          # debug binary at .build/debug/MacCleaner
bash build.sh        # release .app at dist/Sweep.app
bash build.sh install  # release .app into /Applications
```

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16 or later). No dependencies.

The fastest loop for scanner work is the headless mode — it exercises every scanner without touching the UI:

```
swift run MacCleaner --scan        # caches, app junk, toolchains
swift run MacCleaner --scan --all  # adds projects, git, large files, duplicates
```

## The rule that matters

**Never widen what can be deleted without saying so explicitly in the pull request.**

`Cleaner.isRemovable()` is the last line of defence before anything is removed. It refuses paths outside the home directory, paths containing `..`, paths shallower than two components unless the catalog named them, and the keychain, preferences, SSH, GPG and iCloud trees.

If your change touches that function, the protected list, or `Catalog.explicitCachePaths`, say so in the PR description and explain why the new surface is safe. A reviewer should never have to discover a widened deletion surface by reading the diff.

## Adding a cache location

Most contributions are new entries in `Catalog.devCaches` or `Catalog.appJunk`. A good entry needs four things:

1. **A `PathSpec`** with a stable `id`, a human title, and the relative paths it covers.
2. **The right `Risk` tier.** Be honest and be conservative:
   - `.safe` — regenerates with no user-visible cost. A cache the tool refills silently.
   - `.rebuild` — comes back, but costs a build, a re-download, or a container pull.
   - `.protected` — needs a human look. Never selected automatically.
   - When you are torn between two tiers, pick the more cautious one.
3. **A rationale** in `Catalog.rationales`, written for someone who does not know the tool. Say what recreates it and what it costs. "Restored by `npm install` in this project. Your source and lockfile are untouched." — not "safe to delete".
4. **A `ToolAction`** instead of a raw path delete, when the tool ships its own cleanup command. `pnpm store prune` beats deleting the store directory, because the tool knows what is still referenced.

Verify with `swift run MacCleaner --scan` before opening the PR, and put the relevant lines of that output in the description. Numbers from a real machine are the evidence that the entry works.

## Things that will be sent back

- A new deletion path with no rationale.
- Anything classified `.safe` that costs a rebuild.
- Widening `isRemovable()` without a written justification.
- Blocking work on the main thread. Scans shell out to `du` and `find`; they belong in a background context.
- Reaching into `~/Pictures`, `~/Movies`, or any `com.apple.*` cache domain. Those trip macOS privacy prompts on mere traversal, and media libraries must never be cleaned piecemeal. This is deliberate — see the comments in `Catalog.defaultFileRoots` and `DiskScanner.scanLooseCaches()`.

## Tests and coverage

```
swift test                 # just the tests
bash Scripts/coverage.sh   # tests plus the gate CI enforces
```

**Run the coverage script before opening a pull request.** CI runs the same thing, and a red gate is the first thing a reviewer sees.

There is no single global percentage to hit. Most of this codebase is SwiftUI view code, and a 90-something target would only produce tests that execute views without asserting anything about them. Instead the gate has three parts:

| Check | Rule |
|---|---|
| `Cleaner.isRemovable` | **100% line coverage**, always |
| Logic files (`Cleaner`, `DuplicateScanner`, `Catalog`, `Types`, `AppState`) | per-file floors, listed in the script |
| Everything else | a **ratchet** — the total may never fall below `Scripts/coverage-baseline.txt` |

The ratchet is why you do not need to write tests for `Theme.swift` to land a one-line fix. It only asks that you do not make things worse.

Raise a floor when you raise the coverage. Never lower one to turn a red build green — if a drop is genuinely correct, say why in the pull request and change the baseline in the same commit so it shows up in review.

`Tests/MacCleanerTests/CleanerSafetyTests.swift` pins every clause of `isRemovable()`, and the gate holds that function at 100%. If a change makes one of those fail, the change is wrong until proven otherwise — do not edit the test to match new behaviour without saying why in the pull request.

`CatalogTests` enforces the rules above mechanically: unique ids, populated specs, relative paths only, and a real rationale on every entry.

## Style

Match the file you are editing. The codebase has a specific convention about comments: they explain **why**, never **what**. If a comment restates the code, it gets removed in review. If a non-obvious decision has no comment, that is the gap worth filling.

No new dependencies without discussing it in an issue first. The zero-dependency build is a feature.

## Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) — the release automation reads them to decide version numbers and to write the changelog:

```
feat(catalog): add Deno dependency cache
fix(scanner): skip symlinked node_modules to avoid double counting
docs: clarify the rebuild tier
```

| Prefix | Effect on the next release |
|---|---|
| `fix:` | patch bump (1.0.0 → 1.0.1) |
| `feat:` | minor bump (1.0.0 → 1.1.0) |
| `feat!:` or a `BREAKING CHANGE:` footer | major bump (1.0.0 → 2.0.0) |
| `docs:`, `chore:`, `build:`, `refactor:`, `test:` | no release on their own |

The body is where the reasoning goes. Explain the decision, not the diff.

## Pull requests

Keep them small and single-purpose. Before opening one:

- `swift build` is clean, with no new warnings
- `swift run MacCleaner --scan --all` runs without crashing
- You have launched the app and used the screen you changed
- Nothing personal is in your screenshots — that view lists real paths from your own machine

## Reporting a bug

Include your macOS version, whether the app was built from source or installed from a release, and what you expected instead. If a scanner reported something wrong, the output of `--scan --all` around that entry is the single most useful thing you can attach.

**If Sweep deleted something it should not have, say so in the title.** That class of bug jumps the queue.

## Security

For anything that could cause data loss on someone else's machine, do not open a public issue. Reach out on [LinkedIn](https://www.linkedin.com/in/moelzanaty3/) instead and it gets handled first.

## License

By contributing you agree that your work is licensed under the MIT license that covers this repository.
