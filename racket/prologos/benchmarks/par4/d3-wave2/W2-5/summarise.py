#!/usr/bin/env python3
# W2-5: summarise dyn.rkt outputs: per file, per leg: result diffs vs seq, stale/assigned params, reentrancy.
import sys, os, re, glob, collections
outdir = sys.argv[1]
files = sorted(set(os.path.basename(p).rsplit('.', 2)[0] for p in glob.glob(f"{outdir}/*.out")))
legs = ['seq', 'fresh', 'prod', 'persist', 'persistcap']
def load(b, leg):
    p = f"{outdir}/{b}.{leg}.out"
    if not os.path.exists(p): return None
    res, stats, params, extra = [], '', {}, []
    for ln in open(p, errors='replace'):
        ln = ln.rstrip('\n')
        if ln.startswith('RESULT'): res.append(ln.split(': ', 1)[1] if ': ' in ln else ln)
        elif ln.startswith('STATS'): stats = ln
        elif ln.startswith('PARAM'):
            m = re.match(r'PARAM (\S+) stale-eq=(\d+) stale-equal=(\d+) assigned-in-fire=(\d+)', ln)
            params[m.group(1)] = tuple(int(x) for x in m.groups()[1:])
        else: extra.append(ln)
    return res, stats, params, extra
stale_any = collections.Counter(); assigned_any = collections.Counter()
print(f"{'file':42s} " + ' '.join(f"{l:>14s}" for l in legs))
for b in files:
    base = load(b, 'seq')
    row = []
    for leg in legs:
        d = load(b, leg)
        if d is None: row.append('-'); continue
        res, stats, params, extra = d
        m = re.search(r'rounds=(\d+) wide-rounds\(>=8\)=(\d+) fires=(\d+) reentrant=(\d+)', stats)
        if not stats: row.append('NOSTATS'); continue
        ndiff = sum(1 for a, c in zip(base[0], res) if a != c) + abs(len(base[0]) - len(res)) if base else -1
        nstale = sum(1 for k, v in params.items() if v[1] > 0)
        nasg = sum(1 for k, v in params.items() if v[2] > 0)
        for k, v in params.items():
            if v[1] > 0: stale_any[(leg, k)] += 1
            if v[2] > 0: assigned_any[(leg, k)] += 1
        exc = sum(1 for r in res if r.startswith('HARNESS-EXCEPTION'))
        row.append(f"d{ndiff}/s{nstale}/a{nasg}/r{m.group(4)}{'/X' if exc else ''}")
    rounds = re.search(r'rounds=(\d+) wide-rounds\(>=8\)=(\d+) fires=(\d+)', base[1]) if base and base[1] else None
    print(f"{b:42s} " + ' '.join(f"{c:>14s}" for c in row) + (f"   seq rounds={rounds.group(1)} wide={rounds.group(2)} fires={rounds.group(3)}" if rounds else ''))
print("\nlegend: d=#results differing from seq, s=#params stale (not equal?) at >=1 round, a=#params assigned inside fires, r=#re-entrant executor calls, X=harness exception")
print("\nassigned-in-fire params (leg: param -> #files):")
for (leg, k), n in sorted(assigned_any.items()): print(f"  {leg:10s} {k} {n}")
