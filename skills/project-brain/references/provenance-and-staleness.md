# Provenance, staleness and the cross-project guard

> Part of the Project Brain skill — SKILL.md points here. Moved out of SKILL.md in 2.5 to keep
> the always-loaded part small; the wording is unchanged.

## Provenance & staleness — memory that knows what it doesn't know

`status` answers *"did the work succeed?"*. Two more (optional) fields answer *"can I trust this
note, and is it still current?"* — the thing flat notes never tell you:

- **`trust:`** — what kind of claim this is and who vouches for it. Three values:
  - `human` = **FACT**, a person confirmed it (gospel).
  - `ai-inferred` (or absent) = the AI wrote it without confirmation; useful, but verify before relying.
  - `pref` = **PREFERENCE** — the user's stated choice ("always OVH", "tabs not spaces"). Honor it as
    the decision; it isn't a verifiable fact, so don't re-litigate it, but don't treat it as proof
    either. (A hard, inviolable rule is a `! never:` line, not a `pref` — see *Hard rules* in `format.md`.)
  This keeps a model's own guesses from hardening into "facts" just because they're written down.
- **`review_by:`** — an optional expiry date. Past it (or, with no `review_by`, once `last_done` is
  older than ~180 days), `brain-check` flags a *finished* topic as stale: re-confirm before
  trusting. Memory with an expiry date, instead of treating last year's note as still true.

When you recall a topic, factor both in (see Mode: recall in SKILL.md). When you save, set `trust` honestly and
add `review_by` to anything that ages — credentials, versions, "current" prod state.

## Don't mix projects up — the cross-project guard

The multi-project case is where memory rots into wrong answers: a fact from project A applied to
project B. Two guards:
- **Always on:** a topic's `project:` **must equal the folder** it lives under (`projects/<project>/`).
  `brain-check` warns on any mismatch — that's almost always a misfiled, contaminating note.
- **Opt-in (`brain-check --strict`):** flags a topic that name-drops another known project in its body
  without declaring it in `cross_refs:`. Off by default on purpose — in tightly-coupled setups
  projects reference each other legitimately, so this is noise unless you want strict isolation.
