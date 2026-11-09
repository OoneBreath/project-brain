# Session summaries and the decision log

> Part of the Project Brain skill — SKILL.md points here. Moved out of SKILL.md in 2.5 to keep
> the always-loaded part small; the wording is unchanged.

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
