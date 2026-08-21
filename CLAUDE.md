Read [AGENTS.md](AGENTS.md). It is the full guide for coding agents in this repository and applies here unchanged.

The short version:

- **This app deletes files.** `Cleaner.isRemovable()` is the last guard. Changing it, the protected list, or `Catalog.explicitCachePaths` must be called out explicitly, never left for the reviewer to spot.
- `swift build`, `swift test`, `swiftlint lint --strict` and `shellcheck build.sh` must all be clean.
- Comments explain **why**, never what. Minimal diff. No new dependencies.
- `swift run MacCleaner --scan` verifies scanner changes without deleting anything.
- Do not commit unless asked, and never to `main`.
