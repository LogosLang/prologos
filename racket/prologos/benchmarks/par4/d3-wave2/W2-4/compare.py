#!/usr/bin/env python3
"""W2-4: index-aligned answer-set comparison of two w24-run.rkt outputs.
Answers of a solve line `@[{..} {..}] : T` are compared as MULTISETS after normalising gensym'd
names (`c_g2485` -> `c_G`). Reports per line: same | order-only | DIFF."""
import re, sys
def lines(p):
    out = {}
    for l in open(p, encoding='utf-8', errors='replace'):
        m = re.match(r'^(\d+): (.*)$', l.rstrip('\n'))
        if m: out[int(m.group(1))] = m.group(2)
    return out
G = re.compile(r'\b([A-Za-z][A-Za-z0-9_-]*?)_g\d+\b')
def norm(s): return G.sub(r'\1_G', s)
def answers(s):
    m = re.match(r'^@\[(.*)\] : (.*)$', s)
    if not m: return None
    body = m.group(1).strip()
    if body == '': return ([], m.group(2))
    items = re.findall(r'\{[^{}]*\}', body)
    return (sorted(norm(i) for i in items), m.group(2))
def compare(a, b):
    A, B = lines(a), lines(b)
    res = []
    for i in sorted(set(A) | set(B)):
        x, y = A.get(i), B.get(i)
        if x == y: res.append((i, 'same', x, y)); continue
        if x is None or y is None: res.append((i, 'DIFF', x, y)); continue
        if norm(x) == norm(y): res.append((i, 'same', x, y)); continue
        ax, ay = answers(x), answers(y)
        if ax and ay and ax[0] == ay[0] and norm(ax[1]) == norm(ay[1]): res.append((i, 'order-only', x, y)); continue
        res.append((i, 'DIFF', x, y))
    return res
if __name__ == '__main__':
    a, b = sys.argv[1], sys.argv[2]
    res = compare(a, b)
    n = {k: sum(1 for r in res if r[1] == k) for k in ('same', 'order-only', 'DIFF')}
    solve_lines = sum(1 for r in res if r[2] and r[2].startswith('@['))
    print(f"{a.split('/')[-1]} vs {b.split('/')[-1]}: lines {len(res)} solve-lines {solve_lines} same {n['same']} order-only {n['order-only']} DIFF {n['DIFF']}")
    for i, k, x, y in res:
        if k == 'DIFF':
            print(f"  [{i}] A: {(x or '')[:220]}\n       B: {(y or '')[:220]}")
