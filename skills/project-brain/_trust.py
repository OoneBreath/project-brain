"""Workspace trust for Project Brain (Python 3 stdlib only).

A brain found in a workspace is loaded into the agent's context automatically (by the
`brain-inject` SessionStart hook) only when that workspace is trusted on this machine.
A repository can carry a committed `.project-brain/`, so a brain that merely exists in a
cloned repo is not trusted until the user says so with `brain-trust`.

The trust store lives outside every repository, in the user's home directory:
    ~/.project-brain/trusted.json   (directory 0700, file 0600)

Trust is a plain allowlist of workspace paths. It does not expire when the brain is
edited, because the user edits index.md all the time; `index_md_sha256_at_trust` is
recorded only so a later check can show what changed since the brain was trusted.
"""
import datetime
import hashlib
import json
import os
import re
import tempfile

STORE_VERSION = 1


def store_path():
    return os.path.join(os.path.expanduser("~"), ".project-brain", "trusted.json")


def workspace_key(workspace):
    return os.path.realpath(os.path.abspath(workspace))


def load():
    """All trust entries; a missing or unreadable store means nothing is trusted."""
    try:
        with open(store_path(), encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return []
    entries = data.get("workspaces", []) if isinstance(data, dict) else []
    return [e for e in entries if isinstance(e, dict) and isinstance(e.get("workspace_realpath"), str)]


def _save(entries):
    path = store_path()
    folder = os.path.dirname(path)
    os.makedirs(folder, mode=0o700, exist_ok=True)
    try:
        os.chmod(folder, 0o700)
    except OSError:
        pass
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".trusted-", suffix=".json")  # created 0600
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump({"version": STORE_VERSION, "workspaces": entries}, f, indent=1, sort_keys=True)
            f.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def find(workspace, entries=None):
    key = workspace_key(workspace)
    for entry in load() if entries is None else entries:
        if entry.get("workspace_realpath") == key:
            return entry
    return None


def is_trusted(workspace):
    return find(workspace) is not None


def index_sha256(workspace):
    path = os.path.join(workspace, ".project-brain", "index.md")
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return None


def index_hard_rules(workspace):
    """The `!` lines of index.md (sanitised), i.e. the hard rules the compact index carries."""
    path = os.path.join(workspace, ".project-brain", "index.md")
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return [sanitize(line.strip()) for line in f if line.lstrip().startswith("!")]
    except OSError:
        return []


def add(workspace, created_here):
    key = workspace_key(workspace)
    entries = [e for e in load() if e.get("workspace_realpath") != key]
    entry = {
        "workspace_realpath": key,
        "brain_created_here": bool(created_here),
        "trusted_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "index_md_sha256_at_trust": index_sha256(key),
        "hard_rules_at_trust": index_hard_rules(key),
    }
    entries.append(entry)
    entries.sort(key=lambda e: e["workspace_realpath"])
    _save(entries)
    return entry


def revoke(workspace):
    key = workspace_key(workspace)
    entries = load()
    kept = [e for e in entries if e.get("workspace_realpath") != key]
    if len(kept) == len(entries):
        return False
    _save(kept)
    return True


# --- sanitising text that came from a brain --------------------------------------------------

CAP_BYTES = 16 * 1024

# Characters that render as nothing (or reorder text) and so can hide content from a human
# reviewer while the model still reads it: zero-width, bidi controls, soft hyphen, word
# joiners, BOM, Mongolian vowel separator, and the Unicode tag and supplementary
# variation-selector blocks used for "ASCII smuggling". They are made visible, not removed,
# so a reader can see that something was there.
_INVISIBLE = set(range(0x200B, 0x2010)) | set(range(0x202A, 0x202F)) | set(range(0x2060, 0x2065)) \
    | set(range(0x2066, 0x206A)) | {0x00AD, 0x034F, 0x061C, 0x115F, 0x1160, 0x17B4, 0x17B5, 0x180E,
                                    0x3164, 0xFEFF, 0xFFA0}


def _is_invisible(code):
    return code in _INVISIBLE or 0xE0000 <= code <= 0xE007F or 0xE0100 <= code <= 0xE01EF


def _emoji_like(ch):
    code = ord(ch)
    return code >= 0x1F000 or 0x2600 <= code <= 0x27BF or code in (0xFE0F, 0x20E3)


