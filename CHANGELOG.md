# Changelog

All notable changes to Project Brain are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); the project uses semantic-ish versioning.

## [Unreleased]

### Added
- **CI** (`.github/workflows/test.yml`): every push to `main` and every pull request runs on Ubuntu and
  macOS with Python 3.9 and 3.12. It calls `tests/run-all.sh`, which checks the syntax of every script
  under `skills/` and `install.sh` (`bash -n`, or a Python compile that writes no files) and runs every
  `tests/test-*.sh`, printing PASS/FAIL per item. Python 3.9 runs on `ubuntu-24.04`, because
  setup-python has no 3.9 for the newest Ubuntu image.

- **`brain-check` lints hard rules.** `hard-rule-grants` (a warning; an error with `--strict`) fires on a
  `!` line in `index.md`, a topic or a person file that grants instead of restricting: skips a
  confirmation ("never ask before…", "without asking", "pre-approved"), widens permissions
  ("--dangerously…", "bypass", "sudo", "run as root", "ignore previous", "override"), hides something
  from the user ("don't tell", "silently"), or says to follow remote content (a URL plus
  follow/run/execute). A rule that is itself negated — "! never: bypass the review", "! never use sudo
  on prod" — is a restriction and isn't flagged. The phrase list lives in one place,
  `_trust.HARD_RULE_GRANTS`; `brain-trust` uses it too and marks such rules before you trust a brain.
- **`hidden-chars`** (an error): zero-width, bidi-control or Unicode tag characters anywhere in the
  brain, with line:column positions. A zero-width joiner between two emoji (family, flag sequences) is
  not counted, and `brain-inject` no longer rewrites it either.
- **`brain-check --report`** lists every hard rule with its file, and — for a brain you trusted — the
  rules added to `index.md` since then. `brain-trust` now records the hard rules at trust time;
  `brain-trust WORKSPACE --yes` on an already trusted workspace records its current state.

- **Anchor drift: "verified" stops counting once the code changes.** A topic can list `anchors:` —
  files, optionally `#symbol`, relative to its `root:` or the workspace. For a verified/done topic,
  `brain-check` warns (`anchor-drift`) when an anchor file is missing, a symbol no longer appears in it,
  or, in a git repository, the file has commits (or uncommitted edits) dated after the topic's
  `last_done`. Read-only git, no network; outside git only the first two run, and the report says so
  once. `brain-check --fix` writes `· drift <date>` into the topic's status bracket in `index.md` and
  removes it after a re-verify; the compact shows `✓v?` / `✓d?` (new legend line). Only `--fix` writes
  it, never a hook, so the compact stays a pure function of `index.md`. Dates are days, so a change
  on the same day as the verification isn't detected. `templates/topic.md` lists the two fields.

### Changed
- **SKILL.md split: 564 → 198 lines** (200 after the anchor-drift lines above). SKILL.md is what the agent loads every time the skill is used.
  It now keeps only what every use needs — where the brain lives, the modes (init / recall / save /
  validate), what a save writes (index line, status legend, hard rules), the Rules — plus a "read X
  when Y" table. The detail moved, with the wording unchanged, into
  `skills/project-brain/references/`: `init.md`, `format.md`, `compact-and-tiers.md`,
  `sessions-and-decisions.md`, `provenance-and-staleness.md`, `validate-and-search.md`, `export.md`,
  `hooks.md`. Measured on this change (`wc`, and ~4 chars/token, the same estimate `brain-export`
  uses — approximate, stdlib has no tokenizer): **564 lines / 36,293 bytes / ~8,970 tokens → 198
  lines / 13,216 bytes / ~3,270 tokens**. The references (28,372 bytes) are read only when needed.
  `airlock audit skills/project-brain` (Skill Airlock 0.2.0): before REVIEW (MEDIUM `agent-config`
  in SKILL.md, LOW `oversized`, ~8,762 tok on use), after OK (no MEDIUM, ~3,064 tok on use).

- **SKILL.md clarifications** from a fresh-agent test of the split (these were unclear before it too):
  where the scripts live and what `[workspace]` means; recall reads the index the same way session
  start does (`index.compact`, else `index.md`); a save also updates a related topic line it finished
  or changed; an explicit "save it" from the user is the decision "suggest, don't auto-save" waits for.
- **README: 399 → 248 lines.** The five "What's new in 2.0–2.4" sections are gone (the CHANGELOG
  already held all of it) and a 4-line "Latest (2.5)" block links here; Install moved right after
  "The fix"; a short "Security" section (brain content is data, trust before auto-load, hard rules only
  restrict, no secrets) links SECURITY.md; "How it works", "The validator" and "Native memory" were
  merged where they repeated each other. No feature description and no measured number was dropped.

