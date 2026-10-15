#!/usr/bin/env python3
"""PAR 4 O-10 evidence: medians of o10-instrument-cost.sh output (sequential ms per network, main vs branch).
   python3 benchmarks/par4/o10-cost-summary.py data/par4-p0/o10/instrument-cost"""
import re, glob, sys, statistics as st, collections
D = sys.argv[1]
def parse(f):
    sec = None; out = {}
    for l in open(f):
        m = re.match(r'═══ (.+?) ═══', l)
        if m: sec = m.group(1).split(' (')[0]; continue
        p = l.split()
        if len(p) >= 5 and p[0].isdigit() and sec: out[(sec, int(p[0]))] = float(p[2])
    return out
rows = collections.defaultdict(lambda: collections.defaultdict(list))
for f in sorted(glob.glob(D + '/*-*.txt')):
    leg = f.rsplit('-', 1)[1][:-4]
    for k, s in parse(f).items(): rows[k][leg].append(s)
print(f"{'network (sequential, threshold off)':40s} {'main ms':>8s} {'branch ms':>10s} {'branch/main':>12s}  ranges main | branch  (n={len(rows[next(iter(rows))]['main'])} interleaved)")
for k in sorted(rows):
    m, b = rows[k]['main'], rows[k]['branch']
    print(f"{k[0]+' '+str(k[1]):40s} {st.median(m):8.2f} {st.median(b):10.2f} {st.median(b)/st.median(m):12.3f}  {min(m):.2f}-{max(m):.2f} | {min(b):.2f}-{max(b):.2f}")
