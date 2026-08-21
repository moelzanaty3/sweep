#!/bin/bash
# Coverage gate.
#
# A single global percentage is the wrong shape for this repository: most of the
# line count is SwiftUI view bodies, which are expensive and brittle to cover,
# and a high global floor would only encourage tests that execute code without
# asserting anything about it.
#
# So there are three separate checks:
#
#   1. Per-function floors on the code that can lose someone's data.
#   2. Per-file floors on the logic layer.
#   3. A global ratchet: coverage may never fall below what is recorded in
#      Scripts/coverage-baseline.txt. It can only go up.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE_FILE="$ROOT/Scripts/coverage-baseline.txt"
cd "$ROOT"

echo "==> Running tests with coverage"
swift test --enable-code-coverage

BIN="$(swift build --show-bin-path)"
PROFDATA="$BIN/codecov/default.profdata"
XCTEST="$(find "$BIN" -maxdepth 1 -name '*.xctest' | head -1)"
BINARY="$XCTEST/Contents/MacOS/$(basename "$XCTEST" .xctest)"

if [[ ! -f "$PROFDATA" || ! -f "$BINARY" ]]; then
    echo "Could not find coverage data. Did the tests run?" >&2
    exit 1
fi

report() {
    xcrun llvm-cov report "$BINARY" -instr-profile "$PROFDATA" -ignore-filename-regex='Tests/' "$@"
}

failures=0

# Line coverage sits in a different column in each of llvm-cov's two layouts:
# field 10 on a file row (after the region and function columns), field 7 on a
# function row.
percent_for_file() {
    report "$1" 2>/dev/null | awk -v want="$1" '$1 ~ want { gsub("%","",$10); print $10; exit }'
}

percent_for_function() {
    report -show-functions "$1" 2>/dev/null | awk -v want="$2" '$1 ~ want { gsub("%","",$7); print $7; exit }'
}

check() {
    local label="$1" actual="$2" floor="$3"
    if [[ -z "$actual" ]]; then
        echo "  MISSING  $label - no coverage data"
        failures=$((failures + 1))
        return
    fi
    if awk -v a="$actual" -v f="$floor" 'BEGIN { exit !(a + 0 < f + 0) }'; then
        echo "  FAIL     $label - ${actual}% (floor ${floor}%)"
        failures=$((failures + 1))
    else
        echo "  ok       $label - ${actual}% (floor ${floor}%)"
    fi
}

echo
echo "==> Safety-critical functions"
# isRemovable is the last check before anything is deleted. Every clause of it
# must be exercised; there is no acceptable reason for this to drop.
check "Cleaner.isRemovable" "$(percent_for_function Sources/MacCleaner/Core/Cleaner.swift isRemovable)" 100

echo
echo "==> Logic files"
# Floors sit just under what the suite reaches today, so they catch a
# regression rather than describing an ambition. Raise them when you raise the
# coverage - never lower them to make a red build go green.
check "Core/Cleaner.swift" "$(percent_for_file Sources/MacCleaner/Core/Cleaner.swift)" 55
check "Core/DuplicateScanner.swift" "$(percent_for_file Sources/MacCleaner/Core/DuplicateScanner.swift)" 90
check "Model/Catalog.swift" "$(percent_for_file Sources/MacCleaner/Model/Catalog.swift)" 80
check "Model/Types.swift" "$(percent_for_file Sources/MacCleaner/Model/Types.swift)" 70
check "Model/AppState.swift" "$(percent_for_file Sources/MacCleaner/Model/AppState.swift)" 20

echo
echo "==> Global ratchet"
TOTAL="$(report | awk '/^TOTAL/ { gsub("%","",$10); print $10; exit }')"
BASELINE="$(cat "$BASELINE_FILE" 2>/dev/null || echo 0)"

if [[ -z "$TOTAL" ]]; then
    echo "  MISSING  could not read the total" >&2
    failures=$((failures + 1))
elif awk -v a="$TOTAL" -v b="$BASELINE" 'BEGIN { exit !(a + 0 < b + 0 - 0.5) }'; then
    echo "  FAIL     total ${TOTAL}% is below the recorded ${BASELINE}%"
    echo "           Coverage may not go down. Add tests, or justify the drop in the"
    echo "           pull request and update Scripts/coverage-baseline.txt deliberately."
    failures=$((failures + 1))
else
    echo "  ok       total ${TOTAL}% (recorded ${BASELINE}%)"
    if [[ "${UPDATE_BASELINE:-0}" == "1" ]]; then
        printf '%s\n' "$TOTAL" > "$BASELINE_FILE"
        echo "           baseline updated to ${TOTAL}%"
    fi
fi

echo
if (( failures > 0 )); then
    echo "Coverage gate failed with $failures problem(s)."
    exit 1
fi
echo "Coverage gate passed."
