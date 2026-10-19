#!/usr/bin/env python3
"""W2-7 Q4 (D.2 §6.3 row 2) — a LATTICE-LEVEL model of the relational scope cells, run on C9's five programs and the
three fresh ones in w27-row2.prologos, against the DFS answers MEASURED with the real solver
(d3-wave1/C9/c1-overwrite.out, c4-varvar.out, and w27-row2.out).

Proposed design (the combination CL-14/CL-6 converge on):
  * per-key FLAT lattice  bot < consts < TOP                                   (row 2)
  * the read at worldview W is ev_W = base ⊔ ⊔{entry | label ⊆ W}              (C4-1, C9-3)
  * unify-fire writes EACH side's value into the other                          (C4-12, C9-5)
  * fires compute on labelled values: the var-var fire is lifted per entry      (D2L-1; additive, so per-entry = pointwise, C4 B4)
  * TOP meaning, three candidates: NOGOOD (TOP read at W => W is inconsistent; with W = {} that is the query's failure),
    NET-CONTRADICTION (any TOP anywhere => the whole query fails), BASE-ONLY (only a TOP in the base counts).
Ablations (power rows): drop each ingredient in turn; each must break at least one program.
TODAY's stated mechanisms (new-wins merge, shadowing read, var-var conflict dropped, no lift) are modelled too, and
compared with the MEASURED on-network answers as a check on the model.
"""
import itertools
from collections import Counter

TOP = 'TOP'

def join(a, b):
    if a is None: return b
    if b is None: return a
    return a if a == b else TOP

PICK = [[('eq', 'x', 1)], [('eq', 'x', 2)]]           # defr pick [?x] &> (= x 1) &> (= x 2)

def expand(goals, label=frozenset(), counter=None):
    """Flatten calls into (goal, label) with one choice point per call site. Returns goals, choice points."""
    counter = counter if counter is not None else itertools.count()
    out, cps = [], []
    for g in goals:
        if g[0] == 'call':                             # ('call', 'pick', arg)
            k = next(counter); cps.append(k)
            for i, clause in enumerate(PICK):
                sub = [('eq', g[2] if a == 'x' else a, g[2] if b == 'x' else b) for (_, a, b) in clause]
                o, c = expand(sub, label | {(k, i)}, counter)
                out += o; cps += c
        else:
            out.append((g, label))
    return out, cps

def isvar(t): return isinstance(t, str)

def worldviews(cps):
    for choice in itertools.product(*[[(k, 0), (k, 1)] for k in cps]):
        yield frozenset(choice)

def run_proposed(qvars, goals, top_meaning='NOGOOD', ev_join=True, both_sides=True, lift=True):
    flat, cps = expand(goals)
    cells = {}                                          # var -> {label: value}
    ground_nogoods = []
    def write(v, L, val):
        e = cells.setdefault(v, {})
        new = join(e.get(L), val)
        if new != e.get(L): e[L] = new; return True
        return False
    def read(v, W):
        e = cells.get(v, {})
        vis = [(L, x) for L, x in e.items() if L <= W]
        if not vis: return None
        if ev_join:
            r = None
            for _, x in vis: r = join(r, x)
            return r
        return max(vis, key=lambda p: len(p[0]))[1]      # shadowing read (most specific entry wins)
    changed = True; it = 0
    while changed and it < 50:
        changed = False; it += 1
        for (g, L) in flat:
            _, a, b = g
            if not isvar(a) and not isvar(b):
                if a != b and L not in ground_nogoods: ground_nogoods.append(L)
            elif isvar(a) != isvar(b):
                v, c = (a, b) if isvar(a) else (b, a)
                changed |= write(v, L, c)
            else:                                       # var-var
                pairs = [(a, b), (b, a)] if both_sides else [(a, b)]
                for (s, d) in pairs:
                    if lift:
                        for L2, val in list(cells.get(s, {}).items()):
                            changed |= write(d, L | L2, val)
                    else:
                        val = read(s, L)
                        if val is not None: changed |= write(d, L, val)
    allvars = set(cells) | set(qvars)
    any_top = any(x == TOP for e in cells.values() for x in e.values()) or \
              any(read(v, W) == TOP for W in worldviews(cps) for v in allvars)
    if top_meaning == 'NET-CONTRADICTION' and any_top:
        return []
    if any(len(L) == 0 for L in ground_nogoods):
        return []
    answers = []
    for W in worldviews(cps):
        if any(L <= W for L in ground_nogoods): continue
        if top_meaning == 'NOGOOD' and any(read(v, W) == TOP for v in allvars): continue
        if top_meaning == 'BASE-ONLY' and any(cells.get(v, {}).get(frozenset()) == TOP for v in allvars): return []
        answers.append(tuple(sorted((v, read(v, W)) for v in qvars if read(v, W) is not None)))
    return answers

