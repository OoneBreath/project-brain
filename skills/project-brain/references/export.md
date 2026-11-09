# Export — paste the brain into another assistant

> Part of the Project Brain skill — SKILL.md points here. Moved out of SKILL.md in 2.5 to keep
> the always-loaded part small; the wording is unchanged.

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
