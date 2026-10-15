#!/usr/bin/env python3
"""CIU 6 1b-vi-C — attribute every caret-cont / star-cont reader to its INNERMOST
enclosing define (indentation-aware, per syntax.rkt's ADDING A KIND recipe).
Run from racket/prologos. Comment lines are skipped; the definitions themselves
are reported separately. Positive controls are asserted at the end."""
import re, sys, glob
FILES = sorted(glob.glob("*.rkt") + glob.glob("lsp/*.rkt"))
PATS = {
  "step-cont":  re.compile(r"\(select-step-cont[\s)]"),
  "dissolve":   re.compile(r"'dissolve(?![-\w])"),
  "rename":     re.compile(r"\(select-cont-rename[\s)]"),
  "collapse?":  re.compile(r"\(select-cont-collapse\?[\s)]"),
  "out-name":   re.compile(r"\(select-step-output-name[\s)]"),
  "star-cont":  re.compile(r"\(select-star-cont[\s)]"),
  "rename-pair":re.compile(r"\(eq\? \(car c\) 'rename\)|'\(rename collapse-rename\)|\(cons 'rename"),
}
DEF = re.compile(r"^(\s*)\(define \(([^\s)]+)")

def extents(lines):
    """(start, end, name) per `(define (f …)`, END found by paren matching that
    skips strings, `;` comments and `#\\x` char literals. ⚠ v1 attributed by
    INDENTATION and never popped a nested define when its parent's body resumed —
    caught by the positive control (typing's dissolve arm charged to walk-to-leaf)."""
    text = "".join(lines)
    starts = []  # char offset of each line
    off = 0
    for l in lines:
        starts.append(off); off += len(l)
    import bisect
    def line_of(i): return bisect.bisect_right(starts, i)  # 1-based
    out = []
    for n, l in enumerate(lines, 1):
        m = DEF.match(l)
        if not m: continue
        i = starts[n - 1] + len(m.group(1)); depth = 0; j = i
        while j < len(text):
            c = text[j]
            if c == ";":
                j = text.find("\n", j); j = len(text) if j < 0 else j
            elif c == '"':
                j += 1
                while j < len(text) and text[j] != '"':
                    j += 2 if text[j] == "\\" else 1
            elif c == "#" and text[j:j+2] == "#\\":
                j += 2
            elif c in "([": depth += 1
            elif c in ")]":
                depth -= 1
                if depth == 0: break
            j += 1
        out.append((n, line_of(j), m.group(2)))
    return out

rows = []
for f in FILES:
    lines = open(f, encoding="utf-8").readlines()
    ext = extents(lines)
    for n, line in enumerate(lines, 1):
        m = DEF.match(line)
        inner = [e for e in ext if e[0] <= n <= e[1]]
        stack = [(0, min(inner, key=lambda e: e[1] - e[0])[2])] if inner else []
        s = line.lstrip()
        if s.startswith(";"): continue
        code = line.split(";", 1)[0] if '"' not in line else line
        for k, p in PATS.items():
            if p.search(code):
                if m and p.pattern.startswith(r"\(" + re.escape(m.group(2))): continue
                fn = stack[-1][1] if stack else "<toplevel>"
                rows.append((k, f, n, fn))
by = {}
for k, f, n, fn in rows:
    by.setdefault((f, fn), []).append(f"{k}@{n}")
for (f, fn), hits in sorted(by.items()):
    print(f"{f:22} {fn:42} {' '.join(hits)}")
print(f"-- {len(rows)} hits in {len(by)} functions")
# positive controls: sites known to exist (read by hand this session)
must = [("typing-core.rkt", "select-branch-entries", "dissolve"),
        ("reduction.rkt", "branch-entries", "dissolve"),
        ("syntax.rkt", "select-step-output-name", "dissolve"),
        ("pretty-print.rkt", "cont->string", "dissolve"),
        ("typing-core.rkt", "star-join-type", "star-cont")]
for f, fn, k in must:
    ok = any(r[1] == f and r[3] == fn and r[0] == k for r in rows)
    print(("PASS" if ok else "FAIL") + f" control {f}:{fn}:{k}")
    if not ok: sys.exit(1)
