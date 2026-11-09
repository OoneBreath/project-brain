#!/usr/bin/env bash
# Project Brain — persistent project memory for Claude Code.
# Author: Slawomir Luzny <info@fixflex.co.uk> (https://fixflex.co.uk) — MIT licensed.
# Repo:   https://github.com/OoneBreath/project-brain
#
# Install the project-brain skill for Claude Code (personal scope).
# Re-run any time to update. Run on every machine where you use Claude Code.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills/project-brain"
DEST="${HOME}/.claude/skills/project-brain"
SETTINGS="${HOME}/.claude/settings.json"

if [ ! -f "${SRC}/SKILL.md" ]; then
  echo "error: ${SRC}/SKILL.md not found — run this from inside the repo." >&2
  exit 1
fi

mkdir -p "${DEST}"
cp -R "${SRC}/." "${DEST}/"
echo "✓ Installed project-brain skill to ${DEST}"

# Register the bundled hooks in settings.json.
# Skill-mode installs (unlike the plugin) don't get hooks wired automatically,
# so we MERGE each one in: never overwrite existing settings (permissions, model, ...),
# idempotent (skip if already present), back up + show a diff before writing.
# Uses python3 (the skill's scripts need it anyway), so there is no node or jq requirement.
#
# $1 = hook event name (e.g. "Stop", "SessionStart", "PostToolUse")
# $2 = marker substring used to detect "already registered" (the script's basename)
# $3 = full command to run
# $4 = optional matcher (PostToolUse only, e.g. "Edit|Write|MultiEdit")
register_hook() {
  local event="$1" marker="$2" cmd="$3" matcher="${4:-}"
  if ! command -v python3 >/dev/null 2>&1; then
    echo "  ! python3 not found — skipping ${event}-hook registration."
    echo "    Add it by hand: a ${event} hook running ${cmd}"
    return 0
  fi
  mkdir -p "$(dirname "$SETTINGS")"
  local tmp; tmp="$(mktemp)"
  local rc=0
  python3 -I - "$SETTINGS" "$event" "$marker" "$cmd" "$matcher" "$tmp" <<'PY' || rc=$?
import json, os, sys
settings_path, event, marker, hook_cmd, matcher, out_path = sys.argv[1:7]
try:
    raw = open(settings_path, encoding="utf-8").read().strip() if os.path.exists(settings_path) else ""
    cfg = json.loads(raw) if raw else {}
    if not isinstance(cfg, dict):
        raise ValueError("not an object")
except (OSError, ValueError):
    sys.exit(3)  # existing settings.json is not valid JSON -> do not touch it
hooks = cfg.setdefault("hooks", {})
lst = hooks.get(event)
lst = lst if isinstance(lst, list) else ([lst] if lst else [])
if marker in json.dumps(lst):
    sys.exit(10)  # already registered
entry = {"hooks": [{"type": "command", "command": hook_cmd}]}
if matcher:
    entry["matcher"] = matcher
lst.append(entry)
hooks[event] = lst
with open(out_path, "w", encoding="utf-8") as f:
    f.write(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
PY
  case "$rc" in
    10) echo "  ✓ ${event} hook already registered — settings.json unchanged"; rm -f "$tmp"; return 0 ;;
    3)  echo "  ! settings.json is not valid JSON — left untouched, hook not added"; rm -f "$tmp"; return 0 ;;
    0)  : ;;
    *)  echo "  ! hook registration failed (python3 rc=$rc) — settings.json left untouched"; rm -f "$tmp"; return 0 ;;
  esac
  echo "  + registering Project Brain ${event} hook (${marker}):"
  echo "  --- settings.json diff ---"
  if [ -f "$SETTINGS" ]; then
    diff -u "$SETTINGS" "$tmp" | sed 's/^/    /' || true
  else
    echo "    (creating new settings.json)"
    sed 's/^/    /' "$tmp"
  fi
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "${SETTINGS}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$tmp" "$SETTINGS"
  echo "  ✓ settings.json updated (previous version backed up)"
}
register_hook "Stop" "brain-nudge" "${DEST}/brain-nudge"
register_hook "SessionStart" "brain-inject" "${DEST}/brain-inject"
register_hook "PostToolUse" "brain-autocompact" "${DEST}/brain-autocompact" "Edit|Write|MultiEdit"

echo "  Start a Claude Code session and run:  /project-brain  (then 'init')"
echo "  Already have a brain in a workspace? Brains are loaded only in trusted workspaces (2.4.2+):"
echo "    review it, then run:  ${DEST}/brain-trust /path/to/workspace"
