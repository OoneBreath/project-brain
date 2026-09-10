---
name: project-brain
version: 2.4.0
author: Slawomir Luzny <info@fixflex.co.uk> (https://fixflex.co.uk)
description: >-
  Persistent, navigable project memory for Claude Code that survives across
  sessions and months. Use when the user wants to set up project memory ("set up
  project brain", "init brain"), recall how something was solved before ("how did
  we solve the cache", "what did we do with auth"), check whether a task was
  already done before redoing it ("did we already swap the logo?"), find something by
  tag or keyword across the whole brain ("where did we write anything about Stripe?"),
  or save what was accomplished after finishing work. Especially for multi-project / multi-server
  setups where Claude must remember each project's stack, decisions and pitfalls
  without re-reading huge docs every session.
---

# Project Brain

Persistent project memory you (Claude) navigate through a **small index** instead of
re-reading large docs every session. Only the index is ever loaded eagerly; detail
lives in topic files read **on demand**. The index is your token budget — keep it small.

## Where the brain lives

A `.project-brain/` directory at the workspace (or repo) root:

```
.project-brain/
  index.md                  # THE MAP. Small. Read this FIRST. Projects -> topics -> status + pointer
  projects/
    <project>/
      <topic>.md            # Detail: problem, solution, status, version, tags
  people/
    <slug>.md               # Agreements with humans (client/partner/vendor): who, context, status
```

One brain can catalog **many projects** (a server hosting several repos) or just **one**
(a single repo). Multi-project is the default shape — each project is a section in `index.md`.

## How to behave every session

If the brain exists, **read its index first** — it is small by design and tells you what each
project is, its stack, and what has already been done. Prefer `.project-brain/index.compact`
(a token-cheap, generated view); if it is missing or older than `index.md`, read `index.md`
instead — they carry the same information, so the fallback never loses anything. Drill into a
topic file only when you actually need that detail.

When this skill is invoked, choose the mode that matches the request:

### Mode: init — create the brain
Use when no `.project-brain/` exists, or the user says "set up / init project brain".

**Default is a LIGHT init — keep it cheap. Do NOT read the codebase.**
1. Create `.project-brain/` and `.project-brain/projects/`.
2. Detect projects from cheap signals only: top-level dirs, git repos, `package.json`,
   `pyproject.toml`, `go.mod`, `Cargo.toml`, `composer.json`. Infer name + stack from those
   files — do not read source to do this. **Skip non-project directories** —
   `node_modules`, `venv`, `.venv`, `target`, `dist`, `build`, `.cache`, `snap`,
   `android-sdk`, `flutter`, `.git` — and anything that is clearly a toolchain or data dump,
   not a codebase. When unsure, ask rather than adding noise.
3. Write `index.md` from `templates/index.md`, one section per project with the stack filled in
   and the topic list empty. Topics get filled as real work happens (via `save`).
4. Append a tiny pointer to the workspace `CLAUDE.md` (create it if missing) using
   `templates/CLAUDE-snippet.md` — this is what makes future sessions read the map first.
   Keep the pointer to a few lines; never duplicate the map into it.
5. **Defer this workspace's native memory to the brain (optional, non-destructive).** Claude Code's
   own per-project memory (`MEMORY.md`) competes with the brain and roughly doubles the per-session
   token cost. With the user's ok, seed a small **conditional** redirect into THIS workspace's native
   `MEMORY.md` so it points at the brain instead of duplicating facts. Same contract as the
   `brain-bootstrap` tool:
   - Idempotency marker `<!-- project-brain-redirect v1 -->`.
   - Native memory empty/absent → write just the redirect stub.
   - Marker already present → leave it untouched.
   - It holds the user's own notes → **back them up** (`.bak-<timestamp>`) and **prepend** the
     redirect; never delete or reorder their text.
   Keep the stub generic ("if this workspace has a `.project-brain/`, it is the source of truth") so
   it carries no absolute path and stays correct on any machine. To migrate native memory across
   *other* existing projects on the machine, point the user at the on-demand `brain-bootstrap` script
   — it only touches projects you ask it to, never silently.
6. Tell the user what you created, and that the brain fills in as you work.

**Optional DEEP backfill — only when the user explicitly asks** ("scan the project / populate the
brain from the codebase"). This pre-fills topic files by reading the project, so it spends real
tokens once.

To keep it cheap and accurate, **read the project's own distilled docs first** — `README`,
`CHANGELOG`, `docs/`, ADRs, design notes — and fall back to reading source only for the gaps. The
result reflects what the project actually documents: a well-documented repo backfills richer than a
bare one. It summarises what's there; it does not invent context. Set the user's expectations
accordingly — this is not magic, and two different projects will produce different depth.

Before starting: warn the user it is a one-time upfront cost that pays back on every later session,
and offer to scope it to **one project at a time** rather than the whole workspace.

### Mode: recall — "how did we do X" / "did we already do X"
1. Read **only** `index.md`.
2. Find the matching project + topic line; note its `[status · date · vN]`.
3. Read **only** that one topic file for detail. Do not read sibling topic files.
4. If the user is asking to redo something already marked `✓ done` or `✓ verified`,
   **say so and ask**: repeat it, or make a new change? Never silently redo finished work.
5. **Weigh how much to trust it** before acting on it (see *Provenance & staleness*):
   - `trust: human` = a person vouched for this — treat as reliable. Absent or `trust: ai-inferred`
     = the AI wrote it without confirmation — useful, but verify before you rely on it.
   - Past its `review_by`, or `last_done` long ago = possibly stale. Say "this was confirmed back
     in <date> — worth re-checking?" rather than presenting it as current fact.
6. For cross-cutting questions ("everything Redis", "all auth work") or when you don't know
   which project/topic to look under, run `brain-find QUERY [workspace]` (see *Search*) instead of
   reading files whole — it's a tag/keyword search across the brain.
7. **Before proposing a choice** (a library, a host, an architecture), read the project's
   `_decisions.md` and the brain-wide `decisions.md` (see *Decision log*) so you don't re-propose
   an option that was already weighed and rejected.

### Mode: save — after completing work
1. Identify project + topic (one topic = one meaningful unit of work, not every tiny edit).
2. Create/update `projects/<project>/<topic>.md` from `templates/topic.md`:
   - If new: fill frontmatter + body.
   - If it existed: **bump `version`**, and keep the previous approach as a short
     `vN (superseded): ...` line in the body. Do not erase history.
   - Set `status` to the real outcome (see legend).
   - Set `trust` honestly: `human` only when the user actually confirmed it (or you verified it
     end-to-end); otherwise `ai-inferred`. Never label your own guess `human`.
   - Make sure `project:` equals the folder name — a mismatch is how projects get mixed up.
   - Optionally set `review_by:` for facts that age (credentials, versions, "current" anything).
3. Update the matching line in `index.md`: status-with-outcome + date + version + pointer.
   Keep it to **one line**. All detail goes in the topic file, never in the index.
4. If the project section doesn't exist in `index.md` yet, add it.
5. **Session summary (where we left off).** When the work wraps a session, refresh the project's
   one-line resume (see *Session summaries*): move the project's current `> resume …` line (if any)
   to the **top** of `projects/<project>/_session.md`, then write a fresh `> resume <today> · done: …
   · next: … · blocker: …` under the project header in `index.md`. Keep `_session.md` to **5 active
   lines** — older lines rotate to the top of `projects/<project>/_session.cold.md` (cold storage).
6. **If this save settled a real choice** (picked a host, a library, an architecture over alternatives),
   append one newest-first line to `projects/<project>/_decisions.md` (or `.project-brain/decisions.md`
   if brain-wide): `YYYY-MM: <chosen> > <rejected> — <why>` (see *Decision log*). Only for choices
   someone might otherwise re-open — not every micro-pick.
7. Regenerate the compact index so the fast path stays in sync — it is deterministic and free
   (no LLM, no tokens): `python3 ~/.claude/skills/project-brain/brain-compact [workspace]`.
   Always edit `index.md` (the source of truth); never hand-edit `index.compact`.
8. Run `brain-check` (see Validate) so the index line and the topic file can't silently drift.

### Validate — keep the two sources of truth in sync
Run the bundled validator any time, and especially after a `save`:
```
python3 ~/.claude/skills/project-brain/brain-check [workspace]
```
It checks that every pointer resolves, frontmatter is well-formed with a valid status, and the
status in `index.md` matches the status in the topic file. It also flags (as advisory warnings)
an invalid `trust:`, a topic past its staleness horizon, a `project:` that doesn't match its
folder, an `index.compact` that is missing or out of date with `index.md`, and **conflicting facts**
— a single project that names two of the same mutually-exclusive tech (a relational DB, or a host)
across its index stack and topic files, which is usually a stale fact one place forgot to update.
An **aggregator** topic that legitimately lists several (an infra topology map, a multi-repo
roadmap) opts a group out with frontmatter `allow_conflict: [relational-db]` — narrow: it excludes
only that topic's tokens, so genuine drift in other topics still surfaces.
Add `--report` for a grouped, readable rundown (conflicts, staleness, orphans, …) instead of a flat
list — same checks, easier to scan. Add `--diff YYYY-MM-DD` to instead list **what changed since a
date** — new/updated topics, session lines, resume lines, decisions, and people — read straight from
the brain's own dates (no git needed), handy for "what did we touch since last week?". Add `--strict`
to additionally flag topics that name-drop another project without a
`cross_refs:` (off by default — noisy on coupled brains). Exit code 1 = real errors to fix; warnings
(staleness, provenance, cross-project, compact-drift, thin **and over-long** topics, session-log
overflow, orphans, over-fragmentation) are advisory.

Add `--fix` to apply the two *mechanical* fixes before validating — regenerate a missing/stale
`index.compact`, and rotate any project's `_session.md` past 5 active lines into `_session.cold.md`
(oldest entries move out, newest-first order preserved across both files). Everything else stays a
human judgment call (orphans, staleness, conflicts — `--fix` never guesses at those). It then runs
the normal validation so you immediately see what, if anything, still needs you. Idempotent — a
second `--fix` reports "nothing to fix" once the brain is current.

## Search — brain-find
Look something up by tag or keyword instead of walking the index by hand:
```
python3 ~/.claude/skills/project-brain/brain-find QUERY [workspace] [--body]
```
Matches (case-insensitive substring) against a topic or person's `tags:` frontmatter, its filename,
and its `project:`/`topic:`/`person:` fields — cheap and low-noise, no file bodies read. Add `--body`
to also search full file text when a tag guess doesn't land. Groups results by project, showing each
match's status, version, and tags — good for "where did we write anything about Stripe?" without
guessing which topic file it landed in.

## index.md format

```markdown
# Project Brain — index

> Read this first. Drill into projects/<name>/<topic>.md only when you need detail.

! never: deploy outside the EU (client is GDPR-bound)

## acme-api  (Node · tRPC · Drizzle · MySQL · Redis)
! never: store PII in Redis
> resume 2026-05-20 · done: refresh endpoint · next: client silent refresh · blocker: denylist store
- cache → Redis invalidation on ad update   [✓ verified 2026-05-12 · v2] → projects/acme-api/cache.md
- auth  → tRPC session handling             [⚠ in-progress 2026-04-30]   → projects/acme-api/auth.md

## acme-web  (React · TypeScript · Vite)
- (no topics yet)
```

The optional `> resume …` blockquote under a project header is the **one-line session summary** —
where you left off (done / next / blocker + date). See *Session summaries* below.

`! never: …` lines are **hard rules**: brain-wide if placed before the first `##`, or project-scoped
under a header. They surface in the compact for every active project — see *Hard rules* below.

**Optional tier markers** on a project header (see *Tiers* below): `## billing  (Go) {hot}` pins it
HOT; `## legacy-api  (PHP) {archived}` makes it COLD. No marker = automatic tiering by recency.

**Status legend** (carry the OUTCOME, not just "done"):
- `✓ verified` — done and confirmed working
- `✓ done` — done, not independently confirmed
- `⚠ in-progress` — started, not finished
- `✗ failed` — tried, did not work (kept so we don't repeat it)
- `⨯ superseded` — replaced by a newer approach (see the topic's latest version)

## The compact index (index.compact)

`index.md` is the **single source of truth** — human-readable, hand-edited. Alongside it lives
`index.compact`, a **generated** view that says the same thing in far fewer tokens (~60% smaller on
a real multi-project brain). It is what you read at session start; the markdown is the fallback.

- **One-way only:** `index.md` → `index.compact`, never the reverse. The compact file is compiled
  output — never hand-edit it. Edit `index.md`, then regenerate.
- **Regeneration is deterministic and free:** `brain-compact` is plain Python (stdlib), no LLM call,
  zero tokens. Run it after any `save`, or wire it into a hook.
- **Reading:** prefer `index.compact`; if it is missing or older than `index.md`, read `index.md`
  — same information, so the fallback never loses anything (older brains with no compact still work).
- **Format:** a self-describing legend block on top, then `P <name>  <stack·tags>` per project and
  one line per topic `<topic> <status> <date> <vN>`. Status codes: `✓v` verified · `✓d` done ·
  `⚠` in-progress · `✗` failed · `⨯` superseded. The pointer `projects/<name>/<topic>.md` is implied
  and shown inline only when it differs.

```
# Project Brain — compact index · generated from index.md · DO NOT EDIT
# legend: "<P> <name>  <stack·tags>" then one line/topic: "<topic> <status> <date> <vN>"
#   status: ✓v=verified ✓d=done ⚠=in-progress ✗=failed ⨯=superseded
#   pointer = projects/<name>/<topic>.md  (inline only when it differs)
#   tiers:  P+ = HOT (active, full)  ·  P = WARM  ·  COLD (archived) omitted — read on demand
#   when active projects > 15, WARM collapses to: P <name> <stack> · N topics, last <date>
#   ! <rule> = HARD RULE, never violate (brain-wide on top, or under a project) · ~ = session resume
@src index.md  @gen 2026-06-13  @updated 2026-05-20

! never: deploy outside the EU (client is GDPR-bound)
P+ acme-api  Node·tRPC·Drizzle·MySQL·Redis
  ! never: store PII in Redis
  ~ 2026-05-20 next: client silent refresh · blocker: denylist store
  cache ✓v 2026-05-12 v2
  auth ⚠ 2026-05-20
```

The `! never: …` lines are **hard rules** (see *Hard rules*); `~ …` is the **session resume**;
`@updated` is the newest activity in the brain (see *Delta-load*). `brain-check` warns (advisory)
when `index.compact` is missing or out of date with `index.md`.

## Tiers — HOT / WARM / COLD (keeping the compact small at scale)

A brain with many projects would make even the compact index big. Tiers bound that **automatically**
— you don't manage them by hand (unlike the manual archiving below, which only drops a line):

- **HOT** (`P+`, max 3) — the active projects, always rendered **in full**. Chosen automatically as
  the 3 most recently active projects (latest topic date). Pin one with a `{hot}` marker in its
  `index.md` header to force it HOT regardless of dates (useful for a project you just picked up).
- **WARM** (`P`) — every other active project. Rendered in full while the brain is small; once there
  are **more than 15 active projects**, WARM collapses to a one-liner (`P name stack · N topics, last
  <date>`) so the compact stays light. The full detail is still in `index.md` and the topic files —
  read it on demand.
- **COLD** — archived projects (`{archived}` marker, or a name starting with `_`). **Never** in the
  compact; read on demand only. This is the tier form of archiving.

Tiering only shapes the **generated** compact — `index.md` always holds every project in full, so
nothing is hidden from a deliberate read. Selection is deterministic (recency + pins, not the clock),
so regeneration is stable. `brain-check` warns if more than 3 projects are pinned `{hot}` (only the
first 3 are honored; the rest fall to WARM).

**Topic-level collapsing (within one project).** The tiers above bound the compact as a brain
grows *more projects*; this bounds it as a single project grows *more topics* — the same idea, one
level down. `⚠ in-progress` topics are **always** shown in full, however many there are — they're
the still-open work, the most likely thing to matter right now. Past **15 topics**, a project's
finished ones (`✓v` `✓d` `✗` `⨯`) start collapsing: the most-recently-dated ones stay expanded up
to that cap, and the rest fold into one line — `+K more, oldest <date>` — instead of dumping every
topic unconditionally. Same rule as above: this only shapes the compact, `index.md` still holds
every topic in full, and it's deterministic (a given `index.md` always collapses the same way).

## Session summaries — "where did we leave off?"

Topic files capture *what a thing is*; a session summary captures *what just happened and what's
next*. After a working session, each touched project carries a single **one-line resume**:

```
> resume 2026-05-20 · done: refresh endpoint · next: client silent refresh · blocker: denylist store
```

- **Current resume lives in `index.md`** (under the project header) — so it is the source of truth and
  shows up when you read the map. At session start, the compact surfaces it for **HOT** projects as a
  `~ <date> next: … · blocker: …` line (forward-looking: `done` is dropped to stay lean), so you
  immediately see where to pick up — no need to open anything.
- **History lives in `projects/<project>/_session.md`** — previous resume lines, newest first. Kept to
  **5 active lines**; older lines rotate to `projects/<project>/_session.cold.md` (cold storage, never
  loaded eagerly). On a new save, the old resume drops from `index.md` into `_session.md`, and the
  fresh one takes its place in `index.md` — no duplication.
- Files starting with `_` (`_session.md`, `*.cold.md`) are **not topics**: `brain-check` skips them and
  warns only if the active `_session.md` grows past 5 lines (rotate the oldest down).

This makes resuming a project instant and keeps the rolling log from bloating the index — the same
index-stays-lean principle as topic files.

## People — agreements with humans (beside projects)

Not all memory is about code. Who the client is, what a partner agreed to, the vendor you're locked
into — that context matters and gets forgotten too. People live in `people/<slug>.md`, one file per
person, catalogued in their own `# People` section of `index.md`:

```
# People
- jane-doe → client · Acme Corp · billing + annual contract  [active 2026-06-10]  → people/jane-doe.md
- bob-dns  → vendor · DNS + mail relay                        [paused 2026-03-01]  → people/bob-dns.md
```

- **Same rules as topics.** A person file uses the same frontmatter spirit — `trust:` (human/ai-inferred/
  pref), optional `review_by:` for staleness — and `brain-check` validates it the same way (frontmatter
  present, person matches filename, orphans, staleness). Create one from `templates/person.md`.
- **Status is the relationship, not the work:** `active | prospect | paused | closed` (not
  verified/done). Required frontmatter: `person` (= filename), `status`, `version`.
- **In the compact** they appear as a `@people` block — `@ <slug> <status> <date>` — so the agent knows
  who's who at session start; the agreements (dated, newest first) are detail in the file, read on demand.
- **Recall/save** them like projects: when something is agreed with a person, add a dated line to their
  file and refresh the `[status date]` in the `# People` index, then regenerate the compact.

## Hard rules — `! never:` (constraints you must not break)

Some memory isn't a note you weigh — it's a **constraint**. "This client is GDPR-bound, never deploy
outside the EU." "Never store PII in Redis." These are `! never:` lines:

- **Brain-wide** rules go before the first `## ` in `index.md` (they bind every project); **project**
  rules go under a project header.
- They render in the compact for **every active project — even a collapsed WARM one** — because a
  broken hard rule is the worst possible failure, so they must always be in context, not on-demand.
- **Treat them as absolute.** Before proposing or doing anything for a project, check its hard rules
  (and the brain-wide ones) and never suggest an action that violates one. If a request conflicts with
  a `! never:`, say so and stop — don't quietly work around it.

They are deliberately few and short. If you find yourself writing many, most are probably ordinary
notes (`trust: pref`) rather than inviolable constraints — keep `! never:` for the real lines.

## Decision log — why, not just what (so rejected options stay rejected)

A topic's version history records *what changed*. The decision log records *why a path was chosen and
what was rejected*, so the rejected alternative is never quietly proposed again three months later.

- **Where it lives:** a dedicated, append-style file — `projects/<project>/_decisions.md` for a
  project decision, or `.project-brain/decisions.md` for a brain-wide one. These are **not** topics
  (the per-project file is `_`-prefixed, so `brain-check` skips it; the brain-wide one sits beside the
  index). They are **read on demand at planning time**, never loaded eagerly — which keeps the compact
  lean and the generator a pure function of `index.md`.
- **Format** — one line per decision, newest first:

  ```
  2026-06: OVH > Hetzner, DigitalOcean — client is EU-based and contractually EU-only
  2026-05: Drizzle > Prisma — lighter, owns the SQL, no engine binary
  ```

  `YYYY-MM: <chosen> > <rejected[, …]> — <why>`. The value is the **why** and the **rejected** side.
- **When you plan, read it first.** Before you propose or pick an approach, a library, a host, an
  architecture for a project, **read that project's `_decisions.md` and the brain-wide
  `decisions.md`**. If the option you're about to suggest is on the rejected side of a past decision,
  don't propose it as if it were new — either honor the decision, or, if circumstances changed,
  surface it explicitly: *"we chose OVH over Hetzner in 2026-06 for EU residency — has that changed?"*
- **When a decision is made, log it.** On a save that settled a real choice, append one line. This is
  not for every micro-pick — only choices someone might otherwise re-open. (A choice that must *never*
  be reopened is a `! never:` hard rule instead.)

## Delta-load — only reload what changed

You read the compact at the **start of every session** (it is cheap). You do **not** need to re-read
every topic file every time. The compact carries an `@updated <date>` header (the newest activity
anywhere in the brain), and every project shows its own latest date (topic dates, the `~` resume,
or a collapsed WARM project's `last <date>`). Use them as a delta signal:

- Your reference point is the **most recent `> resume` date you yourself wrote** last time here.
- **Drill into a project only if its date is newer than that** — that's what actually changed since you
  were last active. For everything unchanged, the compact line is enough; don't reopen topic files.
- If nothing in the brain is newer than your last resume, just keep the **HOT** projects in context
  and move on — there is no delta to load.

This keeps a long-lived brain cheap to resume: the per-session cost tracks *what changed*, not the
total size of the history.

## Export — paste the brain into another assistant

A brain lives on disk; claude.ai / Gemini / ChatGPT can't read your files. `brain-export` bundles it
into **one self-contained Markdown file** to paste into such a chat — the bridge for an agent with no
filesystem.

```
python3 ~/.claude/skills/project-brain/brain-export [workspace] \
    [--project NAME ...] [--max-tokens N] [--include-infra] [--stdout]
```

- It writes `<brain>/context-export.md` (or `--stdout`): the condensed **Map** (the compact index, with
  its legend, so it's self-explaining) plus full detail for the **HOT** projects and any you add with
  `--project` (even WARM/COLD ones).
- **Safe by default.** Infra that shouldn't land in an external chat — IPs, ports, absolute paths,
  hostnames, and secret-looking values (`PASSWORD=`, `API_KEY:`, tokens, AWS keys) — is **redacted** to
  `[ip]`/`[port]`/`[path]`/`[host]`/`[redacted]`. The brain holds real server data; the export goes to
  a third party — so you opt **in** to leaking, never out. `--include-infra` keeps it (only when you
  trust the destination). Redaction is best-effort heuristics — skim the result before pasting.
- `--max-tokens N` caps the size, keeping the most important parts first: **Map > HOT detail > named
  projects**, truncating the tail with a note. Token figures are approximate (~4 chars/token; stdlib
  has no real tokenizer).

## Provenance & staleness — memory that knows what it doesn't know

`status` answers *"did the work succeed?"*. Two more (optional) fields answer *"can I trust this
note, and is it still current?"* — the thing flat notes never tell you:

- **`trust:`** — what kind of claim this is and who vouches for it. Three values:
  - `human` = **FACT**, a person confirmed it (gospel).
  - `ai-inferred` (or absent) = the AI wrote it without confirmation; useful, but verify before relying.
  - `pref` = **PREFERENCE** — the user's stated choice ("always OVH", "tabs not spaces"). Honor it as
    the decision; it isn't a verifiable fact, so don't re-litigate it, but don't treat it as proof
    either. (A hard, inviolable rule is a `! never:` line, not a `pref` — see *Hard rules*.)
  This keeps a model's own guesses from hardening into "facts" just because they're written down.
- **`review_by:`** — an optional expiry date. Past it (or, with no `review_by`, once `last_done` is
  older than ~180 days), `brain-check` flags a *finished* topic as stale: re-confirm before
  trusting. Memory with an expiry date, instead of treating last year's note as still true.

When you recall a topic, factor both in (see Mode: recall). When you save, set `trust` honestly and
add `review_by` to anything that ages — credentials, versions, "current" prod state.

## Don't mix projects up — the cross-project guard

The multi-project case is where memory rots into wrong answers: a fact from project A applied to
project B. Two guards:
- **Always on:** a topic's `project:` **must equal the folder** it lives under (`projects/<project>/`).
  `brain-check` warns on any mismatch — that's almost always a misfiled, contaminating note.
- **Opt-in (`brain-check --strict`):** flags a topic that name-drops another known project in its body
  without declaring it in `cross_refs:`. Off by default on purpose — in tightly-coupled setups
  projects reference each other legitimately, so this is noise unless you want strict isolation.

## topic file frontmatter

```markdown
---
project: acme-api         # MUST match the folder under projects/
topic: cache
tags: [redis, invalidation, performance]
status: verified          # verified | done | in-progress | failed | superseded  (did the work succeed?)
trust: human              # human=FACT | ai-inferred | pref=preference  (absent = ai-inferred)
last_done: 2026-05-12
review_by: 2026-11-12      # optional: re-confirm by this date, else flagged stale
# allow_conflict: [relational-db]   # optional: aggregator topic may list several DBs/hosts — don't flag
version: 2
---

**Problem:** stale Redis entries after an ad is updated.

**Solution (v2):** invalidate by key `ad:{id}` on write instead of a blanket flush.

**v1 (superseded):** 60s TTL — too slow, users saw stale data.
```

## Rules (the whole point — do not skip)

- **The index is the budget.** It is the only thing read eagerly. Keep each line to one line;
  push all detail into topic files read on demand. A bloated index defeats the purpose.
- **Status = outcome.** Distinguish "done and works" from "tried and failed" from "in progress".
- **Never silently redo finished work.** Surface what exists and ask.
- **Version, don't overwrite.** Keep the trail of what was tried and why it changed.
- **Tag topics** so cross-project recall works via grep on `tags:`.
- **Don't over-fragment.** One file per meaningful topic, not per keystroke. Dozens of files
  good; hundreds of micro-files bad.
- **Reference code by stable anchors, not line numbers.** Point to `file.ts` + a function or
  symbol name, not `file.ts:273` — line numbers rot on the first refactor. This is narrative
  memory, not a live index, so write references that survive editing.
- **Be honest about provenance.** Mark `trust: human` only when a person actually confirmed it.
  Your own inference is `ai-inferred` — writing it down does not make it true.
- **Keep the map clean — suggest, don't auto-save.** The brain is valuable because a human chose
  what is worth remembering. Never bulk-dump a session into it. When work is done, *propose* what to
  save and let the user decide. (The bundled `brain-nudge` Stop hook only reminds — it cannot write.)
- **Keep CLAUDE.md pointer tiny.** It points to the map; it is not a copy of the map.

## Optional: the bundled hooks (brain-inject, brain-autocompact, brain-nudge)

Three small hooks make the brain load and stay current mechanically, instead of depending on the
agent choosing to do any of it.

**`brain-inject`** (`SessionStart`) reads `.project-brain/index.compact` for the current workspace
and returns it as context at the **start of the session**, before the agent does anything — so the
compact index is always loaded, even by a model that would otherwise skip reading it on a plain
greeting. No brain in the project → silent no-op.

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

## Keeping the brain lean — archiving

Topic files are **cold storage**: only `index.md` is read eagerly, so a topic file costs nothing
until something opens it. That means the brain's per-session weight is bounded by the **index**,
not by the total amount of history you keep — a brain with hundreds of topic files is still cheap
as long as the index stays a list of one-liners. This is the whole reason it doesn't rot like a
flat `notes.md` that grows heavier every session.

So you almost never need to delete anything. When a topic is genuinely dead (obsolete, replaced,
no longer a project), **archive instead of delete**:

1. Remove its **one line** from `index.md` — this is what actually frees eager-token budget.
2. **Keep the topic file** (optionally move it to `projects/<project>/_archive/`). History survives
   and is still findable by grep if it's ever needed again.

Never auto-delete a user's notes — durable memory is the point. Archiving is a manual, occasional
tidy: the index is the only thing that needs to stay lean, and dropping a line from it is enough.
Use `last_done` dates and the `⨯ superseded` status to spot what's stale.

---

*Project Brain — built and maintained by **Slawomir Luzny** ([fixflex.co.uk](https://fixflex.co.uk)).
MIT licensed. Contributions and issues: https://github.com/OoneBreath/claude-code-project-brain*
