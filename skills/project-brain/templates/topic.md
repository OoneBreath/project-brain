---
project: <project-name>      # MUST match the folder under projects/ — a mismatch is a cross-project mix-up
topic: <short-topic-slug>
tags: [<tag1>, <tag2>]
status: in-progress          # verified | done | in-progress | failed | superseded  (did the WORK succeed?)
trust: ai-inferred           # human=FACT | ai-inferred | pref=preference  (absent = treat as ai-inferred)
last_done: <YYYY-MM-DD>
review_by: <YYYY-MM-DD>       # optional: re-confirm by this date, else brain-check flags it stale
version: 1
# cross_refs: [other-project] # optional: declare an intentional mention of another project, to silence the guard
# anchors: [src/cache.py#get_or_set, docker-compose.yml]  # optional: the code this topic is about (file, optional #symbol)
# root: ../acme-api           # optional: where anchors are relative to (default: the workspace holding .project-brain/)
---

**Problem:** <what was wrong / what was needed>

**Solution (v1):** <what was done and why it works>

<!-- On the next change, bump `version` above and add a line here instead of erasing:
**v1 (superseded):** <old approach and why it changed> -->
