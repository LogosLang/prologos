#!/usr/bin/env python3
"""PAR 4 O-9 evidence: aggregate a PAR4_MERGE_ORDER_CENSUS file (propagator.rkt).
   python3 benchmarks/par4/o9-census-summary.py FILE [--exclude-prelude-gen] [--exclude-label=NAME ...]
Sums the per-process summary lines, then groups divergence events by (order, merge functions,
contradiction differs, test file). --exclude-prelude-gen drops the process that regenerated the .pnet
cache (tools/pnet-compile.rkt: exactly 5 rounds / 2 002 fires at 2b1e1e78), reported on its own line."""
import json, sys, collections
path = sys.argv[1]; excl = '--exclude-prelude-gen' in sys.argv
drop = {a.split('=', 1)[1] for a in sys.argv if a.startswith('--exclude-label=')}
rows = [r for r in (json.loads(l) for l in open(path)) if r.get('label') not in drop]
if drop: print(f"excluded labels: {sorted(drop)}")
summ = [r for r in rows if r['kind'] == 'summary']
gen = [r for r in summ if r.get('rounds') == 5 and r.get('fires') == 2002]
if excl: summ = [r for r in summ if r not in gen]
S = collections.Counter()
for r in summ:
    for k, v in r.items():
        if isinstance(v, (int, float)): S[k] += v
print(f"processes: {len(summ)}  thresholds: {sorted(set(r.get('threshold') for r in summ))}"
      + (f"  (excluded {len(gen)} prelude-generation process(es): {gen[0] if gen else ''})" if excl else ""))
for k in sorted(S): print(f"  {k:44s} {S[k]}")
ev = [r for r in rows if r['kind'] == 'event']
print(f"events: {len(ev)} (cap 300 per process); in rounds >= 256 fires: {sum(1 for e in ev if e['fires'] >= 256)}")
byorder = collections.Counter(e['order'] for e in ev); print("  by order:", dict(byorder))
m = collections.Counter()
for e in ev:
    for f in (e['merges'] or ['(contradiction only)']): m[(e['order'], f)] += 1
print("  by (order, merge function) — events naming it:")
for (o, f), v in m.most_common(): print(f"    {v:4d}  {o}  {f}")
t = collections.Counter(e['test'] or '(no tests/ frame on the stack)' for e in ev)
print("  by test file (first tests/ frame on the stack):")
for f, v in t.most_common(): print(f"    {v:4d}  {f}")
