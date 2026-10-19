#!/usr/bin/env python3
"""W2-2: summarize a legs.jsonl with any leg set: per-file median (of per-process medians) per leg + range,
ratios vs A, tier sums, per-process spread, fingerprint agreement against A."""
import json, sys, statistics as st, collections
rows = [json.loads(l[5:]) for l in open(sys.argv[1]) if l.startswith("W22T:")]
by = collections.defaultdict(list)
for d in rows: by[(d["file"], d["leg"])].append(d)
files = sorted({d["file"] for d in rows}); legs = sorted({d["leg"] for d in rows})
HEAVY = ["constraints-adversarial.prologos", "type-adversarial.prologos"]
pm = lambda d, k: st.median(d[k])
def agg(f, l, k):
    xs = [pm(d, k) for d in by[(f, l)]]; return st.median(xs), min(xs), max(xs), len(xs)
hdr = f"{'file':30} " + " ".join(f"{l:>15}" for l in legs) + "  " + " ".join(f"{l}/A " for l in legs[1:]) + " fp=A?"
print(hdr)
for f in files:
    w = {l: agg(f, l, "wall") for l in legs}
    fpA = {tuple(x) for d in by[(f, "A")] for x in d["fp"]}
    same = "".join("y" if {tuple(x) for d in by[(f, l)] for x in d["fp"]} == fpA else "n" for l in legs)
    print(f"{f[:30]:30} " + " ".join(f"{w[l][0]:5.1f}[{w[l][1]:3.0f}-{w[l][2]:3.0f}]" for l in legs) + "  "
          + " ".join(f"{w[l][0]/w['A'][0]:.2f}" for l in legs[1:]) + "  " + same)
print("processes per leg:", {l: agg(files[0], l, "wall")[3] for l in legs})
print("S0 fire_ms / merge_ms medians (heavy):")
for f in HEAVY:
    print("  ", f[:24], "  ".join(f"{l}: fire {agg(f,l,'fire_ms')[0]:.1f} merge {agg(f,l,'merge_ms')[0]:.1f} gc {agg(f,l,'gc')[0]:.0f}" for l in legs))
for name, sel in [("HEAVY-2", HEAVY), ("MEDIUM-18", files), ("MEDIUM-minus-heavy-16", [f for f in files if f not in HEAVY])]:
    t = {l: sum(agg(f, l, "wall")[0] for f in sel) for l in legs}
    print(f"{name}: " + " ".join(f"{l}={t[l]:.1f}" for l in legs) + "   " + " ".join(f"{l}/A={t[l]/t['A']:.3f}" for l in legs[1:])
          + ("   " + " ".join(f"{a}/{b}={t[a]/t[b]:.3f}" for a, b in [("D", "B"), ("E", "D"), ("E", "B")] if a in t and b in t)))
    for l in legs:
        procs = collections.defaultdict(float)
        for f in sel:
            for i, d in enumerate(by[(f, l)]): procs[i] += pm(d, "wall")
        v = sorted(procs.values()); print(f"    leg {l}: per-process total min {v[0]:.1f} med {st.median(v):.1f} max {v[-1]:.1f}")
