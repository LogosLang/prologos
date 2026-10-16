#!/usr/bin/env python3
"""C5 (PAR 4 D.3, Theory) — can D.2 §6.7's epoch-tagged late-write check miss a late S0 write?

Writer W (an executor finishing an epoch-e fire) and boundary D (the detector that just declared e).
  W ctw : r1 = load(boundary_epoch); if r1 < e: store(cell, 1) else flag 'late-s0-write      (check, then write)
  W wtc : store(cell, 1); r1 = load(boundary_epoch); flag if r1 >= e                        (write, then check)
  W wtcF: store(cell, 1); FENCE; r1 = load(boundary_epoch); flag if r1 >= e
  D     : store(boundary_epoch, e); r2 = load(cell)          (the handler then reads the cell)
  D F   : store(boundary_epoch, e); FENCE; r2 = load(cell)
MISSED = the write landed in memory, the handler read the old value (r2 = 0), and nothing was flagged.
Memory models: SC (interleavings) and x86-TSO (per-thread FIFO store buffers; FENCE drains the buffer).
TSO outcomes are a subset of what release/acquire on ARMv8 (Apple M-series) permits for this pattern
(the store-buffering litmus test), so a TSO miss is also an ARM release/acquire miss.
"""
import itertools

def prog_W(kind):
    if kind == 'ctw':  return [('L', 'be', 'r1'), ('IFSTORE', 'cell', 1)]
    if kind == 'wtc':  return [('S', 'cell', 1), ('L', 'be', 'r1')]
    if kind == 'wtcF': return [('S', 'cell', 1), ('F',), ('L', 'be', 'r1')]
def prog_D(fence):
    return [('S', 'be', 1)] + ([('F',)] if fence else []) + [('L', 'cell', 'r2')]

def explore(pW, pD, tso):
    progs = (pW, pD)
    results = set()
    def rec(pcs, mem, bufs, regs, wrote):
        moved = False
        for t in (0, 1):
            pc = pcs[t]
            if pc < len(progs[t]):
                ins = progs[t][pc]
                op = ins[0]
                nb = [list(b) for b in bufs]; nm = dict(mem); nr = dict(regs); nw = wrote
                ok = True
                if op == 'S' or (op == 'IFSTORE'):
                    if op == 'IFSTORE' and regs.get('r1', 0) >= 1:
                        nr['flag'] = 1
                    else:
                        if tso: nb[t].append((ins[1], ins[2]))
                        else: nm[ins[1]] = ins[2]
                        if ins[1] == 'cell': nw = True
                elif op == 'L':
                    v = None
                    if tso:
                        for (a, x) in reversed(nb[t]):
                            if a == ins[1]: v = x; break
                    nr[ins[2]] = nm.get(ins[1], 0) if v is None else v
                elif op == 'F':
                    if tso and nb[t]: ok = False
                if ok:
                    moved = True
                    np = list(pcs); np[t] += 1
                    rec(tuple(np), nm, tuple(tuple(b) for b in nb), nr, nw)
            if tso and bufs[t]:
                nb = [list(b) for b in bufs]; (a, x) = nb[t].pop(0); nm = dict(mem); nm[a] = x
                moved = True
                rec(pcs, nm, tuple(tuple(b) for b in nb), regs, wrote)
        if not moved:
            flag = regs.get('flag', 0) or (regs.get('r1', 0) >= 1 and progs[0][0][0] == 'S')
            missed = mem.get('cell', 0) == 1 and regs.get('r2', 0) == 0 and not flag
            results.add(('MISSED' if missed else 'ok'))
    rec((0, 0), {}, ((), ()), {}, False)
    return results

print(__doc__.strip().splitlines()[0])
for tso in (False, True):
    for w in ('ctw', 'wtc', 'wtcF'):
        for f in (False, True):
            r = explore(prog_W(w), prog_D(f), tso)
            print(f"{'TSO' if tso else 'SC '}  W={w:4s} D={'fence' if f else 'plain'}  "
                  f"{'MISSED late write reachable' if 'MISSED' in r else 'never missed'}")
