#!/usr/bin/env python3
"""C3 probe: read P0's dynamic census (comparative-census-bsp.jsonl, read-only) and report, per file,
the share of S0 value writes whose cell merge is attribute-map-merge-fn (whose :type facet composes
type-unify-or-top, classify-inhabit.rkt:171) and the hub-cell data (hub_cells_top10 = [cell, degree]).
Purpose: bound the share of writes that the per-cell fence (D.2 §6.3) covers while O-12 (ii) is open,
and whether a single cell carries most writes (home = owner of first output => one executor)."""
import json, collections
P = "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/data/par4-p0/comparative-census-bsp.jsonl"
tot = collections.Counter(); allw = 0
for line in open(P):
    r = json.loads(line)
    if 'error' in r and r.get('error'):
        print("SKIP", r['file'].split('/')[-1], r['error']); continue
    w = r.get('writes', 0); allw += w
    bym = dict((m, n) for m, n in r.get('writes_by_merge', []))
    for m, n in bym.items(): tot[m] += n
    ln = r.get('largest_network', {}) or {}
    cbm = dict((m, n) for m, n in ln.get('cells_by_merge', []))
    am = bym.get('attribute-map-merge-fn', 0)
    rr = (r.get('cut_K8', {}) or {}).get('rr', {})
    print(f"{r['file'].split('/')[-1]:40s} writes={w:5d} attr-map={am:5d} ({(am/w*100 if w else 0):5.1f}%) "
          f"attr-map cells in largest net={cbm.get('attribute-map-merge-fn',0)} cells={ln.get('cells')} "
          f"props={ln.get('propagators')} hubs={ln.get('hub_cells_top10')} rr_foreign_write={rr.get('fires_with_foreign_write_share')}")
print("TOTAL writes", allw)
for m, n in tot.most_common(8): print(f"  {m:32s} {n:5d} {n/allw*100:5.1f}%")
