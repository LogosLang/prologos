#!/usr/bin/env python3
"""W2-4 Q1: classify forced-ATMS vs DFS differences per solve line.
  extra    : ATMS returns an answer DFS does not (an answer DFS rejects)   <- the PD-1 class
  missing  : DFS returns an answer ATMS does not (incompleteness)
  unknown  : the ATMS answer differs only by holding `unknown` / unresolved placeholders
  other    : not a solve line (errors, defs)"""
import sys, re, glob, os
sys.path.insert(0, os.path.dirname(__file__))
from compare import compare, answers, norm
D = sys.argv[1]
tot = {}
rows = []
for a in sorted(glob.glob(os.path.join(D, '*.atms.out'))):
    t = os.path.basename(a)[:-len('.atms.out')]
    b = os.path.join(D, t + '.dfs.out')
    c = {'extra': 0, 'missing': 0, 'unknown': 0, 'other': 0}
    ex = []
    for i, k, x, y in compare(a, b):
        if k != 'DIFF': continue
        ax, ay = (answers(x) if x else None), (answers(y) if y else None)
        if not ax or not ay:
            c['other'] += 1; ex.append((i, 'other', x, y)); continue
        A, B = ax[0], ay[0]
        extra = [e for e in A if e not in B]
        missing = [e for e in B if e not in A]
        if extra and all('unknown' in e or re.search(r'_G\b', e) for e in extra):
            c['unknown'] += 1; ex.append((i, 'unknown', x, y)); continue
        if extra: c['extra'] += 1; ex.append((i, 'extra', x, y))
        elif missing: c['missing'] += 1; ex.append((i, 'missing', x, y))
    rows.append((t, c, ex))
    for k in c: tot[k] = tot.get(k, 0) + c[k]
for t, c, ex in rows:
    print(f"{t:40s} extra {c['extra']:3d}  missing {c['missing']:3d}  unknown {c['unknown']:3d}  other {c['other']:3d}")
print("TOTAL", tot)
if len(sys.argv) > 2:
    for t, c, ex in rows:
        for i, k, x, y in ex:
            if k == sys.argv[2]:
                print(f"--- {t} [{i}] {k}\n  ATMS: {(x or '')[:300]}\n  DFS : {(y or '')[:300]}")
