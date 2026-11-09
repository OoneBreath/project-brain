# Init — native-memory redirect and deep backfill

> Part of the Project Brain skill — SKILL.md points here. Moved out of SKILL.md in 2.5 to keep
> the always-loaded part small; the wording is unchanged.

## Native memory redirect (init step 5)

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
