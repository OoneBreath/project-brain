#!/usr/bin/env bash
# Regression (issue #1): a hard rule written without the colon after "never" but with a colon later
# in the sentence was split on that later colon, so index.compact showed a mangled rule.
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BRAIN="$TMP/.project-brain"
mkdir -p "$BRAIN/projects/acme"

cat > "$BRAIN/index.md" <<'MD'
# Project Brain — index

! never: deploy outside the EU (client is GDPR-bound)
! never commit .env files (see: security.md)

## acme  (Go)
! Never: store PII in Redis: use the vault
!never push to main without review (policy: two approvals)
- cache → cache notes  [✓ verified 2026-01-10 · v1] → projects/acme/cache.md
MD

cat > "$BRAIN/projects/acme/cache.md" <<'MD'
---
project: acme
topic: cache
status: verified
last_done: 2026-01-10
version: 1
---
Cache invalidation notes long enough to not be a thin topic. Padding padding padding
padding padding padding padding padding padding padding padding padding padding padding.
MD

python3 "$SKILL/brain-compact" "$TMP" >/dev/null
C="$BRAIN/index.compact"

fail=0
expect() {
  if grep -qxF -- "$1" "$C"; then echo "ok   $1"; else echo "FAIL missing: $1"; fail=1; fi
}
expect '! never: deploy outside the EU (client is GDPR-bound)'
expect '! never: commit .env files (see: security.md)'
expect '  ! never: store PII in Redis: use the vault'
expect '  ! never: push to main without review (policy: two approvals)'
if grep -q 'never: security.md)\|never: two approvals)\|never: use the vault' "$C"; then
  echo "FAIL a rule was split on a later colon"; fail=1
fi
[ "$fail" = 0 ] && echo "PASS: hard rules keep their text" || { cat "$C"; exit 1; }
