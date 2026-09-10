"""_compact — shared logic for the dual-format index (ETAP 1).

index.md is the SINGLE SOURCE OF TRUTH (human-readable, hand-edited).
index.compact is GENERATED one-way from it (md -> compact, never the reverse) and
is what an agent reads at session start — same information, far fewer tokens.

This module is the one place the compact format is defined, imported by both
`brain-compact` (writes it) and `brain-check` (verifies it is up to date). Keeping
the renderer in one module is what stops the writer and the checker from drifting.

No third-party dependencies — Python 3 stdlib only.
"""
import os
import re

VALID_STATUS = ["verified", "done", "in-progress", "failed", "superseded"]

# md status word -> compact code. ✓ is split into ✓v/✓d because index.md uses one ✓
# glyph for both "verified" and "done"; the legend documents the suffix.
STATUS_CODE = {
    "verified": "✓v",
    "done": "✓d",
    "in-progress": "⚠",
    "failed": "✗",
    "superseded": "⨯",
}

PEOPLE_STATUS = ["active", "prospect", "paused", "closed"]   # relationship state, not work state

HEADER_LINES = [
    "# Project Brain — compact index · generated from index.md · DO NOT EDIT",
    '# legend: "<P> <name>  <stack·tags>" then one line/topic: "<topic> <status> <date> <vN>"',
    "#   status: ✓v=verified ✓d=done ⚠=in-progress ✗=failed ⨯=superseded",
    "#   pointer = projects/<name>/<topic>.md  (inline only when it differs)",
    "#   tiers:  P+ = HOT (active, full)  ·  P = WARM  ·  COLD (archived) omitted — read on demand",
    "#   when active projects > 15, WARM collapses to: P <name> <stack> · N topics, last <date>",
    "#   a project's finished topics collapse past 15: '+K more, oldest <date>' (⚠ always kept)",
    "#   ! <rule> = HARD RULE, never violate (brain-wide on top, or under a project) · ~ = session resume",
    "#   @ <name> <status> <date> = person (people/<name>.md) · status: active|prospect|paused|closed",
]

HOT_MAX = 3            # at most this many projects are HOT (always full in compact)
PROJECT_THRESHOLD = 15  # above this many ACTIVE projects, WARM collapses to keep compact small
TOPIC_THRESHOLD = 15    # above this many topics in ONE project, finished topics start collapsing
                        # (same number brain-check warns "consider consolidating" at — one
                        # canonical threshold instead of two independently-defined 15s)


def find_brain(arg):
    """Resolve a .project-brain dir from a path, a workspace containing one, or cwd."""
    cand = arg or "."
    if os.path.basename(os.path.normpath(cand)) == ".project-brain" and os.path.isdir(cand):
        return cand
    pb = os.path.join(cand, ".project-brain")
    if os.path.isdir(pb):
        return pb
    if os.path.isfile(os.path.join(cand, "index.md")):
        return cand
    return None


