# Project Brain — persistent, navigable memory for AI coding agents

**Stop re-explaining your projects to the AI every session.**

[![Version](https://img.shields.io/badge/version-2.4.0-blue)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Runtime deps](https://img.shields.io/badge/runtime%20deps-zero-success)](#how-it-works)
[![Works with](https://img.shields.io/badge/works%20with-Claude%20Code%20%C2%B7%20Cursor%20%C2%B7%20Windsurf-purple)](#works-across-tools-same-brain-different-agents)

Project Brain is a skill that gives your AI agent a small, navigable **map** of your projects — their
stack, decisions, pitfalls, what's done, what failed, and where you left off — so it stops forgetting,
stops mixing projects up, and stops re-reading a 1000-line README into context on every single task.

It is **not** a database, a server, or another AI wrapper. It's a convention plus a skill: a
`.project-brain/` folder of plain Markdown that any file-reading agent navigates through an index,
loading detail only when it's actually needed. **Zero runtime dependencies** (Python 3 stdlib only).
Works across tools — **Claude Code · Cursor · Windsurf**, or any file-reading agent.

![Project Brain in action — the agent reads the project map, recalls how the cache fix was done, and refuses to silently redo verified work](docs/demo.gif)

<sub>Core recall flow above: read the map → recall with version history → refuse to silently redo verified work.</sub>

![The interview — a fresh agent session greets with full project context from the brain, then gives an unscripted, self-critical review of Project Brain itself](docs/interview.gif)

<sub>"The interview": a brand-new session types <code>hi</code> and is instantly oriented across every project from the brain — then answers, unscripted, whether the tool is actually any good (criticism included).</sub>

---

## The problem

Every new session, on every project:

- explain the architecture
- explain the deployment
- explain the stack
- explain the history
- explain the known pitfalls

…again. And after a few hours of work the model starts mixing details between projects — this one is
FastAPI + Postgres, that one is Node + tRPC + MySQL — and quietly redoing things you finished last week.

## The fix

```
.project-brain/
  index.md          # hand-edited MAP: projects → topics → status + pointer
  index.compact     # generated, deterministic — what the agent reads at startup
  projects/
    <project>/
      <topic>.md     # the detail, read only when needed
  _decisions.md      # why things were chosen (and rejected)
  _session.md        # rolling one-line session history
  people/            # agreements with clients / partners / vendors
```

The agent reads the **small index** first. Ask *"how did we solve the cache issue?"* and it follows one
pointer to one file — not the whole knowledge base. Ask it to *"swap the logo"* when the map says that
was done and verified three days ago, and it tells you and asks, instead of silently redoing it.

---

## What it actually saves

Be honest with yourself about why you'd use this:

- **Fewer tokens — when it applies.** If you currently keep everything in a giant always-loaded doc,
  splitting into a small index + on-demand topic files genuinely cuts per-session context; the compact
  and tiers cut it further on big brains. (Measured on a real 6-project / 15-topic brain:
  `index.md` 3415 B → `index.compact` 1655 B — **~52% smaller** — and the saving scales with how much
  prose your summaries carry, so a tiny brain sees less.)
- **Fewer hallucinations.** The map is an anchor. The model stops inventing your deployment or swapping
  one project's stack for another's — and the conflict detector catches it when a fact drifts.
- **Multi-month memory.** Come back after three months and the agent still knows how it works — without
  you pasting a kilometre of README.

---

## What makes it more than a flat notes file

**1. Status carries the outcome, not just "done."**
`✓ verified` vs `✗ failed` vs `⚠ in-progress` vs `⨯ superseded`. The model knows the difference between
*"done and works"* and *"we tried that and it broke"* — and won't silently redo it.

**2. Versioning, not overwriting.**
When an approach is replaced, the old one is kept as a superseded note — so the trail of what was tried
and why it changed survives.

**3. A small index, details on demand.**
`index.md` is the hand-edited source of truth; a generated `index.compact` (deterministic, 0-token
Python) is what the agent loads at startup. New topics go into cold storage — files nobody reads until
asked — so the per-session cost is bounded by the index, not by how much history you keep. It doesn't
bloat over time.

**4. HOT / WARM / COLD tiers.**
The compact surfaces recent/pinned projects (HOT), collapses the rest to one-liners (WARM) once you pass
**15 active projects**, and omits archived ones (COLD). The eager token cost stays bounded as the brain
grows.

**5. One-line session resume.**
Each project carries a `> resume <date> · done / next / blocker` line. Start a new session and the agent
already knows where you stopped and what's next — no *"what were we doing?"*

**6. Decision log.**
`_decisions.md` records `chosen > rejected — why`, read at planning time so a rejected option isn't
quietly re-proposed three weeks later.

**7. Memory hygiene.**
- `! never:` — hard rules the agent must not break.
- `trust:` — mark a note `human` (a person confirmed it) or `ai-inferred` (the model wrote it
  unconfirmed). Recall weighs them differently; a guess can't harden into "fact" just by being written.
- `review_by:` — finished topics past their date (or ~180 days) get flagged *"re-confirm before trusting."*
- delta-load — reload only what changed since last time.

**8. Export for other tools.**
`brain-export` bundles the brain into one pasteable file for claude.ai / Gemini / ChatGPT, with infra
(IPs, ports, paths, hosts, secrets) **redacted by default**.

---

## How is this different from native Session Memory / ClaudeMem?

Auto-memory tools (a tool's built-in session memory, ClaudeMem, and similar) summarize your transcripts
for you. That's genuinely zero-effort — and it's a different thing from what Project Brain is for. The
honest trade:

| | Auto session memory / ClaudeMem | **Project Brain** |
|---|---|---|
| How it's built | **Automatic** — summarizes your transcripts (zero effort) | **Curated** — a human chooses what's worth keeping |
| What it is | A running **journal** of what happened | A **map of truth**: status (✓/✗), versions, decisions |
| Trust | Undifferentiated | `human` (FACT) vs `ai-inferred` vs `pref` |
| Freshness | No expiry | `review_by:` + staleness flags |
| Multi-project | Mixes easily | Cross-project guard + conflict detector |
| Reach | Tied to one tool | Plain Markdown — Claude Code, Cursor, Windsurf, any file-reading agent |
| Ownership | Lives inside the tool | A folder you read, edit, grep, and **commit to your repo** |
| Cost over time | Grows with history | Index-first + tiers — eager cost stays **bounded** |
| Inspectable | Opaque | Every byte is yours to open and edit |

They're complementary: auto-memory is a frictionless journal; Project Brain is the deliberate,
inspectable, portable map you actually trust to plan against.

---

## The validator

A bundled `brain-check` (zero-dependency Python) keeps the map honest:

- pointers resolve to real files
- frontmatter is well-formed
- index ↔ topic status stay in sync
- a topic isn't filed under the wrong project (cross-project guard)
- a fact hasn't passed its freshness date
- a conflict detector flags a project naming two mutually-exclusive techs

`brain-check --report` gives a readable rundown; `brain-check --diff <date>` shows what changed since a
date — read straight from the brain's own dates, no git required.

> **What it does and doesn't do:** the validator checks structure and freshness — that labels exist and
> are well-formed, that pointers resolve, that statuses match. It does **not** judge whether your
> knowledge is *true*. A clean `brain-check` means the map is consistent, not that every note is correct.

---

## What's new in 2.4

An audit of the brain's own claims found the "cost stays bounded, not by how much history you
keep" promise held across projects (HOT/WARM/COLD) but not *within* one large project — backward
compatible, still zero required runtime dependencies.

- **Topic-level tiering in the compact index.** Same idea as HOT/WARM/COLD, one level down:
  `⚠ in-progress` topics always render in full; past 15 topics in one project, the finished ones
  collapse to the most-recently-dated cap plus one `+K more, oldest <date>` line, instead of every
  topic dumping unconditionally forever.

Full details in the [CHANGELOG](CHANGELOG.md).

---

## What's new in 2.3

Closes the loop 2.2 opened: the brain now stays fresh without a manual step, gets mechanical
drift fixed for you, and is searchable by tag/keyword — backward compatible, still zero required
runtime dependencies.

- **`brain-autocompact` — a new hook that regenerates `index.compact` right after `index.md` is
  saved.** Without it, the compact index only refreshes when someone remembers to run
  `brain-compact` by hand, so it can sit stale for a whole session. Silent no-op on any other file.
- **`brain-check --fix`** — applies the two *mechanical* fixes before validating: regenerates a
  missing/stale `index.compact`, and rotates a project's `_session.md` past 5 active lines into
  `_session.cold.md`. Everything else (orphans, staleness, conflicts) stays a human call.
- **`brain-find QUERY [workspace] [--body]`** — search the brain by tag or keyword instead of
  walking the index by hand. Matches `tags:`, filename, and project/topic/person fields by
  default; `--body` extends to full file text.

Full details in the [CHANGELOG](CHANGELOG.md).

---

## What's new in 2.2

New hook that makes the brain load mechanically instead of relying on the agent choosing to read
it — backward compatible, still zero required runtime dependencies.

- **`brain-inject` auto-loads `index.compact` on every session start.** A new `SessionStart` hook
  reads `.project-brain/index.compact` for the current workspace and injects it as context before
  the agent does anything, so it no longer depends on the model deciding to read it — motivated by
  a confirmed case of a small/fresh model skipping the read on a plain no-task greeting. Wired
  automatically for plugin installs (`hooks/hooks.json`); `install.sh` registers it for skill
  installs, alongside `brain-nudge`, through one shared idempotent merge routine.

Full details in the [CHANGELOG](CHANGELOG.md).

---

## What's new in 2.1

Quality-of-life release that finishes wiring the brain into Claude Code's own machinery —
backward compatible, still zero runtime dependencies for the brain itself.

- **`install.sh` auto-wires the `brain-nudge` Stop hook for skill installs.** Previously only the plugin
  path registered the save-reminder hook; a skill-only install shipped it but never ran it. The
  installer now **merges** the hook into `~/.claude/settings.json` — preserves your existing keys, is
  idempotent, and **backs up + prints a diff** before writing (uses `node`, which Claude Code already
  ships, so no `jq` needed).
- **`brain-bootstrap`** — points Claude Code's native per-project memory at the brain, **non-destructively**:
  writes a small *conditional* redirect ("if this workspace has a `.project-brain/`, it's the source of
  truth"), backs up and preserves any existing notes, and is idempotent. Cuts always-loaded
  native-memory tokens without losing anything.
- **`init`-time native→brain seeding** — `/project-brain init` now offers to seed that same redirect for
  the current workspace, so one memory system stops competing with (and drifting from) the brain.
- **`allow_conflict:` opt-out for the conflict detector (2.1.1).** An aggregator topic (an infra
  topology map, a multi-repo roadmap) legitimately lists several mutually-exclusive techs at once; it
  can now opt a group out with `allow_conflict: [relational-db]` (or `true`). Narrow by design — only
  that topic's tokens are excluded, so genuine drift in other topics still surfaces.

Full details in the [CHANGELOG](CHANGELOG.md).

---

## What's new in 2.0

- **Dual-format index** — a generated, token-cheap `index.compact` the agent reads first (≈ −52% vs
  `index.md` on a real multi-project brain), falling back to `index.md` if it's missing.
- **HOT / WARM / COLD tiers** — the eager cost stays bounded as the brain grows past 15 projects,
  or past 15 topics inside one project.
- **One-line session resume** — done / next / blocker, so you pick up exactly where you left off.
- **Hard rules** (`! never:`), **`trust: pref`**, and **delta-load** (reload only what changed).
- **Decision log** — why a path was chosen and what was rejected, so it isn't re-proposed.
- **`brain-export`** — one pasteable file for claude.ai / Gemini / ChatGPT, infra redacted by default.
- **`people/`** — first-class memory for agreements with clients, partners, and vendors.
- **`brain-check --report`**, a **conflict detector**, and **`--diff <date>`** (what changed since when).

Full details in the [CHANGELOG](CHANGELOG.md).

---

## Install

```bash
git clone https://github.com/OoneBreath/claude-code-project-brain.git
cd claude-code-project-brain
./install.sh        # copies the skill into ~/.claude/skills/  (run on each machine)
```

**Start a new Claude Code session after installing** — skills load at session start.

> `install.sh` also wires the optional `brain-inject` (auto-load), `brain-autocompact` (auto-refresh),
> and `brain-nudge` (save-reminder) hooks by **merging** them into `~/.claude/settings.json` — it
> keeps your existing settings, is idempotent, and backs up + prints a diff before writing (a
> corrupt or foreign settings.json is left
> untouched).

Then, in a session inside your workspace:

```
/project-brain  →  "init"                  set up .project-brain/ and detect your projects
/project-brain  →  "how did we solve X?"   recall through the index
```

Run `init` once **per workspace**. The skill is installed per machine (`~/.claude/skills/`), but the
memory (`.project-brain/`) lives per project — so on a server hosting several repos, point `init` at the
workspace root and it catalogs them all in one brain.

> **First run is light by design.** `init` detects your projects from `package.json` / `pyproject.toml`
> / git and writes a small index — it does **not** read your source, so it's cheap. The brain fills in
> gradually as you work. Ask it to *"scan the project"* for a one-time deep backfill that reads your
> docs/code to pre-fill topics; it summarises what's there, it doesn't invent context, so depth varies
> by how well a repo is documented.

---

## How it works

- The skill lives in `~/.claude/skills/project-brain/` (personal scope, per machine).
- `index.md` is the hand-edited **source of truth**. `brain-compact` regenerates `index.compact` from it
  — one-way, deterministic, zero tokens (no LLM call). The agent reads the compact first and falls back
  to `index.md` if it's missing or stale, so nothing ever breaks.
- One brain can catalog **many projects on one server** or a single repo. Everything is plain Markdown
  you can read, edit, and commit.
- `brain-check` (`python3 ~/.claude/skills/project-brain/brain-check`) validates the brain — broken
  pointers, malformed frontmatter, index↔topic drift, stale facts, misfiled cross-project notes, tech
  conflicts, people records. `--report` groups it readably; `--diff <date>` shows what changed;
  `--strict` adds stricter cross-project isolation; `--fix` applies the mechanical fixes (stale
  `index.compact`, session-log rotation) before validating. Zero dependencies, plain Python 3.
- `brain-find QUERY [path] [--body]` searches the brain by tag or keyword — `tags:` frontmatter,
  filename, and project/topic/person fields by default; `--body` extends to full file text.
- `brain-export` bundles the brain into one pasteable file for another assistant — infra redacted by
  default.
- An optional `brain-inject` `SessionStart` hook reads `.project-brain/index.compact` and injects it
  as context at the **start of the session**, before the agent does anything — so the compact index
  loads mechanically instead of depending on the model choosing to read it.
- An optional `brain-autocompact` `PostToolUse` hook regenerates `index.compact` right after
  `index.md` is saved, so the compact index `brain-inject` loads never sits stale mid-session.
- An optional `brain-nudge` `Stop` hook fires at the **end of a turn** (throttled, so it nudges once after
  work, not every turn) and reminds you to save when a turn changed files but the brain wasn't updated.
  It only **suggests** — it never writes to the brain.
- **It doesn't bloat over time.** Topic files are cold storage — only the index is loaded eagerly, so
  the per-session cost is bounded by the index (kept small by the compact + tiers), not by how much
  history you keep. Tidy a dead topic by *archiving* it (drop its line from the index, keep the file).

---

## Native memory, not in competition with it

`brain-bootstrap` points Claude Code's own per-project memory at the brain, non-destructively: it seeds
a small conditional redirect into native `MEMORY.md` ("if this workspace has a `.project-brain/`, that's
the source of truth") so the two don't compete and double your per-session tokens. It never deletes or
reorders your existing notes — it backs them up and prepends the redirect.

---

## Keeping it private

> **Your brain is yours — and private by default.** A real `.project-brain/` ends up holding infra
> details (DB names, ports, server paths, hostnames). Decide per project whether to commit it (travels
> with the repo, shared with your team) or keep it out of version control. This repo ships a `.gitignore`
> that ignores `.project-brain/` — and any `brain-export` output — so the skill's own repo never
> accidentally carries a real brain.

**Never store secret *values* in the brain** — variable names and paths are fine (that's architecture),
but actual passwords, tokens, and keys belong in a secrets manager or env vars, never on the map.
Removing a leaked secret is only half the job; rotating it is the other half.

---

## Works across tools (same brain, different agents)

Because a brain is just a `.project-brain/` folder of Markdown on disk, it isn't tied to one tool. The
same brain has been read and written by **Claude Code** and **Windsurf** (state persisted across a
restart), and read by a **third-party agent over SSH**. Any file-reading agent can use it.

The `project-brain` skill itself (install, init, hooks) is built for Claude Code, but the underlying
convention (the Markdown layout + the validator) travels to any file-reading agent. And `brain-export`
turns the brain into a single pasteable file for assistants with no filesystem at all (claude.ai /
Gemini / ChatGPT).

> **The honest limit — the model matters more than the tool.** This works when the agent is driven by a
> model with real agentic tool use. A small local 7B model failed: it couldn't run the read → use →
> write loop and started inventing the brain's contents. A **free local Gemma model (via Ollama)** later
> ran the full loop correctly — slower, but it read the brain, did the work, and respected the update
> hook. Capability is the bar, not the vendor: reading a brain is nearly universal, and managing one
> well is now within reach of good local models.

---

## Background

Project Brain came out of running several independent SaaS products at once — among them
[Sentinel AI](https://sentinel-ai.info) (server security & database autopilot) and
[24ad.info](https://24ad.info) (an AI-assisted classifieds platform), alongside a multi-server
fleet-intelligence backend, an anti-spam service, and a content tool. When every project carries
thousands of lines of context, the cost of the AI forgetting — or quietly mixing two projects up — is
real. This is the working memory that keeps them straight. The pattern isn't theoretical.

## Author

Built and maintained by **Slawomir Luzny** — [fixflex.co.uk/project-brain.html](https://fixflex.co.uk/project-brain.html).

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Slawomir Luzny.
