# Changelog

All notable changes to Project Brain are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); the project uses semantic-ish versioning.

## [2.4.0] — 2026-09-10

Closes a gap an audit of the brain's own claims turned up: the README promises the per-session
cost stays bounded "not by how much history you keep" — true across projects (HOT/WARM/COLD tiers,
2.0), but not true *within* a single project, whose full topic list rendered unconditionally no
matter how large it grew. **Backward compatible**, still zero required runtime dependencies.

### Added
- **Topic-level tiering in the compact index.** The same idea as HOT/WARM/COLD, one level down:
  `⚠ in-progress` topics are always shown in full, however many there are; once a project passes
  **15 topics**, its finished ones (`✓v`/`✓d`/`✗`/`⨯`) start collapsing — the most-recently-dated
  ones stay expanded up to that cap, the rest fold into one `+K more, oldest <date>` line. Pure
  function of `index.md`, deterministic, no new file format. `brain-check`'s existing "project has
  >15 topics" warning now references the same threshold (`_compact.TOPIC_THRESHOLD`) instead of a
  second, independently-defined `15`, and its wording reflects that the compact self-corrects now
  even though the underlying files still benefit from consolidating.

## [2.3.0] — 2026-08-16

Closes the loop the last two releases opened: the brain now loads itself (2.2), stays fresh
without a manual step, gets mechanical drift fixed for you, and is searchable by tag/keyword.
**Backward compatible**, still zero required runtime dependencies (Python 3 stdlib only).

### Added
- **`brain-autocompact` — a new `PostToolUse` hook (matched to `Edit|Write|MultiEdit`) that
  regenerates `index.compact` right after `index.md` is saved.** Without it, `index.compact` —
  what `brain-inject` loads at session start — only refreshes when someone remembers to run
  `brain-compact` by hand, so it can drift stale for an entire session. Regeneration is
  deterministic and free (no LLM call), so doing it on every save is cheap. Silent no-op for
  any edit that isn't a brain's `index.md`; never blocks the tool call. Wired automatically for
  plugin installs (`hooks/hooks.json`); `install.sh` registers it for skill installs alongside
  the other two hooks, through the same idempotent merge routine (now matcher-aware).
- **`brain-check --fix`** — applies the two *mechanical* fixes before validating: regenerates a
  missing/stale `index.compact`, and rotates any project's `_session.md` past 5 active lines into
  `_session.cold.md` (oldest entries move out, newest-first order preserved across both files).
  Everything else — orphans, staleness, conflicts — stays a human judgment call; `--fix` never
  guesses at those. Idempotent: a second `--fix` reports "nothing to fix" once the brain is
  current. Then runs the normal validation so you see what, if anything, still needs you.
- **`brain-find QUERY [workspace] [--body]`** — search a brain by tag or keyword instead of
  walking the index by hand. Fast path matches `tags:` frontmatter, filename, and
  `project:`/`topic:`/`person:` fields (cheap, low-noise); `--body` extends to full file text
  when a tag guess doesn't land. Groups results by project with status/version/tags shown.

## [2.2.0] — 2026-08-15

New hook that makes the brain load mechanically instead of relying on the agent choosing to
read it. **Backward compatible**, still zero required runtime dependencies.

### Added
- **`brain-inject` — auto-loads `index.compact` on every session start.** A new bundled
  `SessionStart` hook reads `.project-brain/index.compact` for the current workspace and returns
  it via `hookSpecificOutput.additionalContext`, so the compact index lands in context before the
  agent does anything — it no longer depends on the model deciding to read it. Motivated by a
  confirmed case of a small/fresh model skipping the read on a no-task greeting. No brain in the
  project → silent no-op. Uses `jq` opportunistically for JSON-string escaping when present, with
  a dependency-free manual-escape fallback — same zero-hard-dependency stance as the rest of the
  skill.
- **Plugin installs get it automatically** (`hooks/hooks.json`); **skill installs** get it via
  `install.sh`, which now registers `Stop` and `SessionStart` hooks through one shared,
  idempotent `register_hook()` merge routine (previously `Stop`-only).

## [2.1.2] — 2026-07-01

Patch: small correctness fixes found by auditing the tool against its own author's
production brain. **Backward compatible** — no format changes, no new required fields.

### Fixed
- **People changes now count as compact drift.** `data_lines()` stripped every `@` line as
  metadata, but `@people` / `@ <slug> …` lines are data — editing the `# People` section never
  triggered the "index.compact is out of date" warning. Only the `@src …` meta line is stripped
  now. Regression test added (`tests/test-compact-people-drift.sh`).
- **`brain-nudge` no longer nudges right after a save.** A merely-dirty git tree was treated as
  unsaved work, so the very next Stop after updating `index.md` (code still uncommitted — the
  normal case) nudged again. It now nudges only when a change is *newer* than `index.md`.
- **HOT tiering counts the resume line.** Project recency was the latest topic date only, so a
  project actively being worked on (fresh `> resume`, topic not re-dated yet) could lose its
  HOT slot. Recency is now max(topic dates, resume date).
