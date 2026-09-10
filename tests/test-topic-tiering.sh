#!/usr/bin/env bash
# Topic-level tiering in the compact index: a project's ⚠ in-progress topics are always shown
# in full; once a project passes TOPIC_THRESHOLD (15) topics, the oldest finished ones collapse
# into one "+K more, oldest <date>" line instead of dumping every line unconditionally.
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BRAIN="$TMP/.project-brain"
mkdir -p "$BRAIN"

fail() { echo "✗ $1"; exit 1; }

gen_finished() {  # gen_finished N -> N lines "fNN -> f  [✓ verified YYYY-01-NN · v1]", oldest=01
    local n="$1" i
    for ((i = 1; i <= n; i++)); do
        printf -- "- f%02d -> finished topic %02d  [✓ verified 2026-01-%02d · v1]\n" "$i" "$i" "$i"
    done
}

# --- brain: 3 projects ---
# acme:   3 open (⚠) + 15 finished = 18 topics -> over threshold, should collapse
# small:  3 finished topics -> under threshold, unchanged
# allopen: 16 open (⚠), 0 finished -> over threshold but nothing to collapse
{
    echo "# Project Brain — index"
    echo
    echo "## acme  (Go)"
    echo "- alpha -> open  [⚠ in-progress 2026-02-01]"
    echo "- beta  -> open  [⚠ in-progress 2026-02-02]"
    echo "- gamma -> open  [⚠ in-progress 2026-02-03]"
    gen_finished 15
    echo
    echo "## small  (Python)"
    echo "- one -> f  [✓ verified 2026-01-01 · v1]"
    echo "- two -> f  [✓ verified 2026-01-02 · v1]"
    echo "- three -> f  [✓ verified 2026-01-03 · v1]"
    echo
    echo "## allopen  (Rust)"
    for i in $(seq -w 1 16); do
        echo "- o$i -> open  [⚠ in-progress 2026-03-$i]"
    done
} > "$BRAIN/index.md"

out="$(python3 "$SKILL/brain-compact" "$TMP" --stdout)" || fail "brain-compact --stdout errored"

# --- acme: over threshold (18 topics) ---
acme="$(echo "$out" | sed -n '/^P+\? acme/,/^P/p')"
for t in alpha beta gamma; do
    echo "$acme" | grep -q "^  $t ⚠" || fail "acme: open topic '$t' missing or not shown in full"
done
# budget = 15 - 3 open = 12 finished kept -> most recent f04..f15 shown, f01..f03 collapse
for i in 04 05 06 07 08 09 10 11 12 13 14 15; do
    echo "$acme" | grep -q "^  f$i " || fail "acme: expected finished topic f$i to be kept (most recent 12)"
done
for i in 01 02 03; do
    echo "$acme" | grep -q "^  f$i " && fail "acme: f$i should have collapsed, not been shown"
done
echo "$acme" | grep -q "^  +3 more, oldest 2026-01-01\$" || fail "acme: collapse line wrong or missing: $(echo "$acme" | grep '+.*more')"

# --- small: under threshold, unchanged (no collapse line, all 3 shown) ---
small="$(echo "$out" | sed -n '/^P+\? small/,/^P/p')"
for t in one two three; do
    echo "$small" | grep -q "^  $t " || fail "small: topic '$t' missing (should be unaffected under threshold)"
done
echo "$small" | grep -q "more, oldest" && fail "small: should not have a collapse line under threshold"

# --- allopen: over threshold, all ⚠, nothing finished -> no collapse line, all 16 shown ---
allopen="$(echo "$out" | sed -n '/^P+\? allopen/,/^P/p')"
n_shown="$(echo "$allopen" | grep -c '^  o[0-9]* ⚠')"
[ "$n_shown" -eq 16 ] || fail "allopen: expected all 16 open topics shown, got $n_shown"
echo "$allopen" | grep -q "more, oldest" && fail "allopen: should not collapse (nothing finished to collapse)"

# --- determinism: same index.md -> byte-identical compact on a second render ---
out2="$(python3 "$SKILL/brain-compact" "$TMP" --stdout)" || fail "second brain-compact --stdout errored"
[ "$out" = "$out2" ] || fail "compact rendering is not deterministic across repeated runs"

echo "✓ test-topic-tiering: PASS"