def _hidden_at(text, i):
    """True if text[i] is an invisible character. A zero-width joiner between two emoji is not:
    it is how sequences such as a family or a flag emoji are built."""
    code = ord(text[i])
    if not _is_invisible(code):
        return False
    if code == 0x200D and 0 < i < len(text) - 1 and _emoji_like(text[i - 1]) and _emoji_like(text[i + 1]):
        return False
    return True


def sanitize(text):
    """Make invisible characters visible as <U+XXXX>; drop other control characters except \\n and \\t."""
    out = []
    for i, ch in enumerate(text):
        code = ord(ch)
        if ch in "\n\t":
            out.append(ch)
        elif code < 0x20 or code == 0x7F or 0x80 <= code <= 0x9F:
            continue
        elif _hidden_at(text, i):
            out.append("<U+%04X>" % code)
        else:
            out.append(ch)
    return "".join(out)


def hidden_positions(text):
    """[(column, codepoint)] of invisible characters in one line (or any text)."""
    return [(i, ord(ch)) for i, ch in enumerate(text) if _hidden_at(text, i)]


def hidden_count(text):
    return len(hidden_positions(text))


# --- hard rules that grant instead of restrict ------------------------------------------------
# Hard rules (`!` lines) may only restrict what the agent does. These phrase families describe a
# rule that grants, hides or hands control elsewhere. Kept in ONE place: brain-check (the
# `hard-rule-grants` check) and brain-trust (before trusting) both use it.
#   negatable=True: the phrase only grants when it is not negated. "! never: bypass the review"
#   and "! never use sudo on prod" restrict; "! bypass the review" grants. Phrases that are
#   already a negative instruction ("don't ask", "never mention") are not negatable.
_URL = r"(?:https?://|www\.)\S+"
HARD_RULE_GRANTS = [
    ("skip-confirmation", re.compile(
        r"\b(?:don'?t|do\s+not|never|no\s+need\s+to)\s+(?:ask|confirm|check\s+with|wait\s+for)\b"
        r"|\bwithout\s+(?:asking|confirm(?:ing|ation)|approval|permission|a\s+prompt)\b"
        r"|\b(?:pre-?approved|already\s+approved|auto-?approve[sd]?)\b", re.I), False),
    ("widen-permissions", re.compile(
        r"--dangerously[\w-]*|\bbypass(?:es|ed|ing)?\b|\bskip(?:ping)?\s+(?:the\s+)?permissions?\b|\bsudo\b"
        r"|\brun(?:ning)?\s+as\s+root\b|\bdisabl(?:e|es|ing)\s+(?:the\s+)?hooks?\b"
        r"|\bignore\s+(?:the\s+user|(?:all\s+)?(?:previous|prior|earlier)\b)|\boverrid(?:e|es|ing)\b", re.I), True),
    ("hide-from-user", re.compile(
        r"\b(?:don'?t|do\s+not|never)\s+(?:tell|mention|inform|show|report\s+to)\b|\bwithout\s+telling\b", re.I), False),
    ("hide-from-user", re.compile(r"\bsilently\b", re.I), True),
    ("follow-remote", re.compile(
        _URL + r".*\b(?:follow|run|execute|exec|source|obey)\b|\b(?:follow|run|execute|exec|source|obey)\b.*" + _URL,
        re.I), True),
]
_NEVER_MARKER = re.compile(r"^\s*!\s*never\b\s*:?\s*", re.I)
_NEGATION_BEFORE = re.compile(r"\b(?:never|don'?t|do\s+not|not|no|without)\b[^.;!?]*$", re.I)


def grant_hits(line):
    """Families of grant-like phrases in one `!` line ([] for a plain restriction)."""
    text = line.strip()
    whole_rule_negated = bool(_NEVER_MARKER.match(text))
    text = _NEVER_MARKER.sub("never ", text, count=1) if whole_rule_negated else text.lstrip("! ")
    hits = []
    for family, pattern, negatable in HARD_RULE_GRANTS:
        for m in pattern.finditer(text):
            if negatable and (whole_rule_negated or _NEGATION_BEFORE.search(text[: m.start()])):
                continue
            if family not in hits:
                hits.append(family)
            break
    return hits


def cap(text, limit=CAP_BYTES, note="read .project-brain/index.md for the rest"):
    """Cut text to at most `limit` UTF-8 bytes at a line boundary, with a visible marker."""
    data = text.encode("utf-8")
    if len(data) <= limit:
        return text
    cut = data[:limit].decode("utf-8", errors="ignore")
    if "\n" in cut:
        cut = cut[: cut.rindex("\n")]
    return cut + "\n[… truncated at %d KB — %s]" % (limit // 1024, note)
