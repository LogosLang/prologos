#!/usr/bin/env python3
"""Summarize ab152.sh jsonl: per (test, leg) median of each phase metric, load range."""
import json, sys, statistics as st
from collections import defaultdict
path = sys.argv[1]
phase = sys.argv[2] if len(sys.argv) > 2 else 'test_phase'
rows = [json.loads(l) for l in open(path)]
g = defaultdict(list)
for r in rows:
    g[(r['r']['test'], r['leg'])].append(r)
keys = ['cpu_ms', 'gc_ms', 'mb', 'major', 'minor', 'wall_ms']
print(f"phase={phase}  (median over n runs; values per run listed for cpu_ms)")
print("| test | leg | n | load1 range | " + " | ".join(keys) + " | cpu_ms runs |")
print("|---|---|---|---|" + "---|" * len(keys) + "---|")
for (t, leg), rs in sorted(g.items()):
    vals = {k: [x['r'][phase][k] for x in rs] for k in keys}
    loads = [x['load1'] for x in rs]
    med = {k: st.median(v) for k, v in vals.items()}
    print(f"| {t} | {leg} | {len(rs)} | {min(loads):.2f}–{max(loads):.2f} | " +
          " | ".join(f"{med[k]:g}" for k in keys) + f" | {vals['cpu_ms']} |")