def run_today(qvars, goals):
    flat, cps = expand(goals)
    cells = {}; ground_nogoods = []
    def write(v, L, val):                               # per key, new wins
        e = cells.setdefault(v, {})
        if e.get(L) != val: e[L] = val; return True
        return False
    def read(v, W):                                     # shadowing: entries visible under W hide the base
        e = cells.get(v, {})
        vis = [(L, x) for L, x in e.items() if L <= W and L]
        if vis: return max(vis, key=lambda p: len(p[0]))[1]
        return e.get(frozenset())
    for _ in range(3):                                  # new-wins may not converge: bounded sweeps, in goal order
        for (g, L) in flat:
            _, a, b = g
            if not isvar(a) and not isvar(b):
                if a != b and L not in ground_nogoods: ground_nogoods.append(L)
            elif isvar(a) != isvar(b):
                v, c = (a, b) if isvar(a) else (b, a); write(v, L, c)
            else:
                va, vb = read(a, L), read(b, L)
                if va is not None and vb is None: write(b, L, va)
                elif vb is not None and va is None: write(a, L, vb)
                # both bound and different: dropped (relations.rkt:2112-2120)
    if any(len(L) == 0 for L in ground_nogoods): return []
    return [tuple(sorted((v, read(v, W)) for v in qvars if read(v, W) is not None))
            for W in worldviews(cps) if not any(L <= W for L in ground_nogoods)]

def dfs(qvars, goals):
    """Depth-first search with substitution (the DFS solver's semantics for these first-order programs)."""
    def walk(t, s):
        while isvar(t) and t in s: t = s[t]
        return t
    def solve(gs, s):
        if not gs: yield s; return
        g, rest = gs[0], gs[1:]
        if g[0] == 'call':
            for clause in PICK:
                sub = [('eq', g[2] if a == 'x' else a, g[2] if b == 'x' else b) for (_, a, b) in clause]
                yield from solve(sub + rest, s)
        else:
            a, b = walk(g[1], s), walk(g[2], s)
            if a == b: yield from solve(rest, s)
            elif isvar(a): yield from solve(rest, {**s, a: b})
            elif isvar(b): yield from solve(rest, {**s, b: a})
    out = []
    for s in solve(goals, {}):
        out.append(tuple(sorted((v, walk(v, s)) for v in qvars if not isvar(walk(v, s)))))
    return out