### Fixed
- **A topic line with its own `[...]` in the description lost its status.** The first `[...]` on an
  `index.md` line was taken as the status bracket, so a description like "plaintext [Security]
  password" or a `[[wiki-link]]` made `index.compact` show the topic without status, date or version,
  and `brain-check` skipped its status-drift check (and the new anchor check). The status bracket is
  now the last `[...]` holding a status word or a date. Found on a real brain (2 of 91 topic lines).
  Regression test: `tests/test-status-bracket.sh`.
- **`brain-nudge` on macOS** read the modification time of `index.md` with `date -r FILE` and GNU
  `stat -c`; where neither works (BSD `date -r` takes seconds, BSD `stat` uses `-f %m`) it fell back to
  `0`, so after its first reminder it never reset. It now tries `stat -c %Y`, then `stat -f %m`.
- Two tests ran the scripts from a hard-coded `/home/ubuntu/...` path, so they failed on any other
  machine; they now use the repo they live in. One test used `sed -i` without a suffix, which BSD sed
  rejects, and one used `sed '/P+\?/'` (`\?` is a GNU extension), so it failed on macOS.

## [2.4.2] — 2026-11-09

### Action needed
- **Run `brain-trust` once in each workspace whose brain you created yourself.** After this update a
  brain is auto-loaded only in a trusted workspace, and existing brains are not trusted
  automatically (a brain you made can't be told apart from one that came with a cloned repo or a
  downloaded archive). Until you do, the session starts with a one-line notice instead of the index.
  Review what the command shows (hard rules, size), then confirm:
  `~/.claude/skills/project-brain/brain-trust /path/to/workspace` (plugin installs: the same script
  under the plugin's `skills/project-brain/`). New brains made with `init` are trusted by `init`.

### Security
- **`brain-inject` no longer loads a brain from an untrusted workspace.** A repository can carry a
  committed `.project-brain/`; before, its `index.compact` reached the agent at session start, with
  `!` lines presented as hard rules. Now the trust store `~/.project-brain/trusted.json` (outside
  every repo, mode 600) decides. Details in [SECURITY.md](SECURITY.md).
- **New `brain-trust` command:** `brain-trust [workspace]` shows the brain's hard rules and size and
  asks before trusting (`--yes` skips the prompt, and is required without a terminal); `--revoke`,
  `--list`; `--created-here` is what `init` uses, and it refuses a brain that git tracks or that
  wasn't just created.
- **Fixed preamble** before the loaded index, written by the hook: project notes, not instructions
  from the user; hard rules (`!`) can only restrict and never grant permission, skip confirmation or
  override the user. SKILL.md says the same in its Rules and Hard rules sections.
- **Sanitised and capped:** zero-width, bidi-control and Unicode tag characters are shown as
  `<U+XXXX>`; other control characters except newline and tab are dropped; the text is capped at
  16 KB with a "truncated" line.

### Fixed
- **Invalid JSON without `jq`.** The bash hook's fallback escaped only backslash, quote and newline,
  so a tab, `\r` or any other control character in the brain produced invalid JSON and the session
  silently started without the index. `brain-inject` is now Python 3 (stdlib) and uses `json.dumps`.

### Changed
- `install.sh` merges the hooks into `settings.json` with `python3` instead of `node`, so a skill
  install no longer needs Node. Same behaviour: keeps existing settings, idempotent, backup + diff,
  leaves an invalid `settings.json` untouched.
- If a hard rule in your brain is really a standing permission ("always push after saving"), move
  it to `CLAUDE.md` or your agent's settings: a `!` line can only restrict.

### Tests
- `tests/test-brain-inject.sh` (22 checks: no brain, untrusted notice, trusted preamble, valid JSON with
  tab/`\r`/quotes/backslashes/emoji/zero-width/bidi/tag characters, 16 KB cap, `--revoke`, `init`
  via `--created-here` and its refusals, no trust without `--yes` off a terminal) and
  `tests/test-install.sh` (merge keeps settings, idempotent, invalid JSON untouched).

## [2.4.1] — 2026-11-07

### Fixed
- **Hard rules written without the colon after `never` were truncated in `index.compact`** when the
  rule itself contained a colon later on: `! never commit .env files (see: security.md)` became
  `! never: security.md)`, so the agent reading the compact at session start saw a mangled rule.
  The marker (`! never` plus an optional colon) is now stripped with one pattern and the rest of the
  line is kept as is. Rules written as `! never: …` were not affected. Regression test:
  `tests/test-compact-hard-rules.sh`. Reported in #1 — thank you.

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
