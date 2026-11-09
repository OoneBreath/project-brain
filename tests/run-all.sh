#!/usr/bin/env bash
# Run every check: the syntax of each script under skills/ and install.sh (bash -n, or a Python
# compile that writes no files), then every tests/test-*.sh. Prints PASS/FAIL per item and exits
# non-zero if anything failed. CI runs exactly this.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failed=$((failed + 1)); }

for f in "$ROOT"/skills/*/* "$ROOT/install.sh"; do
  [ -f "$f" ] || continue
  rel="${f#"$ROOT"/}"
  first="$(head -n 1 "$f" 2>/dev/null || true)"
  case "$f" in *.py) first="#!python" ;; esac
  case "$first" in
    '#!'*python*)
      if python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$f"; then
        pass "syntax $rel"; else fail "syntax $rel"; fi ;;
    '#!'*bash*|'#!'*/sh*)
      if bash -n "$f"; then pass "syntax $rel"; else fail "syntax $rel"; fi ;;
  esac
done

for t in "$ROOT"/tests/test-*.sh; do
  rel="${t#"$ROOT"/}"
  log="$(mktemp)"
  if bash "$t" >"$log" 2>&1; then
    pass "$rel"
  else
    fail "$rel"
    tail -n 30 "$log" | sed 's/^/    /'
  fi
  rm -f "$log"
done

echo
if [ "$failed" -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; fi
[ "$failed" -eq 0 ]
