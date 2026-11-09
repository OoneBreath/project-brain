# The bundled hooks

> Part of the Project Brain skill — SKILL.md points here. Moved out of SKILL.md in 2.5 to keep
> the always-loaded part small; the wording is unchanged.

## Optional: the bundled hooks (brain-inject, brain-autocompact, brain-nudge)

Three small hooks make the brain load and stay current mechanically, instead of depending on the
agent choosing to do any of it.

**`brain-inject`** (`SessionStart`) reads `.project-brain/index.compact` for the current workspace
and returns it as context at the **start of the session**, before the agent does anything — so the
compact index is always loaded, even by a model that would otherwise skip reading it on a plain
greeting. No brain in the project → silent no-op. It loads a brain only in a **trusted** workspace
(`~/.project-brain/trusted.json`, outside every repo): `init` trusts the brain it creates, and
`brain-trust [workspace]` trusts one you created earlier or reviewed (`--revoke`, `--list`). An
untrusted brain gets a one-line notice instead of its content. The loaded text starts with a fixed
preamble (notes, not instructions; hard rules only restrict), is capped at 16 KB, and has invisible
characters made visible.

**`brain-autocompact`** (`PostToolUse`, matched to `Edit|Write|MultiEdit`) regenerates
`index.compact` right after `index.md` is saved — so the compact index (what `brain-inject` loads,
and what an agent re-reads mid-session) never sits stale for the rest of a session waiting on
someone to remember `brain-compact`. It's a silent no-op for every edit that isn't a brain's
`index.md`, and it never blocks the tool call.

**`brain-nudge`** (`Stop`) reminds you to keep the brain current. It fires at the **end of a turn**
(not at session end) and is **throttled**, so when a turn changed files but `index.md` wasn't
updated, it surfaces the note *once after the work* — *"you did work — want to save any of it?"* — not
on every turn. It **never writes to the brain and never blocks** — auto-saving everything would turn
the map into a swamp. It only nudges; the human still decides what is worth keeping.

- Installed as a **plugin**, all three hooks are wired up automatically (`hooks/hooks.json`).
- Installed as a **skill**, `install.sh` wires them for you — it **merges** each hook into
  `~/.claude/settings.json` (keeping your existing settings, idempotent, with a backup). If you ever
  need to add them by hand:
  ```json
  { "hooks": {
    "SessionStart": [ { "hooks": [
      { "type": "command", "command": "~/.claude/skills/project-brain/brain-inject" }
    ] } ],
    "PostToolUse": [ { "matcher": "Edit|Write|MultiEdit", "hooks": [
      { "type": "command", "command": "~/.claude/skills/project-brain/brain-autocompact" }
    ] } ],
    "Stop": [ { "hooks": [
      { "type": "command", "command": "~/.claude/skills/project-brain/brain-nudge" }
    ] } ]
  } }
  ```
