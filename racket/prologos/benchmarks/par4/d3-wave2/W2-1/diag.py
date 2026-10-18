#!/usr/bin/env python3
"""W2-1 extra diagnostics on the heavy files: why time-weighted parallelism is low.
  - per-round concentration: time share of the round's heaviest fire (time-weighted mean over rounds)
  - fires > 20 us per round
  - work/span with COMPONENT-level edges (as in gran_analyze) vs CELL-level edges (power: the matcher must
    discriminate; cell-level edges are a superset so span_cell >= span_comp)
  - work/span with NO edges inside a run except round order removed (= T / sum over runs of max fire): ideal
  - the p2lite estimate's removed diff time
usage: diag.py FILE.json ..."""
import json, sys, statistics
from collections import defaultdict
sys.path.insert(0, '.')
from gran_analyze import units_match

for p in sys.argv[1:]:
    d = json.load(open(p)); F = d['fires']; F.sort(key=lambda f: (f['call'], f['idx']))
    for j, f in enumerate(F):
        f['t'] = statistics.median([r[j] for r in d['rep_ms']])
    T = sum(f['t'] for f in F)
    rounds = defaultdict(list); runs = defaultdict(list)
    for f in F:
        rounds[(f['run'], f['round'])].append(f); runs[f['run']].append(f)
    conc = sum(max(x['t'] for x in fs) for fs in rounds.values()) / T
    heavy = [sum(1 for x in fs if x['t'] > 0.020) for fs in rounds.values()]
    def span(level):
        sp = {}; tot = 0.0
        for rid, fs in runs.items():
            m = 0.0
            for f in sorted(fs, key=lambda f: (f['round'], f['idx'])):
                prev = rounds.get((rid, f['round'] - 1), [])
                best = 0.0
                for g in prev:
                    hit = False
                    for w in g['writes'] + g['undeclared']:
                        for i in f['ins']:
                            if i['n'] != w['cell']['n']:
                                continue
                            if level == 'cell' or any(units_match(wu, iu) for wu in w['units'] for iu in i['units']):
                                hit = True
                    if hit:
                        best = max(best, sp[id(g)])
                sp[id(f)] = f['t'] + best
                m = max(m, sp[id(f)])
            tot += m
        return tot
    s_comp = span('comp'); s_cell = span('cell')
    ideal = sum(max(x['t'] for x in fs) for fs in runs.values())
    edges_comp = edges_cell = 0
    print('%s: T=%.3f ms | heaviest-fire share of its round (time-weighted) %.3f | rounds with >=2 fires >20us: %d of %d | '
          'work/span comp-edges %.2f, cell-edges %.2f, no-edges (T / sum of each run\'s heaviest fire) %.2f' % (
              p.split('/')[-1], T, conc, sum(1 for h in heavy if h >= 2), len(heavy), T / s_comp, T / s_cell, T / ideal))
