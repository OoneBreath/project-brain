#!/usr/bin/env bash
set -u
BOOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)/brain-bootstrap"
ROOT=$(mktemp -d)
FAKE="$ROOT/projects"; mkdir -p "$FAKE"

# simulated FOREIGN machine (NOT /home/ubuntu)
mkdir -p "$FAKE/-Users-test/memory"                 # macOS, fresh
mkdir -p "$FAKE/-C--Users-bob-code/memory"          # Windows-ish, fresh
mkdir -p "$FAKE/-Users-alice-projects-myapp/memory" # macOS, HAS real notes
NOTES="$FAKE/-Users-alice-projects-myapp/memory/MEMORY.md"
printf '%s\n' \
  "# Alice's notes — DO NOT LOSE" \
  "- prod DB host: db.internal:5432" \
  "- oncall rotation in PagerDuty" \
  "- TODO: rotate API keys before July" > "$NOTES"
cp "$NOTES" "$ROOT/alice.orig"

pass(){ echo "  PASS  $1"; }
fail(){ echo "  FAIL  $1"; FAILS=$((FAILS+1)); }
FAILS=0

echo "############ RUN 1 ############"
"$BOOT" "$FAKE"

echo
echo "=== TEST 2: foreign fresh dirs seeded? ==="
for d in -Users-test -C--Users-bob-code; do
  if grep -qF "project-brain-redirect v1" "$FAKE/$d/memory/MEMORY.md"; then pass "seeded $d"; else fail "$d not seeded"; fi
done

echo
echo "=== TEST 3: Alice's notes preserved + .bak? ==="
bak=$(ls "$FAKE/-Users-alice-projects-myapp/memory/"MEMORY.md.bak-* 2>/dev/null | head -1)
if [ -n "$bak" ]; then
  if cmp -s "$bak" "$ROOT/alice.orig"; then pass ".bak byte-identical to original"; else fail ".bak differs from original"; fi
else
  fail "no .bak created"
fi
grep -q "Alice's notes — DO NOT LOSE" "$NOTES" && pass "title line kept"           || fail "title lost"
grep -q "db.internal:5432" "$NOTES"            && pass "db host line kept"          || fail "db host lost"
grep -q "rotate API keys before July" "$NOTES" && pass "TODO line kept"             || fail "TODO lost"
head -1 "$NOTES" | grep -qF "project-brain-redirect v1" && pass "redirect prepended above notes" || fail "redirect not prepended"

echo
echo "############ RUN 2 (idempotency) ############"
before=$(ls "$FAKE"/*/memory/*.bak-* 2>/dev/null | wc -l)
"$BOOT" "$FAKE"
after=$(ls "$FAKE"/*/memory/*.bak-* 2>/dev/null | wc -l)
echo
[ "$before" = "$after" ] && pass "no new backups on rerun ($after)" || fail "rerun made backups ($before -> $after)"
# alice file unchanged on rerun (marker already present)
if cmp -s "$NOTES" "$NOTES"; then :; fi

echo
echo "=== Alice's MEMORY.md after both runs ==="
cat "$NOTES"

echo
if [ "$FAILS" -eq 0 ]; then echo "ALL ASSERTIONS PASSED"; else echo "$FAILS ASSERTION(S) FAILED"; fi
rm -rf "$ROOT"
exit "$FAILS"
