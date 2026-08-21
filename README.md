# Sweep

**Disk hygiene for developers.** A macOS app that finds the gigabytes your toolchain is sitting on — and tells you what each one costs to delete before you delete it.

Every package manager, build tool and container runtime keeps a cache. None of them clean up after themselves. Sweep finds them, groups them by what removal actually costs you, and gets out of the way.

Requires macOS 14+.

## Install

Build from source. Sweep is a developer tool and you have the toolchain:

```
git clone https://github.com/moelzanaty3/sweep.git
cd sweep
bash build.sh install
```

That builds a release binary, generates the icon, assembles `Sweep.app`, and copies it to `/Applications`. Drop `install` to leave it in `dist/`.

A locally built app never carries the quarantine attribute, so Gatekeeper stays out of your way.

## What it scans

| Category | What it finds |
|---|---|
| **Developer Caches** | 38 known package-manager and toolchain cache locations — npm, pnpm, yarn, pip, Cargo, Go, Gradle, Maven, CocoaPods, SwiftPM, Xcode DerivedData, and more |
| **App Junk** | Application caches, logs, crash reports, stale installers, old backups |
| **Project Build Artifacts** | `node_modules`, `target/`, `build/`, `.next`, virtualenvs — found by walking your project roots |
| **Docker & Toolchains** | Reclaimable space reported by Docker, Homebrew, SDK managers, the iOS simulator runtime |
| **Git Repositories** | Loose objects and unreachable history that `git gc` can pack away |
| **Large & Old Files** | Files above a size threshold, or untouched past a cutoff |
| **Duplicate Files** | Byte-identical copies, grouped into sets with the newest kept |

## Risk tiers

The idea the whole app is built on. Nothing is presented as a flat list of bytes — every item is classified by what deleting it actually costs:

| Tier | Meaning |
|---|---|
| **SAFE** | Regenerates automatically. Nothing is lost. |
| **REBUILD** | Comes back, but costs you a build or a re-download. |
| **PROTECTED** | Needs a human look. Never selected for you. |

The header states the split — how much is reclaimable, how much of that is risk-free — and one action acts on it. **Select all safe** never touches anything above the safe tier.

Every item carries a hand-written rationale. Click the **?** on any row to see what recreates it and at what cost. No magic numbers to trust.

## Safety

Sweep deletes files, so the guard rails matter more than the features.

`Cleaner.isRemovable()` is the last line of defence and runs on every path before removal. It refuses:

- anything outside your home directory
- any path containing `..`
- anything shallower than two path components, unless the catalog named it explicitly
- `~/Library/Keychains`, `~/Library/Preferences`, `~/.ssh`, `~/.gnupg`, `~/Library/Application Support/com.apple*`, `~/Library/Mobile Documents` (iCloud)

Beyond that:

- **Move to Trash is the default.** Permanent deletion is opt-in, per session, in Settings.
- **Nothing is selected without you.** Scanning never deletes. Selection is explicit, and one control clears it.
- **Whitelist** any project path so it never appears in results.
- **Photos and Music libraries are never touched.** They are excluded from the default roots and from traversal — both because those libraries must never be cleaned piecemeal, and because merely measuring them trips a macOS privacy prompt.

Read [`Sources/MacCleaner/Core/Cleaner.swift`](Sources/MacCleaner/Core/Cleaner.swift) before you trust it. That is the point of shipping the source.

## Features

- **Menu bar item** with the current reclaimable total, toggleable
- **Scheduled background scans** — hourly, 6-hourly, daily, weekly, or off
- **Open at login** via `SMAppService`
- **Light / Dark / System** appearance
- **Accessibility text sizing** — honours System Settings › Accessibility › Display › Text size
- **Collapsible sidebar** (`⌘\`)

## CLI

The same binary runs headless — useful for checking a machine over SSH, or for verifying what the GUI reports:

```
/Applications/Sweep.app/Contents/MacOS/Sweep --scan
/Applications/Sweep.app/Contents/MacOS/Sweep --scan --all
```

`--scan` covers caches, app junk and toolchains. `--all` adds the slower filesystem walks: projects, git repos, large files and duplicates. The CLI only ever reports — it never deletes.

## Build

```
swift build                # debug
bash build.sh              # release .app into dist/
bash build.sh install      # release .app into /Applications
```

Swift 6 toolchain, SwiftPM, no dependencies.

## Author

**Mohamed El-Zanaty** — Engineering Manager & Software Engineer

[GitHub](https://github.com/moelzanaty3) · [LinkedIn](https://www.linkedin.com/in/moelzanaty3/)

Built because developer machines deserve better than `rm -rf` and guesswork.

## License

MIT. See [LICENSE](LICENSE).
