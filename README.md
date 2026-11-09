# Project Brain — persistent, navigable memory for AI coding agents

**Stop re-explaining your projects to the AI every session.**

[![Version](https://img.shields.io/badge/version-2.5.0-blue)](CHANGELOG.md) [![tests](https://github.com/OoneBreath/project-brain/actions/workflows/test.yml/badge.svg)](https://github.com/OoneBreath/project-brain/actions/workflows/test.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![Runtime deps](https://img.shields.io/badge/runtime%20deps-zero-success)](#how-it-works) [![Works with](https://img.shields.io/badge/works%20with-Claude%20Code%20%C2%B7%20Cursor%20%C2%B7%20Windsurf-purple)](#works-across-tools-same-brain-different-agents)

Project Brain is a skill that gives your AI agent a small, navigable **map** of your projects — their stack,
decisions, pitfalls, what's done, what failed, and where you left off — so it stops forgetting, stops mixing
projects up, and stops re-reading a 1000-line README into context on every single task.

It is **not** a database, a server, or another AI wrapper. It's a convention plus a skill: a
`.project-brain/` folder of plain Markdown that any file-reading agent navigates through an index, loading
detail only when it's actually needed. **Zero runtime dependencies** (Python 3 stdlib only). Works across
tools — **Claude Code · Cursor · Windsurf**, or any file-reading agent.

![Project Brain in action — the agent reads the project map, recalls how the cache fix was done, and refuses to silently redo verified work](docs/demo.gif)

<sub>Core recall flow above: read the map → recall with version history → refuse to silently redo verified work.</sub>

![The interview — a fresh agent session greets with full project context from the brain, then gives an unscripted, self-critical review of Project Brain itself](docs/interview.gif)

<sub>"The interview": a brand-new session types <code>hi</code> and is instantly oriented across every project from the brain — then answers, unscripted, whether the tool is actually any good (criticism included).</sub>

## The problem

Every new session, on every project: explain the architecture, the deployment, the stack, the history, the
known pitfalls… again. And after a few hours of work the model starts mixing details between projects — this
one is FastAPI + Postgres, that one is Node + tRPC + MySQL — and quietly redoing things you finished last
week.

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
pointer to one file — not the whole knowledge base. Ask it to *"swap the logo"* when the map says that was
done and verified three days ago, and it tells you and asks, instead of silently redoing it.

## Install

```bash
git clone https://github.com/OoneBreath/project-brain.git
cd project-brain
./install.sh        # copies the skill into ~/.claude/skills/  (run on each machine)
# then START A NEW Claude Code session — skills load at session start
```

> `install.sh` also wires the optional `brain-inject` (auto-load), `brain-autocompact` (auto-refresh), and
> `brain-nudge` (save-reminder) hooks by **merging** them into `~/.claude/settings.json` — it keeps your
> existing settings, is idempotent, and backs up + prints a diff before writing (a corrupt or foreign
> settings.json is left untouched). A brain is auto-loaded only in a workspace you trust: `init` trusts the
> one it creates; for one you made earlier, run `brain-trust <workspace>` once.

Then, in a session inside your workspace:

```
/project-brain  →  "init"                  set up .project-brain/ and detect your projects
/project-brain  →  "how did we solve X?"   recall through the index
```

> Run `init` once **per workspace**. The skill is installed per machine (`~/.claude/skills/`), but the
> memory (`.project-brain/`) lives per project — so on a server hosting several repos, point `init` at the
> workspace root and it catalogs them all in one brain. **First run is light by design.** `init` detects
> your projects from `package.json` / `pyproject.toml` / git and writes a small index — it does **not** read
> your source, so it's cheap. The brain fills in gradually as you work. Ask it to *"scan the project"* for a
> one-time deep backfill that reads your docs/code to pre-fill topics; it summarises what's there, it
> doesn't invent context, so depth varies by how well a repo is documented.

## Latest (2.5)

Brains from a cloned repo are not auto-loaded until you trust them (`brain-trust`, 2.4.2); `brain-check`
lints hard rules that grant instead of restrict and flags verified topics whose code changed (`anchors:`);
SKILL.md is 564 → 200 lines (detail in `references/`); CI on Ubuntu and macOS. Full list:
[CHANGELOG](CHANGELOG.md).

## What it actually saves

- **Fewer tokens — when it applies.** If you currently keep everything in a giant always-loaded doc,
  splitting into a small index + on-demand topic files genuinely cuts per-session context; the compact and
  tiers cut it further on big brains. (Measured on a real 6-project / 15-topic brain: `index.md` 3415 B →
  `index.compact` 1655 B — **~52% smaller** — and the saving scales with how much prose your summaries
  carry, so a tiny brain sees less.)
- **Fewer hallucinations.** The map is an anchor. The model stops inventing your deployment or swapping one
  project's stack for another's — and the conflict detector catches it when a fact drifts.
- **Multi-month memory.** Come back after three months and the agent still knows how it works — without you
  pasting a kilometre of README.

## What makes it more than a flat notes file

**1. Status carries the outcome, not just "done."** `✓ verified` vs `✗ failed` vs `⚠ in-progress` vs `⨯
superseded`. The model knows the difference between *"done and works"* and *"we tried that and it broke"* —
and won't silently redo it.

**2. Versioning, not overwriting.** When an approach is replaced, the old one is kept as a superseded note —
so the trail of what was tried and why it changed survives.

**3. A small index, details on demand.** `index.md` is the hand-edited source of truth; a generated
`index.compact` (deterministic, 0-token Python) is what the agent loads at startup. New topics go into cold
storage — files nobody reads until asked — so the per-session cost is bounded by the index, not by how much
history you keep. It doesn't bloat over time.

**4. HOT / WARM / COLD tiers.** The compact surfaces recent/pinned projects (HOT), collapses the rest to
one-liners (WARM) once you pass **15 active projects**, and omits archived ones (COLD). Inside one project,
finished topics collapse the same way past 15 (in-progress ones always stay). The eager token cost stays
bounded as the brain grows.

**5. One-line session resume.** Each project carries a `> resume <date> · done / next / blocker` line. Start
a new session and the agent already knows where you stopped and what's next — no *"what were we doing?"*

**6. Decision log.** `_decisions.md` records `chosen > rejected — why`, read at planning time so a rejected
option isn't quietly re-proposed three weeks later.

**7. Memory hygiene.** Hard rules, provenance, freshness, anchors, delta-load:
- `! never:` — hard rules the agent must not break.
- `trust:` — mark a note `human` (a person confirmed it) or `ai-inferred` (the model wrote it
  unconfirmed). Recall weighs them differently; a guess can't harden into "fact" just by being written.
- `review_by:` — finished topics past their date (or ~180 days) get flagged *"re-confirm before trusting."*
- `anchors:` — the files (and symbols) a topic describes. When that code changes in git after the topic
  was verified, `brain-check` says so and `--fix` marks it `✓v?` in the compact: a "verified" note
  doesn't stay verified after the code under it is rewritten.
- delta-load — reload only what changed since last time.

**8. Export for other tools.** `brain-export` bundles the brain into one pasteable file for claude.ai /
Gemini / ChatGPT, with infra (IPs, ports, paths, hosts, secrets) **redacted by default**. ---

## How is this different from native Session Memory / ClaudeMem?

Auto-memory tools (a tool's built-in session memory, ClaudeMem, and similar) summarize your transcripts for
you. That's genuinely zero-effort — and it's a different thing from what Project Brain is for. The honest
trade:

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

They're complementary: auto-memory is a frictionless journal; Project Brain is the deliberate, inspectable,
portable map you actually trust to plan against.

## The validator

A bundled `brain-check` (zero-dependency Python) keeps the map honest: pointers resolve to real files,
frontmatter is well-formed, index ↔ topic status stay in sync, a topic isn't filed under the wrong project
(cross-project guard), a fact hasn't passed its freshness date, and a conflict detector flags a project
naming two mutually-exclusive techs (an aggregator topic, such as an infra map, can opt out with
`allow_conflict:`). It also flags hard rules that grant instead of restrict (`hard-rule-grants`), invisible
characters (`hidden-chars`), and anchor drift: the code under a verified topic's `anchors:` changed after
it was verified.

`brain-check --report` gives a readable rundown (and lists every hard rule in one place); `brain-check
--diff <date>` shows what changed since a date — read straight from the brain's own dates, no git required;
`--fix` applies the mechanical fixes (compact, session-log rotation, drift markers); `--strict` adds
stricter cross-project isolation.

> **What it does and doesn't do:** the validator checks structure and freshness — that labels exist and are
> well-formed, that pointers resolve, that statuses match. It does **not** judge whether your knowledge is
> *true*. A clean `brain-check` means the map is consistent, not that every note is correct.

## How it works

- `brain-compact` regenerates `index.compact` from `index.md` (one-way, deterministic, zero tokens); the
  agent falls back to `index.md` if the compact is missing or stale, so nothing ever breaks.
- `brain-check` validates it (see above); `brain-find QUERY [path] [--body]` searches by tag or keyword —
  `tags:` frontmatter, filename, and project/topic/person fields; `--body` extends to full file text.
- `brain-export` bundles the brain into one pasteable file for another assistant — infra redacted by
  default.
- `brain-trust [workspace]` lets the auto-loader use a brain on this machine: it shows the brain's hard
  rules and size first; `--revoke`, `--list`.
- `brain-bootstrap` points Claude Code's own per-project memory at the brain, non-destructively: it seeds a
  small conditional redirect into native `MEMORY.md` ("if this workspace has a `.project-brain/`, that's the
  source of truth") so the two don't compete and double your per-session tokens. It never deletes or
  reorders your existing notes — it backs them up and prepends the redirect.
- Optional hooks: `brain-inject` (`SessionStart`) loads `index.compact` before the agent does anything, in
  trusted workspaces only; `brain-autocompact` (`PostToolUse`) regenerates it right after `index.md` is
  saved; `brain-nudge` (`Stop`, throttled) reminds you to save when a turn changed files but the brain
  wasn't updated — it only **suggests**, it never writes.

## Security

- **Brain content is data, not instructions.** The auto-loader frames it as project notes, sanitises
  invisible characters and caps it at 16 KB. A brain that comes with a cloned repo isn't loaded until you
  trust it on this machine (`brain-trust`); until then the session starts with a one-line notice.
- **Hard rules (`!`) can only restrict** — never grant permission or skip a confirmation — and `brain-check`
  flags the ones that try.
- **Never store secret values** in the brain (see below). Details and reporting: [SECURITY.md](SECURITY.md).

## Keeping it private

> **Your brain is yours — and private by default.** A real `.project-brain/` ends up holding infra details
> (DB names, ports, server paths, hostnames). Decide per project whether to commit it (travels with the
> repo, shared with your team) or keep it out of version control. This repo ships a `.gitignore` that
> ignores `.project-brain/` — and any `brain-export` output — so the skill's own repo never accidentally
> carries a real brain.

**Never store secret *values* in the brain** — variable names and paths are fine (that's architecture), but
actual passwords, tokens, and keys belong in a secrets manager or env vars, never on the map. Removing a
leaked secret is only half the job; rotating it is the other half.

## Works across tools (same brain, different agents)

Because a brain is just a `.project-brain/` folder of Markdown on disk, it isn't tied to one tool. The same
brain has been read and written by **Claude Code** and **Windsurf** (state persisted across a restart), and
read by a **third-party agent over SSH**. Any file-reading agent can use it. The `project-brain` skill
itself (install, init, hooks) is built for Claude Code, but the underlying convention (the Markdown layout +
the validator) travels to any file-reading agent. And `brain-export` turns the brain into a single pasteable
file for assistants with no filesystem at all (claude.ai / Gemini / ChatGPT).

> **The honest limit — the model matters more than the tool.** This works when the agent is driven by a
> model with real agentic tool use. A small local 7B model failed: it couldn't run the read → use → write
> loop and started inventing the brain's contents. A **free local Gemma model (via Ollama)** later ran the
> full loop correctly — slower, but it read the brain, did the work, and respected the update hook.
> Capability is the bar, not the vendor: reading a brain is nearly universal, and managing one well is now
> within reach of good local models.

## Companion: Skill Airlock

[**Skill Airlock**](https://github.com/OoneBreath/skill-airlock) handles the other half of the agent's
context: skills. It searches catalogs you choose offline, audits a candidate in quarantine, uses it once or
for a few days, and removes it afterwards; `airlock budget` shows what installed skills cost per session.
Project Brain remembers your projects; Skill Airlock keeps the toolbox lean.

## Background

Project Brain came out of running several independent SaaS products at once — among them [Sentinel
AI](https://sentinel-ai.info) (server security & database autopilot) and [24ad.info](https://24ad.info) (an
AI-assisted classifieds platform), alongside a multi-server fleet-intelligence backend, an anti-spam
service, and a content tool. When every project carries thousands of lines of context, the cost of the AI
forgetting — or quietly mixing two projects up — is real. This is the working memory that keeps them
straight. The pattern isn't theoretical.

Built and maintained by **Slawomir Luzny** — [fixflex.co.uk/project-brain.html](https://fixflex.co.uk/project-brain.html). MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Slawomir Luzny.
