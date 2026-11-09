#!/usr/bin/env bash
# Tests the conflict-detector opt-out: `allow_conflict:` lets an aggregator topic
# (infra map / multi-repo roadmap) name several mutually-exclusive techs without
# being flagged — while genuine drift from OTHER topics still surfaces.
set -u
CHECK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)/brain-check"
ROOT=$(mktemp -d)
BRAIN="$ROOT/.project-brain"
mkdir -p "$BRAIN/projects/roadmap" "$BRAIN/projects/realapp"

cat > "$BRAIN/index.md" <<'EOF'
# Project Brain — index

## roadmap  (multi-repo checklist)
- fixes → cross-repo fix list  [✓ verified 2026-06-13 · v1] → projects/roadmap/fixes.md

## realapp  (Python)
- db    → datastore           [✓ verified 2026-06-13 · v1] → projects/realapp/db.md
- cache → caching             [✓ verified 2026-06-13 · v1] → projects/realapp/cache.md
EOF

# aggregator topic: legitimately names three DBs (24ad=MySQL, SpamSlap=SQLite, Queen=Postgres)
write_roadmap() {  # $1 = extra frontmatter line (or empty)
cat > "$BRAIN/projects/roadmap/fixes.md" <<EOF
---
project: roadmap
topic: fixes
status: verified
trust: human
version: 1
${1}
---
Cross-repo fix roadmap. Each repo has its own datastore:
24ad uses mysql, SpamSlap uses sqlite, Queen uses postgres. Not one project, three repos.
This is an aggregator listing, not a migration.
EOF
}

# realapp: a GENUINE conflict spread across two separate topics (no opt-out anywhere)
cat > "$BRAIN/projects/realapp/db.md" <<'EOF'
---
project: realapp
topic: db
status: verified
version: 1
---
The app stores everything in postgres. Solid choice for our relational needs and joins.
EOF
cat > "$BRAIN/projects/realapp/cache.md" <<'EOF'
---
project: realapp
topic: cache
status: verified
version: 1
---
Older note: the app used to run on mysql before the rewrite of the data layer here.
EOF

pass(){ echo "  PASS  $1"; }
fail(){ echo "  FAIL  $1"; FAILS=$((FAILS+1)); }
FAILS=0
run(){ python3 "$CHECK" "$BRAIN" 2>&1; }

echo "=== TEST 1: aggregator WITHOUT opt-out is flagged ==="
write_roadmap ""
out=$(run)
echo "$out" | grep -q "project 'roadmap': conflicting relational-db" \
  && pass "roadmap flagged without allow_conflict" || fail "roadmap not flagged (baseline broken)"

echo
echo "=== TEST 2: allow_conflict: [relational-db] (+ inline comment) silences the aggregator ==="
write_roadmap "allow_conflict: [relational-db]   # aggregator, not a migration"
out=$(run)
echo "$out" | grep -q "project 'roadmap': conflicting relational-db" \
  && fail "roadmap STILL flagged despite opt-out" || pass "roadmap silenced by allow_conflict"

echo
echo "=== TEST 3: genuine conflict in OTHER project still fires ==="
echo "$out" | grep -q "project 'realapp': conflicting relational-db" \
  && pass "realapp genuine drift still flagged" || fail "realapp drift was wrongly hidden"

echo
echo "=== TEST 4: allow_conflict: true silences all groups too ==="
write_roadmap "allow_conflict: true"
run | grep -q "project 'roadmap': conflicting relational-db" \
  && fail "true did not silence" || pass "allow_conflict: true silences"

echo
echo "=== TEST 5: unknown group name warns ==="
write_roadmap "allow_conflict: [relational_db]"   # underscore typo, not a real group
run | grep -q "allow_conflict names unknown group" \
  && pass "typo'd group name warned" || fail "no warning for unknown group"

echo
echo "=== TEST 6: opt-out does NOT mask a conflict from a sibling topic ==="
# roadmap opts out, but a sibling topic introduces a real second DB -> must still flag
write_roadmap "allow_conflict: [relational-db]"
cat > "$BRAIN/projects/roadmap/extra.md" <<'EOF'
---
project: roadmap
topic: extra
status: verified
version: 1
---
Unrelated note that genuinely standardizes the roadmap tooling DB on mysql, and also mentions postgres as the rejected option we will not use.
EOF
run | grep -q "project 'roadmap': conflicting relational-db" \
  && pass "sibling-topic conflict still surfaces" || fail "opt-out wrongly masked sibling conflict"
rm -f "$BRAIN/projects/roadmap/extra.md"

echo
if [ "$FAILS" -eq 0 ]; then echo "ALL ASSERTIONS PASSED"; else echo "$FAILS ASSERTION(S) FAILED"; fi
rm -rf "$ROOT"
exit "$FAILS"
