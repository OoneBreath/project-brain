#!/usr/bin/env bash
# Regression: people (@people / "@ <slug> …") lines in index.compact are DATA, not metadata.
# Before 2.1.2, data_lines() stripped every "@" line, so a changed # People section never
# triggered the "index.compact is out of date" warning. This test locks the fix in.
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BRAIN="$TMP/.project-brain"
mkdir -p "$BRAIN/projects/acme" "$BRAIN/people"

cat > "$BRAIN/index.md" <<'EOF'
# Project Brain — index

## acme  (Go)
- cache → cache notes  [✓ verified 2026-01-10 · v1] → projects/acme/cache.md

# People
- jane-doe → client · Acme Corp  [active 2026-01-10]  → people/jane-doe.md
EOF

cat > "$BRAIN/projects/acme/cache.md" <<'EOF'
---
project: acme
topic: cache
status: verified
last_done: 2026-01-10
version: 1
---
Cache invalidation notes long enough to not be a thin topic. Padding padding padding
padding padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding padding.
EOF

cat > "$BRAIN/people/jane-doe.md" <<'EOF'
---
person: jane-doe
status: active
version: 1
---
- 2026-01: agreed on annual contract.
EOF

fail() { echo "✗ $1"; exit 1; }

# 1. fresh compact -> no drift warning
python3 "$SKILL/brain-compact" "$TMP" >/dev/null
out="$(python3 "$SKILL/brain-check" "$TMP" 2>&1)" || fail "brain-check errored on a clean brain: $out"
echo "$out" | grep -q "out of date" && fail "clean brain flagged as drifted"

# 2. change ONLY the people line (its date) -> drift MUST be flagged
python3 - "$BRAIN/index.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("[active 2026-01-10]", "[active 2026-02-01]"))
PY
out="$(python3 "$SKILL/brain-check" "$TMP" 2>&1)" || true
echo "$out" | grep -q "out of date" || fail "people-only change did not flag compact drift"

# 3. regenerate -> clean again
python3 "$SKILL/brain-compact" "$TMP" >/dev/null
out="$(python3 "$SKILL/brain-check" "$TMP" 2>&1)" || fail "brain-check errored after regen: $out"
echo "$out" | grep -q "out of date" && fail "regenerated compact still flagged as drifted"

echo "✓ test-compact-people-drift: PASS"