def read_text(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def _status_of(bracket):
    for s in VALID_STATUS:
        if s in bracket:
            return s
    return None


def parse_index(text):
    """Parse index.md into [{name, stack:[...], topics:[{slug,status,date,ver,pointer}]}]."""
    projects = []
    cur = None
    for line in text.splitlines():
        # an H1 heading (e.g. "# People") ends the project area, so its "- " lines aren't
        # swallowed as topics of the last project. "## " project headers are handled below.
        if re.match(r"^#(?!#)\s", line):
            cur = None
            continue
        m = re.match(r"^##\s+(.*)$", line)
        if m:
            head = m.group(1).strip()
            # optional trailing tier markers, e.g. "## billing (Go) {hot}" or "{archived}"
            markers = set()
            for grp in re.findall(r"\{([^}]*)\}", head):
                markers.update(t.lower() for t in re.split(r"[,\s]+", grp.strip()) if t)
            head = re.sub(r"\s*\{[^}]*\}", "", head).strip()
            mp = re.match(r"^(.*?)\s*\((.*)\)\s*$", head)
            if mp:
                name = mp.group(1).strip()
                stack = [p.strip() for p in re.split(r"·", mp.group(2)) if p.strip()]
            else:
                name, stack = head, []
            cur = {
                "name": name,
                "stack": stack,
                "topics": [],
                "resume": None,
                "never": [],
                "hot": "hot" in markers,
                "archived": "archived" in markers or name.startswith("_"),
            }
            projects.append(cur)
            continue
        if cur is None:
            continue
        ls = line.strip()
        if ls.startswith("> resume"):  # one-line session summary: done/next/blocker + date
            cur["resume"] = ls[len("> resume"):].strip()
            continue
        if re.match(r"^!\s*never\b", ls, re.I):  # hard rule scoped to this project
            cur["never"].append(_never_text(ls))
            continue
        if not ls.startswith("-"):
            continue
        body = ls[1:].strip()
        if not body or body.startswith("("):  # "(no topics yet)" placeholder
            continue
        slug = re.split(r"→", body)[0].strip()
        slug = slug.split()[0] if slug.split() else slug
        status = date = ver = pointer = None
        mb = re.search(r"\[([^\]]*)\]", body)
        if mb:
            bracket = mb.group(1)
            status = STATUS_CODE.get(_status_of(bracket))
            md = re.search(r"\d{4}-\d{2}-\d{2}", bracket)
            date = md.group(0) if md else None
            mv = re.search(r"\bv(\d+)\b", bracket)
            ver = "v" + mv.group(1) if mv else None
        mptr = re.search(r"(projects/\S+\.md)", body)
        if mptr:
            pointer = mptr.group(1)
        cur["topics"].append(
            {"slug": slug, "status": status, "date": date, "ver": ver, "pointer": pointer}
        )
    return projects


def _never_text(line):
    """Extract the rule from a `! never: <rule>` line (drop the marker, keep the rule)."""
    s = line.strip()
    if ":" in s:
        return s.split(":", 1)[1].strip()
    return re.sub(r"^!\s*never\b", "", s, flags=re.I).strip()


def parse_people(text):
    """Parse the `# People` section of index.md → [{slug, status, date, pointer}].

    People are agreements with humans (client/partner/vendor), catalogued beside projects. They live
    in the index so the compact (a pure function of index.md) can surface them; detail is in people/.
    """
    people = []
    in_people = False
    for line in text.splitlines():
        s = line.strip()
        if re.match(r"^#\s+People\s*$", s, re.I):
            in_people = True
            continue
        if s.startswith("#"):          # any other heading closes the section
            in_people = False
            continue
        if not in_people or not s.startswith("-"):
            continue
        body = s[1:].strip()
        if not body or body.startswith("("):
            continue
        slug = re.split(r"→", body)[0].strip()
        slug = slug.split()[0] if slug.split() else slug
        status = date = pointer = None
        mb = re.search(r"\[([^\]]*)\]", body)
        if mb:
            for st in PEOPLE_STATUS:
                if st in mb.group(1):
                    status = st
                    break
            md = re.search(r"\d{4}-\d{2}-\d{2}", mb.group(1))
            date = md.group(0) if md else None
        mptr = re.search(r"(people/\S+\.md)", body)
        if mptr:
            pointer = mptr.group(1)
        people.append({"slug": slug, "status": status, "date": date, "pointer": pointer})
    return people


def _brain_never(text):
    """Brain-wide hard rules: `! never:` lines that appear before the first project header."""
    rules = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("##"):
            break
        if re.match(r"^!\s*never\b", s, re.I):
            rules.append(_never_text(s))
    return rules


def _resume_date(raw):
    """The date token from a `> resume <date> · …` line, or '' if none."""
    if not raw:
        return ""
    m = re.search(r"\b\d{4}-\d{2}-\d{2}\b", raw)
    return m.group(0) if m else ""


def _recency(project):
    """A project's most recent activity = the latest topic OR resume date (ISO sorts lexically).

    The resume line counts too: a project actively being worked on (fresh `> resume`, topic
    not re-dated yet) must not lose its HOT slot to one with a stale-but-later topic date.
    """
    dates = [t["date"] for t in project["topics"] if t["date"]]
    rd = _resume_date(project["resume"])
    if rd:
        dates.append(rd)
    return max(dates) if dates else ""


def _compact_resume(raw):
    """Condense an index.md `> resume <date> · done: … · next: … · blocker: …` line for compact.

    Forward-looking only: keep next/blocker (what a resume needs); drop done unless it is the only
    field. Returns a `~ …` line or None.
    """
    if not raw:
        return None
    date = ""
    fields = {}
    for seg in (s.strip() for s in raw.split("·")):
        if re.match(r"^\d{4}-\d{2}-\d{2}$", seg):
            date = seg
        elif ":" in seg:
            k, _, v = seg.partition(":")
            if v.strip():
                fields[k.strip().lower()] = v.strip()
    parts = [f"{k}: {fields[k]}" for k in ("next", "blocker") if fields.get(k)]
    if not parts and fields.get("done"):
        parts = [f"done: {fields['done']}"]
    out = "~"
    if date:
        out += " " + date
    if parts:
        out += " " + " · ".join(parts)
    return out if out != "~" else None


def assign_tiers(projects):
    """Annotate each project with 'recency' and 'tier' (HOT | WARM | COLD). Deterministic.

    COLD  = archived ({archived} marker or a name starting with '_') — never in compact.
    HOT   = up to HOT_MAX active projects: {hot}-pinned first, then the most recently active.
    WARM  = the remaining active projects.
    """
    for p in projects:
        p["recency"] = _recency(p)
    active = [p for p in projects if not p["archived"]]
    pinned = [p for p in active if p["hot"]]
    rest = [p for p in active if not p["hot"]]
    # recency desc, name asc as a stable tiebreak — order of index.md must not change the tiers
    rest = sorted(sorted(rest, key=lambda p: p["name"]), key=lambda p: p["recency"], reverse=True)
    hot_ids = {id(p) for p in (pinned + rest)[:HOT_MAX]}
    for p in projects:
        if p["archived"]:
            p["tier"] = "COLD"
        elif id(p) in hot_ids:
            p["tier"] = "HOT"
        else:
            p["tier"] = "WARM"
    return projects


def _brain_updated(projects):
    """Newest activity anywhere in the brain (latest topic or resume date) — the delta-load signal."""
    dates = []
    for p in projects:
        if p["recency"]:
            dates.append(p["recency"])
        rd = _resume_date(p["resume"])
        if rd:
            dates.append(rd)
    return max(dates) if dates else ""


def _tier_topics(topics):
    """Split a project's topics into (shown, collapse_line) once it passes TOPIC_THRESHOLD.

    `⚠ in-progress` topics are always shown in full — never hidden, whatever the count. The
    remaining budget (THRESHOLD - open count, floored at 0) goes to the most-recently-dated
    finished topics (✓v/✓d/✗/⨯; undated ones sort last); the rest collapse into one summary
    line. Below the threshold, every topic is shown and collapse_line is None — unchanged
    behavior for the vast majority of brains. Shown topics keep their original index.md order.
    """
    if len(topics) <= TOPIC_THRESHOLD:
        return topics, None
    open_t = [t for t in topics if t["status"] == "⚠"]
    closed_t = [t for t in topics if t["status"] != "⚠"]
    budget = max(TOPIC_THRESHOLD - len(open_t), 0)
    closed_sorted = sorted(closed_t, key=lambda t: t["date"] or "", reverse=True)
    keep_ids = {id(t) for t in open_t} | {id(t) for t in closed_sorted[:budget]}
    shown = [t for t in topics if id(t) in keep_ids]
    collapsed = [t for t in closed_sorted[budget:]]
    if not collapsed:
        return shown, None
    dated = sorted(t["date"] for t in collapsed if t["date"])
    tail = f", oldest {dated[0]}" if dated else ""
    return shown, f"  +{len(collapsed)} more{tail}"


def render_compact(text, gen_date=None):
    """Render index.md text into the compact representation (deterministic, tier-aware)."""
    projects = parse_index(text)
    assign_tiers(projects)
    active = [p for p in projects if p["tier"] != "COLD"]
    collapse_warm = len(active) > PROJECT_THRESHOLD

    people = parse_people(text)

    out = list(HEADER_LINES)
    meta = "@src index.md"
    if gen_date:
        meta += f"  @gen {gen_date}"
    updated_dates = [d for d in [_brain_updated(projects)] if d]
    updated_dates += [pe["date"] for pe in people if pe["date"]]
    if updated_dates:
        meta += f"  @updated {max(updated_dates)}"
    out.append(meta)
    out.append("")
    # brain-wide hard rules first — they bind every project, so they lead the compact
    for rule in _brain_never(text):
        out.append(f"! never: {rule}")
    for p in projects:
        if p["tier"] == "COLD":
            continue  # archived: read on demand, never weigh on the eager budget
        head = ("P+ " if p["tier"] == "HOT" else "P ") + p["name"]
        if p["stack"]:
            head += "  " + "·".join(p["stack"])
        if p["tier"] == "WARM" and collapse_warm:
            n = len(p["topics"])
            tail = f"  · {n} topic{'' if n == 1 else 's'}"
            if p["recency"]:
                tail += f", last {p['recency']}"
            out.append(head + tail)
            for rule in p["never"]:  # hard rules surface even when the project is collapsed
                out.append(f"  ! never: {rule}")
            continue
        out.append(head)
        for rule in p["never"]:
            out.append(f"  ! never: {rule}")
        if p["tier"] == "HOT":  # surface "where we left off" only for the always-loaded HOT projects
            rs = _compact_resume(p["resume"])
            if rs:
                out.append("  " + rs)
        if not p["topics"]:
            out.append("  -")
            continue
        shown, collapse_line = _tier_topics(p["topics"])
        for t in shown:
            parts = [t["slug"]]
            for key in ("status", "date", "ver"):
                if t[key]:
                    parts.append(t[key])
            default = f"projects/{p['name']}/{t['slug']}.md"
            if t["pointer"] and t["pointer"] != default:
                parts.append(t["pointer"])
            out.append("  " + " ".join(parts))
        if collapse_line:
            out.append(collapse_line)

    # people — agreements with humans, catalogued beside projects (detail in people/<slug>.md)
    if people:
        out.append("@people")
        for person in people:
            parts = [person["slug"]]
            for key in ("status", "date"):
                if person[key]:
                    parts.append(person[key])
            default = f"people/{person['slug']}.md"
            if person["pointer"] and person["pointer"] != default:
                parts.append(person["pointer"])
            out.append("@ " + " ".join(parts))
    return "\n".join(out) + "\n"


def data_lines(compact_text):
    """The meaningful lines of a compact file: comments (#) and the volatile meta line stripped.

    Used to compare two compact renderings for *content* equality while ignoring the
    legend and the volatile @gen timestamp — so the consistency check is deterministic.
    Only the "@src …" meta line is metadata; "@people" / "@ <slug> …" lines are DATA —
    stripping every "@" line made people changes invisible to the drift check (fixed in 2.1.2).
    """
    return [
        ln for ln in compact_text.splitlines()
        if ln and not ln.startswith("#") and not ln.startswith("@src")
    ]
