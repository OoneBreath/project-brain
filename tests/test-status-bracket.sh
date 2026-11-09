#!/usr/bin/env bash
# Regression: a topic line whose description contains its own [...] ("[Security]", a "[[wiki-link]]")
# lost its status, date and version in index.compact, and brain-check skipped its status-drift check,
# because the first [...] on the line was taken as the status bracket.
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
B="$TMP/.project-brain"
mkdir -p "$B/projects/acme" "$B/people"

cat > "$B/index.md" <<'MD'
# Project Brain — index

## acme  (Go)
- auth → plaintext [Security] password no longer accepted  [✓ verified 2026-01-10 · v4] → projects/acme/auth.md
- plan → see [[acme/pricing]] for tiers  [⚠ in-progress 2026-02-01 · v2] → projects/acme/plan.md

# People
- jane → client [Acme] · contract  [active 2026-03-01] → people/jane.md
MD
for t in auth plan; do
  st=verified; [ "$t" = plan ] && st=in-progress
  cat > "$B/projects/acme/$t.md" <<MD
---
project: acme
topic: $t
status: $st
version: 1
---
Notes long enough not to be a thin topic. Padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding padding padding.
MD
done
cat > "$B/people/jane.md" <<'MD'
---
person: jane
status: active
version: 1
---
Client contact. Padding padding padding padding padding padding padding padding padding padding.
MD

fail=0
python3 "$SKILL/brain-compact" "$TMP" >/dev/null
C="$B/index.compact"
for want in "  auth ✓v 2026-01-10 v4" "  plan ⚠ 2026-02-01 v2" "@ jane active 2026-03-01"; do
  if grep -qxF -- "$want" "$C"; then echo "ok   compact: $want"; else echo "FAIL compact missing: $want"; fail=1; fi
done

# status drift must still be detected on such a line
sed_tmp="$B/projects/acme/auth.md"
python3 - "$sed_tmp" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read(); open(p, "w").write(s.replace("status: verified", "status: in-progress"))
PY
out="$(python3 "$SKILL/brain-check" "$TMP" 2>&1 || true)"   # exits 1 on the drift error — that's expected
if printf '%s' "$out" | grep -q "auth.md: status drift — index says 'verified', file says 'in-progress'"; then
  echo "ok   status drift detected despite [Security] in the description"
else
  echo "FAIL status drift missed"; fail=1
fi
exit "$fail"
