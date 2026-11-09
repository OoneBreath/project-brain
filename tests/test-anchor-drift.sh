#!/usr/bin/env bash
# anchor-drift: a verified topic lists `anchors:`; brain-check warns when the code under them changed
# after the topic's last_done (git), when a symbol is gone or a file is missing; --fix writes and
# clears "· drift <date>" in index.md, and the compact shows ✓v?. Without git: existence checks only.
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME"

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

WS="$TMP/ws"
B="$WS/.project-brain"
mkdir -p "$WS/app/src" "$B/projects/acme"

commit() {  # $1 = date (YYYY-MM-DD), $2 = message; commits everything under app/
  git -C "$WS" add -A app
  GIT_AUTHOR_DATE="$1T12:00:00" GIT_COMMITTER_DATE="$1T12:00:00" \
    git -C "$WS" -c user.email=t@example.invalid -c user.name=t commit -qm "$2"
}
write_brain() {  # $1 = verification date
  cat > "$B/index.md" <<MD
# Project Brain — index

## acme  (Python)
- cache → cache layer  [✓ verified $1 · v1] → projects/acme/cache.md
MD
  cat > "$B/projects/acme/cache.md" <<MD
---
project: acme
topic: cache
status: verified
last_done: $1
root: app
anchors: [src/cache.py#get_or_set, src/other.py]
version: 1
---
How the cache works: get_or_set wraps the store. Long enough not to be a thin topic. Padding
padding padding padding padding padding padding padding padding padding padding padding padding.
MD
}
check() { python3 "$SKILL/brain-check" "$WS" "$@" 2>&1 || true; }
drift_lines() { check | grep "anchor-drift" || true; }

git -C "$WS" init -q
printf 'def get_or_set(key):\n    return key\n' > "$WS/app/src/cache.py"
printf 'x = 1\n' > "$WS/app/src/other.py"
printf 'notes\n' > "$WS/app/notes.txt"
commit 2026-01-05 "initial"
write_brain 2026-01-10

# 1. nothing changed since verification -> no drift
if [ -z "$(drift_lines)" ]; then ok "unchanged code: no drift"; else bad "unexpected drift: $(drift_lines)"; fi

# 2. a commit to an unrelated file -> no drift
echo more >> "$WS/app/notes.txt"; commit 2026-02-01 "notes"
if [ -z "$(drift_lines)" ]; then ok "unrelated commit: no drift"; else bad "unrelated commit flagged: $(drift_lines)"; fi

# 3. a commit to an anchor file -> drift, dated
printf 'def get_or_set(key):\n    return key * 2\n' > "$WS/app/src/cache.py"; commit 2026-02-02 "change cache"
if drift_lines | grep -q "code changed since this was verified on 2026-01-10: src/cache.py (2026-02-02)"; then
  ok "anchor commit: drift reported with dates"; else bad "anchor commit not reported: $(drift_lines)"; fi
if check --report | grep -q "Anchors (code changed since the topic was verified)"; then ok "report has an Anchors section"; else bad "report lacks Anchors section"; fi

# 4. --fix writes the marker into index.md; the compact shows ✓v?
python3 "$SKILL/brain-check" "$WS" --fix >/dev/null 2>&1 || true
if grep -q "\[✓ verified 2026-01-10 · v1 · drift 2026-02-02\]" "$B/index.md"; then ok "--fix wrote the drift marker"; else bad "--fix did not write the marker: $(grep cache "$B/index.md")"; fi
if grep -qx "  cache ✓v? 2026-01-10 v1" "$B/index.compact"; then ok "compact shows ✓v?"; else bad "compact: $(grep cache "$B/index.compact")"; fi
before="$(cat "$B/index.md")"
python3 "$SKILL/brain-check" "$WS" --fix >/dev/null 2>&1 || true
if [ "$(cat "$B/index.md")" = "$before" ]; then ok "--fix is idempotent"; else bad "second --fix changed index.md"; fi

# 5. re-verified (new last_done) -> --fix clears the marker
write_brain 2026-02-03
sed_line="$(grep cache "$B/index.md")"
python3 "$SKILL/brain-check" "$WS" --fix >/dev/null 2>&1 || true
if ! grep -q "drift" "$B/index.md" && grep -qx "  cache ✓v 2026-02-03 v1" "$B/index.compact" && [ -z "$(drift_lines)" ]; then
  ok "re-verified: no drift, marker gone"; else bad "after re-verify: $sed_line / $(grep cache "$B/index.compact") / $(drift_lines)"; fi
# a stale marker left in index.md by hand is also cleared
python3 - "$B/index.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("· v1]", "· v1 · drift 2026-01-01]"))
PY
python3 "$SKILL/brain-check" "$WS" --fix >/dev/null 2>&1 || true
if ! grep -q "drift" "$B/index.md"; then ok "--fix clears a marker that no longer applies"; else bad "stale marker kept"; fi

# 6. the symbol is renamed -> "symbol missing"
printf 'def fetch_or_set(key):\n    return key * 2\n' > "$WS/app/src/cache.py"; commit 2026-02-10 "rename"
if drift_lines | grep -q "symbol missing: src/cache.py#get_or_set"; then ok "renamed symbol: symbol missing"; else bad "rename not caught: $(drift_lines)"; fi

# 7. a file is deleted -> "anchor missing", dated by the deleting commit
git -C "$WS" rm -q app/src/other.py; commit 2026-02-11 "remove other"
if drift_lines | grep -q "anchor missing: src/other.py (changed 2026-02-11)"; then ok "deleted file: anchor missing"; else bad "deletion not caught: $(drift_lines)"; fi

# 8. uncommitted edits to an anchor count as a change (re-verified after the last commit first)
write_brain 2026-02-12
if ! drift_lines | grep -q "code changed since"; then ok "re-verified after the last commit: no change reported"; else bad "change reported right after re-verify"; fi
printf 'def get_or_set(key):\n    return key\n' > "$WS/app/src/cache.py"
if drift_lines | grep -q "code changed since this was verified on 2026-02-12: src/cache.py ($(date +%Y-%m-%d))"; then
  ok "uncommitted edit: drift"; else bad "uncommitted edit not caught: $(drift_lines)"; fi

# 9. not a git repository -> existence checks only, with one note
NG="$TMP/nogit"
mkdir -p "$NG"
cp -R "$B" "$NG/.project-brain"; mkdir -p "$NG/app/src"
printf 'def fetch_or_set(key):\n    pass\n' > "$NG/app/src/cache.py"
out="$(python3 "$SKILL/brain-check" "$NG" 2>&1 || true)"
if printf '%s' "$out" | grep -q "is not a git repository — only checked that anchors and symbols exist"; then ok "non-git: one-line note"; else bad "non-git note missing"; fi
if [ "$(printf '%s\n' "$out" | grep -c "is not a git repository")" -eq 1 ]; then ok "non-git: note said once"; else bad "non-git note repeated"; fi
if printf '%s' "$out" | grep -q "symbol missing: src/cache.py#get_or_set" && printf '%s' "$out" | grep -q "anchor missing: src/other.py"; then
  ok "non-git: existence checks still run"; else bad "non-git existence checks missing"; fi
if printf '%s' "$out" | grep -q "code changed since"; then bad "non-git reported a code change"; else ok "non-git: no change claims"; fi

exit "$fail"
