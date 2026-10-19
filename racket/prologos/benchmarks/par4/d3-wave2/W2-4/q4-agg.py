#!/usr/bin/env python3
"""W2-4 Q4: aggregate q4-run.sh output (one line per file: exit, path, W24 json)."""
import json, sys
rows = []
for l in open(sys.argv[1]):
    parts = l.rstrip('\n').split(' ', 2)
    if len(parts) < 2: continue
    d = None
    if len(parts) > 2:
        try: d = json.loads(parts[2])
        except Exception: pass
    rows.append((parts[0], parts[1], d))
ok = [r for r in rows if r[2]]
print('files', len(rows), 'with summary', len(ok), 'nonzero exit', [(r[0], r[1]) for r in rows if r[0] != '0'])
hist = {}
for r in ok:
    for k, v in r[2].get('outer_hist', {}).items(): hist[int(k)] = hist.get(int(k), 0) + v
print('BSP runs', sum(r[2].get('outer_runs', 0) for r in ok), 'outer-round histogram', dict(sorted(hist.items())))
print('handler calls', sum(r[2].get('handler_calls', 0) for r in ok),
      'handler produced S0', sum(r[2].get('handler_produced_s0', 0) for r in ok),
      'continuations linked', sum(r[2].get('outer_continuations', 0) for r in ok),
      'unlinked rounds', sum(r[2].get('outer_unlinked_rounds', 0) for r in ok))
for r in sorted(ok, key=lambda r: -r[2].get('outer_max', 0))[:6]:
    print(' ', r[2].get('outer_max'), r[1], 'runs', r[2].get('outer_runs'), 'produced', r[2].get('handler_produced_s0', 0), 'linked', r[2].get('outer_continuations', 0))
