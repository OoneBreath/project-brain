#!/usr/bin/env bash
# install.sh merges the three hooks into settings.json with python3 (no node needed): keeps existing
# settings, is idempotent, and leaves an invalid settings.json untouched.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME/.claude"

fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

echo '{"model": "opus", "permissions": {"allow": ["Bash(ls:*)"]}}' > "$HOME/.claude/settings.json"
bash "$REPO/install.sh" >/dev/null
S="$HOME/.claude/settings.json"
python3 - "$S" <<'PY' && ok "hooks merged, existing settings kept" || bad "merge result wrong"
import json, sys
c = json.load(open(sys.argv[1]))
assert c["model"] == "opus" and c["permissions"]["allow"] == ["Bash(ls:*)"]
cmds = {e: [h["command"] for x in c["hooks"][e] for h in x["hooks"]] for e in ("Stop", "SessionStart", "PostToolUse")}
assert any(p.endswith("/brain-inject") for p in cmds["SessionStart"])
assert any(p.endswith("/brain-nudge") for p in cmds["Stop"])
assert any(p.endswith("/brain-autocompact") for p in cmds["PostToolUse"])
assert c["hooks"]["PostToolUse"][0]["matcher"] == "Edit|Write|MultiEdit"
PY
[ -x "$HOME/.claude/skills/project-brain/brain-trust" ] && ok "brain-trust installed" || bad "brain-trust not installed"

before="$(cat "$S")"
bash "$REPO/install.sh" >/dev/null
[ "$(cat "$S")" = "$before" ] && ok "second run changes nothing" || bad "second run changed settings.json"

echo '{ not json' > "$S"
bash "$REPO/install.sh" >/dev/null
[ "$(cat "$S")" = '{ not json' ] && ok "invalid settings.json left untouched" || bad "invalid settings.json was modified"

exit "$fail"
