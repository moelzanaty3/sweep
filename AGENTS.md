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

<!-- REDLINE:BEGIN — generated by Redline. Do not edit inside this block. -->

<!-- Redline v0.0.3 · profile: mobile-ios · stacks: swift -->

# Redline — Core Engineering Standards

You are performing code review against Redline, the engineering standard for this
organisation. Stack-specific rules extend these; they never override them.

## Output contract (required)

Every finding you post MUST begin with a machine-readable prefix on its own first line:

```
Redline/BLOCKER [rule-id]: <one-line problem>
Redline/HIGH [rule-id]: <one-line problem>
Redline/SUGGESTION [rule-id]: <one-line problem>
```

Then one or two sentences: why it breaks, and the concrete fix. No preamble, no praise,
no restating the diff. One finding per comment. If nothing qualifies, post nothing.

Worked example:

```
Redline/BLOCKER [core/query-string-concatenation]: user-supplied `name` is concatenated
into the SQL string, so a crafted value changes the query.
Use a parameterised query: `db.Query("SELECT id FROM users WHERE name = $1", name)`.
```

### Rule ids

Every rule in this document and in the stack rules carries an id in backticks at the
start of its line, of the form `<stack>/<slug>` — for example `react/effect-derived-state`.

- Quote the id of the rule you are applying, exactly as written. Do not invent, abbreviate,
  pluralise, or reformat it.
- One rule per comment. If a line breaks two rules, post two comments.
- If you are confident something is wrong but no rule covers it, use `core/uncatalogued`
  and say plainly which principle it offends. A recurring `core/uncatalogued` is how a
  missing rule gets discovered, so do not force a bad match to avoid it.

Ids are stable across wording changes and are aggregated per rule, which is how the org
finds out which rules earn their place and which only generate noise. A finding without a
valid id cannot be measured and is treated as untagged.

Severity meaning:

- **BLOCKER** — must not merge. Security exposure, data loss, crash, silent corruption,
  or a contract break for live consumers.
- **HIGH** — merge is a deliberate trade-off. Reviewer must acknowledge explicitly.
- **SUGGESTION** — optional. Author may dismiss without justification.

Do not invent severities. Do not upgrade a SUGGESTION to HIGH to get attention.

## Review priorities (in order)

1. Security and data exposure
2. Correctness bugs
3. Type safety
4. Performance regressions
5. Maintainability

Stop at the first three unless the diff is clean there.

## Security (BLOCKER)

- `core/hardcoded-secrets` — No hardcoded secrets, API keys, tokens, or credentials — including in test files,
  fixtures, config samples, and comments.
- `core/customer-data-in-logs` — No customer data (MSISDN, email, account IDs, names, addresses) in logs, analytics
  events, error messages, or metric labels.
- `core/unvalidated-boundary-input` — All external input validated at system boundaries (forms, API responses, deep links,
  query params, webhook payloads, message-queue payloads).
- `core/html-injection-sink` — No unsanitised HTML injection sinks (`dangerouslySetInnerHTML`, `innerHTML`, template
  autoescape disabled).
- `core/missing-auth-check` — Auth checks on every server action / API route / service endpoint — not only in the UI
  layer or at the gateway.
- `core/sensitive-data-in-client-storage` — No sensitive data in browser or device storage (`localStorage`, `AsyncStorage`,
  `UserDefaults`, `SharedPreferences`) without platform-keystore encryption.
- `core/query-string-concatenation` — No query built by string concatenation with external input — parameterised only.
- `core/secrets-in-committed-config` — No secrets read from committed config — environment or vault only.

## Type safety (BLOCKER unless justified inline)

- `core/escape-hatch-types` — No escape-hatch types (`any`, `interface{}` in new Go code, `Object`, `dynamic`)
  where a concrete or generic type works.
- `core/type-checker-suppression` — No type-checker suppression (`@ts-ignore`, `@ts-expect-error`, `# type: ignore`,
  `@SuppressWarnings("unchecked")`) without an inline comment AND a ticket reference.
- `core/unsafe-assertion` — No unsafe assertions (`as unknown as X`, force casts) used to silence an error.
- `core/prefer-discriminated-unions` — Discriminated unions / sealed types over optional-field grab-bags for variant state.
- `core/unchecked-indexed-access` — Assume the strictest project setting is on (TS `strict` + `noUncheckedIndexedAccess`,
  Kotlin/Swift null-safety, mypy strict): indexed access may be absent — require the check.

