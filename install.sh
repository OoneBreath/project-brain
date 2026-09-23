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
# Uses node (a hard dependency of Claude Code) so there's no jq requirement.
#
# $1 = hook event name (e.g. "Stop", "SessionStart", "PostToolUse")
# $2 = marker substring used to detect "already registered" (the script's basename)
# $3 = full command to run
# $4 = optional matcher (PostToolUse only, e.g. "Edit|Write|MultiEdit")
register_hook() {
  local event="$1" marker="$2" cmd="$3" matcher="${4:-}"
  if ! command -v node >/dev/null 2>&1; then
    echo "  ! node not found — skipping ${event}-hook registration."
    echo "    Add it by hand: a ${event} hook running ${cmd}"
    return 0
  fi
  mkdir -p "$(dirname "$SETTINGS")"
  local tmp; tmp="$(mktemp)"
  local rc=0
  node - "$SETTINGS" "$event" "$marker" "$cmd" "$matcher" "$tmp" <<'NODE' || rc=$?
const fs = require('fs');
const [, , settingsPath, event, marker, hookCmd, matcher, outPath] = process.argv;
let cfg = {};
try {
  const raw = fs.existsSync(settingsPath) ? fs.readFileSync(settingsPath, 'utf8').trim() : '';
  cfg = raw ? JSON.parse(raw) : {};
} catch (e) {
  process.exit(3); // existing settings.json is not valid JSON -> do not touch it
}
cfg.hooks = cfg.hooks || {};
let list = Array.isArray(cfg.hooks[event]) ? cfg.hooks[event]
         : (cfg.hooks[event] ? [cfg.hooks[event]] : []);
if (JSON.stringify(list).includes(marker)) process.exit(10); // already registered
const entry = { hooks: [{ type: 'command', command: hookCmd }] };
if (matcher) entry.matcher = matcher;
list.push(entry);
cfg.hooks[event] = list;
fs.writeFileSync(outPath, JSON.stringify(cfg, null, 2) + '\n');
process.exit(0);
NODE
  case "$rc" in
    10) echo "  ✓ ${event} hook already registered — settings.json unchanged"; rm -f "$tmp"; return 0 ;;
    3)  echo "  ! settings.json is not valid JSON — left untouched, hook not added"; rm -f "$tmp"; return 0 ;;
    0)  : ;;
    *)  echo "  ! hook registration failed (node rc=$rc) — settings.json left untouched"; rm -f "$tmp"; return 0 ;;
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
