# The compact index, tiers, delta-load, archiving

> Part of the Project Brain skill — SKILL.md points here. Moved out of SKILL.md in 2.5 to keep
> the always-loaded part small; the wording is unchanged.

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
#   ✓v? / ✓d? = code under the topic's anchors changed after it was verified: re-verify before trusting
@src index.md  @gen 2026-06-13  @updated 2026-05-20

! never: deploy outside the EU (client is GDPR-bound)
P+ acme-api  Node·tRPC·Drizzle·MySQL·Redis
  ! never: store PII in Redis
  ~ 2026-05-20 next: client silent refresh · blocker: denylist store
  cache ✓v 2026-05-12 v2
  auth ⚠ 2026-05-20
```

The `! never: …` lines are **hard rules** (see *Hard rules* in `format.md`); `~ …` is the **session resume**;
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