## Error handling

- `core/missing-boundary-error-handling` — Error handling belongs at real system boundaries: user input, network calls, storage,
  native modules, message consumers. Flag missing handling there.
- `core/unreachable-defensive-guard` — Flag defensive guards against states internal code cannot produce — they hide bugs and
  add noise.
- `core/silent-async-failure` — Async operations that can reject must not fail silently: no empty catch, no floating
  promises, no error logged then treated as success.

## General correctness

- `core/argument-mutation` — Flag mutation of function arguments or shared objects.
- `core/async-race-condition` — Flag race conditions in async work: missing cancellation/abort when the owner unmounts,
  the request is superseded, or the context is cancelled.
- `core/untracked-todo` — Flag `TODO`/`FIXME`/placeholder code without a ticket reference.
- `core/naive-clock` — Flag time handling that assumes local timezone or a naive clock in new code.

## Scope discipline

- `core/unrelated-change` — Flag changes unrelated to the PR's stated purpose (drive-by refactors, formatting churn).
- `core/speculative-abstraction` — Prefer the minimal diff that solves the problem; flag speculative abstraction
  ("might need it later").

## What NOT to flag

AI review dies by nitpick spam. Noise control is a rule, not a preference.

- Formatting, import order, or anything a linter or formatter already enforces.
- Existing patterns the PR merely touches but does not change.
- Missing tests for code outside the diff.
- Alternative libraries when the current one works ("consider using X instead").
- Naming preferences where the existing name is unambiguous.
- Re-raising the same issue on every occurrence — flag the first, say "and N similar".
- Anything you cannot point at a concrete failure for. If you cannot describe the input
  that breaks it, it is not a finding.

---

# Stack rules

## Swift (iOS) Review Rules

### BLOCKER — request changes

- `swift/force-operations` — **Force operations in production paths**: `!` force-unwrap, `try!`, `as!` — restructure with `guard let`, `if let`, `try?` + handling, or fix the optionality.
- `swift/retain-cycle` — **Retain cycles**: `self` captured strongly in `@escaping` closures stored by the object (handlers, subscriptions, timers) — require `[weak self]` and early-return pattern.
- `swift/ui-off-main-actor` — **UI mutation off the main actor** — UIKit/SwiftUI state must be touched on `@MainActor` / main queue; no fire-and-forget background completion touching views.
- `swift/blocking-main-thread` — **Blocking the main thread**: synchronous network/disk on main, `DispatchQueue.main.sync` from the main queue (deadlock).
- `swift/uncancelled-task` — **Unstructured `Task {}` in views without cancellation** — tie to `.task {}` modifier or store and cancel; leaked tasks outlive the screen.
- `swift/sensitive-data-in-userdefaults` — **Sensitive data in `UserDefaults`** — tokens/credentials belong in Keychain.

### HIGH

- `swift/unconfined-singleton-state` — Singletons with mutable state and no actor/queue confinement — convert to `actor` or confine.
- `swift/completion-handler-in-new-code` — Completion-handler APIs in new code where async/await is available.
- `swift/missing-mainactor` — Missing `@MainActor` on ObservableObject/ViewModel classes driving UI.
- `swift/unremoved-observer` — `NotificationCenter` observers without removal (pre-iOS 9-style APIs) or Combine subscriptions without `cancellables` storage.
- `swift/oversized-view` — Massive view controllers / SwiftUI views over ~300 lines — extract subviews and view models.
- `swift/stringly-typed-identifiers` — Stringly-typed identifiers (segues, notification names, userInfo keys) — use enums/constants.
- `swift/swallowed-decode-failure` — `Codable` decode failures swallowed with `try?` where the failure matters.

### SUGGESTION

- `swift/prefer-value-types` — Prefer `struct` value types; classes only for identity or reference semantics.
- `swift/prefer-typed-throws` — `Result` grab-bags where typed `throws` is clearer.
- `swift/prefer-guard-early-exit` — Prefer `guard` early-exit over nested `if let` pyramids.

_Applies to: `**/*.swift`_

<!-- REDLINE:END -->