- **`[inactive …]` no longer parses as `active`** — people/index status matching uses word
  boundaries instead of substring containment.
- **`--diff` no longer mislabels archived topics** as belonging to a project called `_archive`;
  archived material is excluded from the changed-since view entirely.
- **`brain-compact` counted only WARM projects** in its summary line (`P ` missed `P+`).

### Added
- **`brain-check` prints its own version** (from the SKILL.md next to it) in the summary line —
  a stale install (repo updated, `install.sh` not re-run) is now visible instead of silently
  mis-validating. That exact drift produced false `conflicting relational-db` warnings on a
  real brain: the repo had `allow_conflict:`, the installed copy didn't.
- **Wider export redaction:** emails / ssh targets (`user@host`), IPv6 addresses, and a much
  broader TLD list (`.pl`, `.cz`, `.fr`, `.it`, `.online`, `.site`, … — the author's own `.pl`
  was previously not redacted).

## [2.1.1] — 2026-06-19

Patch: a narrow opt-out for the conflict detector. **Backward compatible** — brains without the new
field behave exactly as before.

### Added
- **`allow_conflict:` frontmatter on a topic.** The conflict detector flags a project that names two
  of the same mutually-exclusive tech (a relational DB, a host) — but an **aggregator** topic (an
  infra topology map, a multi-repo roadmap/checklist) legitimately lists several at once. Such a topic
  can now opt a group out with `allow_conflict: [relational-db]` (or `true` for all groups). It is
  **narrow**: only that topic's tokens are excluded from the tally, so genuine drift in *other* topics
  still surfaces. An inline `# comment` after the value is tolerated; an unknown group name is warned.

