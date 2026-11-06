#!/usr/bin/env python3
"""CIU 6 P4e-2 grounding census — every spelling the slice touches, counted per population.

Run from the worktree root:
    python3 docs/tracking/tracks/CIU/CIU_6/research/P4e-2/census-p4e2.py [MAIN_CHECKOUT]

Populations (git-tracked at HEAD, so .claude/worktrees/ copies never count):
    prod   *.prologos under racket/prologos/{lib,examples}; also counted with ; comments stripped (prod-nc)
    tests  *.rkt under racket/prologos/tests (the spellings inside test strings = the pins)
    src    *.rkt under racket/prologos, excluding tests/ tools/ benchmarks/ (comments + message text)
    wip    the OWNER'S uncommitted lib/examples/foray.prologos in MAIN_CHECKOUT's working copy, read-only,
           comments stripped (only when MAIN_CHECKOUT is given)

Every pattern must match each of its must-match strings and reject each must-reject string, or the run aborts.
"""
import re, subprocess, sys
from pathlib import Path

P = "rack" "et/prologos"
BASE_END = r"[A-Za-z0-9_?!'})\]]"          # a token that can END a subject (identifier, closer)
PATS = [
    ("glued-colon-star",  BASE_END + r":\*",
     ["values:*", "x.0:*", "[f x]:*", "xs{a}:*_", "v:*-_"], ["{:* 1}", "x: *", "x :*", "x:k*"]),
    ("spaced-colon-star", BASE_END + r": +\*",
     ["x: *", "x:  *_"], ["x:*", "x :*", "{:* 1}"]),
    ("space-before-colon-star", BASE_END + r" +:\*",
     ["x :*", "f x :*_"], ["x:*", "{:* 1}", "x: *"]),
    ("dot-star-bare",     r"\.\*($|[^A-Za-z0-9_*])",
     ["values.*", "values.* x", "x.*:name", "x.*)"], ["values.*name", "values.**", "a.*b"]),
    ("dot-star-star",     r"\.\*\*",
     ["values.**", "#p(a.**)", ":a.{b c}.**"], ["values.*", "values:**"]),
    ("colon-star-star",   r":\*\*",
     ["values:**", "x:**:k"], ["values.**", "x:*:*"]),
    ("colon-dot-star",    r":\.\*",
     ["values:.*"], ["values.*", "values:*"]),
    ("brace-colon-star",  r"\{[^{}]*[A-Za-z0-9_?!')\]]:\*",   # inside a block: the base cannot be its own `}`
     ["x{a:*}", "tw{teams:*_}"], ["x{a}:*", "x{a:k*}", "{:* 1}"]),
]

def power():
    bad = []
    for name, ere, mm, mr in PATS:
        rx = re.compile(ere)
        bad += [f"{name}: must match {s!r}" for s in mm if not rx.search(s)]
        bad += [f"{name}: must reject {s!r}" for s in mr if rx.search(s)]
    return bad

def ls(*specs):
    out = subprocess.run(["git", "ls-files", *specs], capture_output=True, text=True, check=True).stdout
    return [l for l in out.splitlines() if l]

def strip_prologos_comment(line):
    # `;` starts a comment at line start or after whitespace (string-literal `;` is rare; counted both ways)
    return re.sub(r"(^|\s);.*$", "", line)

def lines(path, strip=False):
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return []
    ls_ = text.splitlines()
    return [strip_prologos_comment(l) for l in ls_] if strip else ls_

def classify_test_hits(tests):
    """Every test line any pattern hits, once, classified — so 'zero expression pins' is a count with a class
    for everything else, not a reading by eye (the first by-eye count double-counted lines two patterns hit)."""
    hits = set()
    for name, ere, _, _ in PATS:
        rx = re.compile(ere)
        for f in tests:
            for i, l in enumerate(lines(f)):
                if rx.search(l):
                    hits.add((f, i + 1, l))
    cls = {}
    for f, n, l in sorted(hits):
        s = l.strip()
        if re.search(r"#rx|#px", s): k = "racket-regex"
        elif "#p(" in s: k = "path-literal (#p, PF's form)"
        elif "selection " in s or ":requires" in s or (f.endswith("test-selection-paths.rkt") and ".*" in s):
            k = "selection-declaration (JD-7)"
        elif s.startswith(";"): k = "comment"
        elif s.startswith("(test-case"): k = "test-name"
        else: k = "OTHER (an expression-position pin)"
        cls.setdefault(k, []).append((f, n, s))
    print(f"\n== test-file hit lines, distinct: {len(hits)}")
    for k in sorted(cls):
        print(f"  {k:36} {len(cls[k])}")
    for f, n, s in cls.get("OTHER (an expression-position pin)", []):
        print(f"  OTHER {f}:{n}: {s[:120]}")

def main():
    bad = power()
    if bad:
        print("ABORT — a census pattern failed its power check:\n  " + "\n  ".join(bad))
        sys.exit(1)
    print(f"power checks: {len(PATS)} patterns passed every must-match / must-reject string")
    prod = ls(f"{P}/lib/*.prologos", f"{P}/examples/*.prologos")
    tests = ls(f"{P}/tests/*.rkt")
    src = [f for f in ls(f"{P}/*.rkt") if not re.match(rf"{P}/(tests|tools|benchmarks)/", f)]
    wip = None
    if len(sys.argv) > 1:
        w = Path(sys.argv[1]) / P / "lib/examples/foray.prologos"
        wip = str(w) if w.exists() else None
    print(f"populations: prod {len(prod)} files · tests {len(tests)} files · src {len(src)} files · "
          f"wip {'foray.prologos (main working copy)' if wip else '—'}\n")
    hdr = f"{'pattern':26} {'prod':>6} {'prod-nc':>8} {'tests':>6} {'src':>6} {'wip-nc':>7}"
    print(hdr); print("-" * len(hdr))
    detail = []
    for name, ere, _, _ in PATS:
        rx = re.compile(ere)
        a = sum(1 for f in prod for l in lines(f) if rx.search(l))
        bhits = [(f, i + 1, l) for f in prod for i, l in enumerate(lines(f, True)) if rx.search(l)]
        c = sum(1 for f in tests for l in lines(f) if rx.search(l))
        d = sum(1 for f in src for l in lines(f) if rx.search(l))
        e = "—"
        whits = []
        if wip:
            whits = [(i + 1, l) for i, l in enumerate(lines(wip, True)) if rx.search(l)]
            e = str(len(whits))
        print(f"{name:26} {a:>6} {len(bhits):>8} {c:>6} {d:>6} {e:>7}")
        detail.append((name, rx, bhits, whits))
    print("\n== non-comment prod hits (file:line: text)")
    for name, rx, bhits, _ in detail:
        for f, n, l in bhits:
            print(f"[{name}] {f}:{n}: {l.strip()[:150]}")
    print("\n== test files with hits (file: lines)")
    for name, rx, _, _ in detail:
        for f in tests:
            k = sum(1 for l in lines(f) if rx.search(l))
            if k:
                print(f"[{name}] {f}: {k}")
    classify_test_hits(tests)
    if wip:
        print("\n== owner WIP foray.prologos (main's working copy, read-only), non-comment hits")
        for name, rx, _, whits in detail:
            for n, l in whits:
                print(f"[{name}] foray:{n}: {l.strip()[:150]}")

main()
