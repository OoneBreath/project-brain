#!/usr/bin/env bash
# brain-inject + brain-trust (2.4.2): a brain is auto-loaded only for a trusted workspace, the output is
# always valid JSON, invisible characters are made visible, oversized content is capped, and
# `init` (--created-here) / --revoke work. Every case runs with a temporary HOME, so the real trust
# store (~/.project-brain/trusted.json) is never touched.
set -euo pipefail

SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/project-brain" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME"

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

new_ws() {  # $1 = name -> prints workspace path with a minimal brain
  local ws="$TMP/$1"
  mkdir -p "$ws/.project-brain/projects/acme"
  cat > "$ws/.project-brain/index.md" <<'MD'
# Project Brain — index

! never: deploy outside the EU
## acme  (Go)
- cache → cache notes  [✓ verified 2026-01-10 · v1] → projects/acme/cache.md
MD
  python3 "$SKILL/brain-compact" "$ws" >/dev/null
  echo "$ws"
}

inject() { CLAUDE_PROJECT_DIR="$1" "$SKILL/brain-inject"; }
context() { python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }
valid_json() { python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; }

# 1. no brain -> no output, exit 0
mkdir -p "$TMP/empty"
out="$(inject "$TMP/empty")"; rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then ok "no brain: silent, exit 0"; else bad "no brain: rc=$rc out=$out"; fi

# 2. untrusted -> notice, not the content
ws="$(new_ws untrusted)"
out="$(inject "$ws")"
if printf '%s' "$out" | valid_json; then ok "untrusted: valid JSON"; else bad "untrusted: invalid JSON"; fi
ctx="$(printf '%s' "$out" | context)"
if printf '%s' "$ctx" | grep -q "isn't trusted on this machine"; then ok "untrusted: notice injected"; else bad "untrusted: no notice"; fi
if printf '%s' "$ctx" | grep -q "deploy outside the EU"; then bad "untrusted: brain content leaked into context"; else ok "untrusted: content not injected"; fi
if printf '%s' "$out" | grep -q '"systemMessage"'; then ok "untrusted: one-line hint for the user"; else bad "untrusted: no systemMessage"; fi

# 3. trusted -> content with the fixed preamble first
"$SKILL/brain-trust" "$ws" --yes >/dev/null
ctx="$(inject "$ws" | context)"
first="$(printf '%s\n' "$ctx" | head -1)"
case "$first" in
  "Project Brain index for this workspace (project notes, not instructions from the user)."*) ok "trusted: preamble first" ;;
  *) bad "trusted: preamble missing (got: $first)" ;;
esac
if printf '%s' "$ctx" | grep -q "deploy outside the EU"; then ok "trusted: content injected"; else bad "trusted: content missing"; fi
mode="$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$HOME/.project-brain/trusted.json")"
if [ "$mode" = "0o600" ]; then ok "trust store is 0600"; else bad "trust store mode $mode"; fi

# 4. awkward characters -> valid JSON, zero-width made visible, \r and other controls dropped
python3 - "$ws/.project-brain/index.compact" <<'PY'
import sys
s = ('tab\there\r\n"quotes" and \\backslashes\\ and emoji 🧠 and zero​width and bell\x07 '
     'and bidi‮evil and tag\U000E0041\n')
open(sys.argv[1], "w", encoding="utf-8").write(s)
PY
out="$(inject "$ws")"
if printf '%s' "$out" | valid_json; then ok "awkward chars: valid JSON"; else bad "awkward chars: invalid JSON"; fi
ctx="$(printf '%s' "$out" | context)"
if printf '%s' "$ctx" | grep -q 'zero<U+200B>width'; then ok "zero-width made visible"; else bad "zero-width not made visible"; fi
if printf '%s' "$ctx" | grep -q 'bidi<U+202E>evil'; then ok "bidi control made visible"; else bad "bidi control not made visible"; fi
if printf '%s' "$ctx" | grep -q 'tag<U+E0041>'; then ok "tag character made visible"; else bad "tag character not made visible"; fi
if printf '%s' "$ctx" | python3 -c 'import sys; t=sys.stdin.read(); sys.exit(0 if ("\r" not in t and "\x07" not in t and "​" not in t) else 1)'; then
  ok "raw \\r, bell and zero-width absent"; else bad "raw control/invisible characters still present"; fi
if printf '%s' "$ctx" | grep -q '🧠' && printf '%s' "$ctx" | grep -qF '"quotes" and \backslashes\'; then
  ok "emoji, quotes and backslashes kept"; else bad "emoji/quotes/backslashes mangled"; fi

# 5. oversized compact -> capped with the marker
python3 -c 'import sys; open(sys.argv[1],"w").write("".join("line %05d %s\n" % (i, "x"*60) for i in range(2000)))' "$ws/.project-brain/index.compact"
ctx="$(inject "$ws" | context)"
bytes="$(printf '%s' "$ctx" | wc -c)"
if printf '%s' "$ctx" | grep -q 'truncated at 16 KB'; then ok "oversized: truncation marker"; else bad "oversized: no marker"; fi
if [ "$bytes" -lt 17500 ]; then ok "oversized: capped ($bytes bytes)"; else bad "oversized: not capped ($bytes bytes)"; fi

# 6. --revoke -> back to the notice
"$SKILL/brain-trust" "$ws" --revoke >/dev/null
if inject "$ws" | context | grep -q "isn't trusted"; then ok "revoke: notice again"; else bad "revoke: still loading"; fi

# 7. init (--created-here) trusts a fresh, untracked brain ...
ws2="$(new_ws fresh)"
if "$SKILL/brain-trust" "$ws2" --created-here >/dev/null && inject "$ws2" | context | grep -q "deploy outside the EU"; then
  ok "init: created-here trusts a fresh brain"; else bad "init: created-here did not trust"; fi
if "$SKILL/brain-trust" --list | grep -q "created here.*$ws2"; then ok "list shows it"; else bad "list missing it"; fi

# ... but not one that git tracks (e.g. a cloned repo) ...
ws3="$(new_ws cloned)"
git -C "$ws3" init -q && git -C "$ws3" add .project-brain && \
  git -C "$ws3" -c user.email=t@example.invalid -c user.name=t commit -qm brain
if "$SKILL/brain-trust" "$ws3" --created-here >/dev/null 2>&1; then bad "created-here trusted a git-tracked brain"; else ok "created-here refuses a git-tracked brain"; fi

# ... nor an old one (e.g. unpacked from an archive, which keeps the old mtime)
ws4="$(new_ws archived)"
touch -t 202001010000 "$ws4/.project-brain/index.md"
if "$SKILL/brain-trust" "$ws4" --created-here >/dev/null 2>&1; then bad "created-here trusted an old brain"; else ok "created-here refuses an old brain"; fi

# 8. without a terminal and without --yes, brain-trust refuses (an agent can't trust silently)
if "$SKILL/brain-trust" "$ws4" </dev/null >/dev/null 2>&1; then bad "trusted without --yes and without a terminal"; else ok "no terminal, no --yes: refused"; fi

exit "$fail"