### Fixed
- Aggregator topics no longer raise a permanent false-positive conflict warning that no note could
  silence (e.g. an infra `server-topology` that maps each project's DB across MariaDB/Postgres/SQLite).

## [2.1.0] — 2026-06-14

Quality-of-life release that finishes wiring the brain into Claude Code's own machinery. **Backward
compatible**, still **zero runtime dependencies** for the brain itself (the installer uses `node`,
which Claude Code already ships, instead of `jq`).

### Added
- **`install.sh` now wires the `brain-nudge` Stop hook for skill installs.** Previously only the plugin
  path registered it (via `hooks/hooks.json`); a skill-only install shipped the hook but never ran it.
  The installer now **merges** the hook into `~/.claude/settings.json` — it preserves existing keys
  (permissions, model, …), is idempotent (skips if already present), backs up and prints a diff before
  writing, and leaves a corrupt/foreign settings.json untouched. Merge is done with `node` (a hard
  Claude Code dependency), so no `jq` is required.
- **`brain-bootstrap` — point Claude Code's native per-project memory at the brain, non-destructively.**
  An on-demand tool that seeds a small, **conditional** redirect ("if this workspace has a
  `.project-brain/`, that is the source of truth") into native `MEMORY.md` so it defers to the brain
  instead of competing with it and doubling per-session tokens. It never reverse-engineers the internal
  `<encoded-cwd>` directory name (not safely reversible); it globs the memory dirs Claude already
  created, so it is OS-agnostic. Contract: empty/absent → write stub; our marker present → skip
  (idempotent); existing user notes → back up (`.bak-<ts>`) and **prepend** the redirect, never delete
  or reorder. Proven on simulated foreign paths and with real user notes preserved byte-identical.
- **Init-time seeding (opt-in).** `init` mode now offers, with the user's ok, to seed the same
  non-destructive native→brain redirect for the current workspace.

### Changed
- Docs: the `brain-nudge` hook is now described accurately as an **end-of-turn, throttled** reminder
  (it nudges once after work, not "at session end" and not every turn), in both README and SKILL.md.

## [2.0.0] — 2026-06-14

Project Brain 2.0 — a major release built in ten stages. **Backward compatible:** every existing
`.project-brain/` keeps working (new fields are optional, new `brain-check` signals are advisory
warnings, exit 1 stays errors-only), and still **zero dependencies** (Python 3 stdlib only).

### Added
- **Dual-format index.** `index.md` stays the single, hand-edited source of truth; a generated
  `index.compact` (one-way, deterministic, 0-token Python — `brain-compact`) is what an agent reads at
  session start. Measured on the author's real 6-project / 15-topic brain: `index.md` 3415 B →
  `index.compact` 1655 B (**−52%, ~440 tokens**); each topic's index line shrinks ~106 → ~24 chars.
  The saving scales with how much prose your summaries carry — on a tiny demo brain the fixed legend
  overhead can make the compact *larger*, so it's for brains with real accumulated content. A missing
  or stale compact → agents fall back to `index.md`, so it never breaks.
- **HOT / WARM / COLD tiers** in the compact — automatic by recency plus a `{hot}` pin (max 3); WARM
  collapses to a one-liner once a brain has **> 15 active projects**; COLD (`{archived}`) is omitted.
  Bounds the eager token cost as a brain grows.
- **One-line session summary.** A `> resume <date> · done/next/blocker` line per project (surfaced in
  the compact for HOT as `~ …`), with rolling history in `_session.md` (5 lines, older → `.cold.md`).
- **Memory hygiene.** `! never:` hard rules (brain-wide or per-project, always in the compact);
  `trust:` extended to `human`=FACT | `ai-inferred` | `pref`; an over-long-topic (> 40 lines) warning;
  delta-load (an `@updated` header + a documented protocol — reload only what changed).
- **Decision log.** `_decisions.md` (per project) + brain-wide `decisions.md` — `YYYY-MM: chosen >
  rejected — why`, read at planning time so a rejected option isn't quietly re-proposed.
- **`brain-check --report`** (a grouped, readable rundown) and a **conflict detector** — flags a
  project that names two of the same mutually-exclusive tech (a relational DB or a host). Tuned on a
  real brain: dropped `oracle` because it matched `oracle.py`, not the database.
- **`brain-export`** — bundle the brain into ONE pasteable file for claude.ai / Gemini / ChatGPT, with
  `--project` / `--max-tokens` and **infra (IPs, ports, paths, hosts, secrets) redacted by default**
  (`--include-infra` to opt in).
- **`people/`** — agreements with humans (client / partner / vendor): `people/<slug>.md`, a `# People`
  index section, a `@people` compact block, a relationship status (`active|prospect|paused|closed`),
  validated like topics.
- **`brain-check --diff <date>`** — what changed since a date (topics, session lines, resume,
  decisions, people), read straight from the brain's own dates — no git.

### Changed
- **README rebuilt**: cross-tool header (Claude Code · Cursor · Windsurf · any file-reading agent),
  the unique advantages surfaced up front, a "How is this different from native Session Memory /
  ClaudeMem?" comparison, and a "What's new in 2.0" section.
- `brain-check`, `brain-compact`, and `brain-export` share one renderer module (`_compact.py`), so the
  compact format has a single definition and the writer and the validator can't drift.

## [1.1.2] — 2026-06-07

Docs and attribution only — no behavior change.

### Added
- `CONTRIBUTING.md` and `SECURITY.md` — how to contribute, and how to report a vulnerability
  privately (with a reminder never to store secrets in brain notes).
- README section **"Works across tools (same brain, different agents)"** — the same `.project-brain/`
  was read and written by Claude Code and by Windsurf (state persisted across a restart), and read by
  a third-party agent over SSH. Documents the honest limit: managing a brain needs a capable agentic
  model — a small local 7B model failed the read→use→write loop and hallucinated the brain's contents.

### Changed
- Author attribution now also travels with the **distributed** skill: `author:` in `SKILL.md`
  frontmatter + an attribution footer, plus an author/repo/license header in `install.sh`
  (previously attribution lived only in `LICENSE`, `README`, and the plugin manifest).

## [1.1.1] — 2026-06-05

### Changed
- The cross-project body-mention check is now **opt-in via `brain-check --strict`** (was on by
  default). On tightly-coupled multi-project brains, projects reference each other on purpose, so
  flagging every legitimate mention was noise. The precise guard — `project:` must match its folder —
  stays **always on**. Found by testing against a real interconnected brain before shipping.

## [1.1.0] — 2026-06-05

Backward compatible: every new field is optional and every new check is an advisory **warning**,
so existing brains keep passing `brain-check` untouched.

### Added
- **Provenance (`trust:`)** — mark a note `human` (a person confirmed it) or `ai-inferred` (the model
  wrote it without confirmation). Recall weighs it; the validator checks the value.
- **Staleness (`review_by:`)** — a finished topic past its `review_by` date (or, with none, older than
  a ~180-day horizon) is flagged "re-confirm before trusting".
- **Cross-project guard** — `brain-check` warns when a topic's `project:` doesn't match its folder, or
  when a topic name-drops another project without declaring it in `cross_refs:`.
- **`brain-nudge` Stop hook** — reminds you to save when a session changed files but the brain wasn't
  updated. It only suggests; it never writes to the brain and never blocks. Auto-wired for plugin
  installs via `hooks/hooks.json`; skill-only users can add a one-line `Stop` hook.
- **Plugin manifest** (`.claude-plugin/plugin.json`) — name, version, author, homepage, repository,
  license, keywords; enables installing as a Claude Code plugin.

### Changed
- `brain-check` extended with the provenance, staleness, and cross-project checks (still zero-dep).
- Topic template and `SKILL.md` document the new optional fields and the suggest-don't-save rule.

## [1.0.0] — 2026-06-01

Initial public release.

### Added
- The `.project-brain/` convention: a small `index.md` map plus on-demand `projects/<name>/<topic>.md`
  topic files (cold storage — only the index is loaded eagerly).
- `project-brain` skill with `init` / `recall` / `save` modes.
- Status-with-outcome legend (`verified` / `done` / `in-progress` / `failed` / `superseded`).
- Versioning instead of overwriting; archiving instead of deleting.
- `brain-check` validator (pointers resolve, frontmatter valid, index↔topic status in sync).