PROGRAMS = {  # name: (query vars, goals, MEASURED on-network answers today, MEASURED DFS answers)
 'C9 Q1 two ?x':            (['x'], [('eq', 'x', 1), ('eq', 'x', 2)], [(('x', 2),)], []),
 'C9 Q2 pick 1':            ([], [('call', 'pick', 1)], [()], [()]),
 'C9 Q3 x=1, pick x':       (['x'], [('eq', 'x', 1), ('call', 'pick', 'x')], [(('x', 2),), (('x', 1),)], [(('x', 1),)]),
 'C9 c4 clash':             (['x', 'y'], [('eq', 'x', 1), ('eq', 'y', 2), ('eq', 'x', 'y')], [(('x', 1), ('y', 2))], []),
 'C9 c4 agree':             (['x', 'y'], [('eq', 'x', 1), ('eq', 'y', 1), ('eq', 'x', 'y')], [(('x', 1), ('y', 1))], [(('x', 1), ('y', 1))]),
 'W27 Q4 pick x, pick y, x=y': (['x', 'y'], [('call', 'pick', 'x'), ('call', 'pick', 'y'), ('eq', 'x', 'y')],
                              [(('x', 1), ('y', 1))], [(('x', 1), ('y', 1)), (('x', 2), ('y', 2))]),
 'W27 Q5 pick x, x=1':      (['x'], [('call', 'pick', 'x'), ('eq', 'x', 1)], [(('x', 1),), (('x', 2),), (('x', 1),)], [(('x', 1),)]),
 'W27 Q6 pick x, y=2, x=y': (['x', 'y'], [('call', 'pick', 'x'), ('eq', 'y', 2), ('eq', 'x', 'y')],
                              [(('x', 1), ('y', 2))], [(('x', 2), ('y', 2))]),
 'W27 Q7 y=2, x=y (control)': (['x', 'y'], [('eq', 'y', 2), ('eq', 'x', 'y')], [(('x', 2), ('y', 2))], [(('x', 2), ('y', 2))]),
 'W27 Q8 pick,pick,x=1,y=x (ctl)': (['x', 'y'], [('call', 'pick', 'x'), ('call', 'pick', 'y'), ('eq', 'x', 1), ('eq', 'y', 'x')],
                              [(('x', 1), ('y', 1))], [(('x', 1), ('y', 1))]),
}

def ms(l): return Counter(l)
print("model DFS == measured DFS (validates the model's DFS):")
for n, (q, g, today, d) in PROGRAMS.items():
    print(f"  {n:28s} {ms(dfs(q, g)) == ms(d)}   dfs={dfs(q, g)}")
print("\nmodel TODAY vs measured on-network answers (as multisets / as sets):")
for n, (q, g, today, d) in PROGRAMS.items():
    t = run_today(q, g)
    print(f"  {n:28s} multiset {ms(t) == ms(today)}  set {set(t) == set(today)}   model={t}  measured={today}")
configs = [
 ('PROPOSED, TOP = NOGOOD (base TOP = query failure)', dict(top_meaning='NOGOOD')),
 ('PROPOSED, TOP = NET-CONTRADICTION',                 dict(top_meaning='NET-CONTRADICTION')),
 ('PROPOSED, TOP = BASE-ONLY',                         dict(top_meaning='BASE-ONLY')),
 ('ablate ev_W join (shadowing read)',                 dict(top_meaning='NOGOOD', ev_join=False)),
 ('ablate both-sides unify (one direction only)',      dict(top_meaning='NOGOOD', both_sides=False)),
 ('ablate per-entry lift (fire reads at its label)',   dict(top_meaning='NOGOOD', lift=False)),
]
print("\nanswer-set agreement with the MEASURED DFS answers (multiset), per configuration:")
for name, kw in configs:
    res = {n: ms(run_proposed(q, g, **kw)) == ms(d) for n, (q, g, today, d) in PROGRAMS.items()}
    bad = [n for n, ok in res.items() if not ok]
    print(f"  {name:52s} {sum(res.values())}/{len(res)}  wrong on: {bad if bad else '-'}")
    for n in bad[:3]:
        q, g, today, d = PROGRAMS[n]
        print(f"      {n}: got {run_proposed(q, g, **kw)}  DFS {d}")
print("\nTODAY's model vs measured DFS:", sum(ms(run_today(q, g)) == ms(d) for n, (q, g, t, d) in PROGRAMS.items()), "/", len(PROGRAMS))
