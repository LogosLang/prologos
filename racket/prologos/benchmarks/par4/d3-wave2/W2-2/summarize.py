#!/usr/bin/env python3
"""W2-2: summarize legs.jsonl -> per-file medians per leg, ratios vs A, corpus sums, fingerprint parity."""
import json, sys, statistics as st, collections
path = sys.argv[1]
rows = [json.loads(l[5:]) for l in open(path) if l.startswith("W22T:")]
by = collections.defaultdict(list)       # (file, leg) -> list of per-process dicts
for d in rows: by[(d["file"], d["leg"])].append(d)
files = sorted({d["file"] for d in rows}); legs = ["A", "B", "C", "D"]
HEAVY = ["constraints-adversarial.prologos", "type-adversarial.prologos"]
def pm(d, k): return st.median(d[k])                 # per-process median over reps
def agg(f, l, k):
    xs = [pm(d, k) for d in by[(f, l)]]
    return st.median(xs), min(xs), max(xs), len(xs)
print(f"{'file':34} " + " ".join(f"{l+' wall':>16}" for l in legs) + "   B/A   C/A   D/A   D/B  fp-same  fire A/B/C/D            merge A/B/C/D")
tot = {l: 0.0 for l in legs}; toth = {l: 0.0 for l in legs}
per_round_tot = collections.defaultdict(lambda: collections.defaultdict(float))
for f in files:
    w = {l: agg(f, l, "wall") for l in legs}
    fire = {l: agg(f, l, "fire_ms")[0] for l in legs}; mer = {l: agg(f, l, "merge_ms")[0] for l in legs}
    fps = {l: {tuple(map(tuple, d["fp"])) for d in by[(f, l)]} for l in legs}
    allfp = set().union(*[{x for t in fps[l] for x in t} for l in legs])
    fpA = {x for t in fps["A"] for x in t}
    same = all({x for t in fps[l] for x in t} == fpA for l in legs)
    for l in legs:
        tot[l] += w[l][0]
        if f in HEAVY: toth[l] += w[l][0]
    print(f"{f[:34]:34} " + " ".join(f"{w[l][0]:6.1f}[{w[l][1]:4.0f}-{w[l][2]:4.0f}]" for l in legs)
          + f"  {w['B'][0]/w['A'][0]:.2f}  {w['C'][0]/w['A'][0]:.2f}  {w['D'][0]/w['A'][0]:.2f}  {w['D'][0]/w['B'][0]:.2f}  {str(same):5}  "
          + "/".join(f"{fire[l]:.1f}" for l in legs) + "   " + "/".join(f"{mer[l]:.1f}" for l in legs))
print("n processes per (file,leg):", {l: agg(files[0], l, 'wall')[3] for l in legs})
for name, t in [("HEAVY (2) sum of medians", toth), ("MEDIUM (18) sum of medians", tot)]:
    print(f"{name}: " + "  ".join(f"{l}={t[l]:.1f}" for l in legs)
          + f"   B/A={t['B']/t['A']:.3f} C/A={t['C']/t['A']:.3f} D/A={t['D']/t['A']:.3f} D/B={t['D']/t['B']:.3f} D/C={t['D']/t['C']:.3f}")
# per-process corpus totals (sum over files of per-process medians) -> spread across the 8 processes per leg
for name, sel in [("HEAVY", HEAVY), ("MEDIUM", files)]:
    for l in legs:
        procs = collections.defaultdict(float)
        for f in sel:
            for i, d in enumerate(by[(f, l)]): procs[i] += pm(d, "wall")
        v = sorted(procs.values())
        print(f"  {name} leg {l}: per-process totals min {v[0]:.1f} med {st.median(v):.1f} max {v[-1]:.1f}")
# medium tier without the two heavy files
rest = [f for f in files if f not in HEAVY]
t = {l: sum(agg(f, l, "wall")[0] for f in rest) for l in legs}
print("MEDIUM minus heavy (16): " + "  ".join(f"{l}={t[l]:.1f}" for l in legs)
      + f"   B/A={t['B']/t['A']:.3f} C/A={t['C']/t['A']:.3f} D/A={t['D']/t['A']:.3f}")
