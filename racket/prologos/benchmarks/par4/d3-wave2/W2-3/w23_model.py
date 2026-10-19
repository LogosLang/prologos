#!/usr/bin/env python3
"""W2-3 (PAR 4 D.3 wave 2) — one exhaustive model of D.2 §6.7's quiescence detector and of every proposed repair.

WHAT IS MODELLED (one engine; scenarios switch features on):
  * K = 2 or 3 executors + one detector thread (which also runs the boundary handler).
  * Executor loop exactly as D.2 §6.7 words it: at the top of each iteration load the contradiction word (if the
    scenario has one), then drain every incoming lane (load the lane word, join each delta into the owned cell = a
    store, enqueue local dependents, notify dependents homed elsewhere), then publish per the scheme, then pop and fire
    one local item, then back to the top.  An empty worklist = publish "idle" per the scheme and spin.
  * Local cascades: a drained delta enqueues a local chain (q1 -> q2 -> write), which sends no message.
  * Fire requests: a dependent homed on another executor is notified by a COUNTED lane message ('wake'),
    by an UNCOUNTED push onto that executor's worklist, or not at all (D.2's Lane = Set [CellId Delta]).
  * Contradiction: a fire stores CW := 1; executors load CW at the top of the loop and stop.  Boundary modes:
      Q    D.2 as written: the boundary fires only on the counter predicate.
      QC   quiescence OR contradiction, the handler starts at once.
      QCH  quiescence OR contradiction, the handler starts only after every executor has stored parked_i (handshake).
  * Regions keyed by network id: every item, message and counter carries a region; counters/indicators are keyed by
    (region, executor) when keyed=True, or process-wide (region 0) when keyed=False.  Detector "tasks" detect one
    region (or all) in a given order; a nested run is a region seeded by the previous region's boundary handler.
  * Memory: SC (interleaving), TSO (per-thread FIFO store buffer; a load reads the thread's own newest buffered
    store, else memory; a FENCE blocks until the buffer is empty — the briefing's store-buffering abstraction), and
    PSO (as TSO, but stores to DIFFERENT addresses may drain out of order — what ARMv8 permits for plain stores with
    no barrier between them).  Every shared load/store is its own step; buffer drains are separate steps.
    Hypothesis on the detector side: its loads are performed in program order (memory-order-acquire per scan on ARM).
    Each lane word holds the whole log (slot+tail publication is taken as one store: detect.rkt already puts a
    release between slot and tail, and C6 measured that it is needed).

SCHEMES (the detector predicate always needs both scans identical, unless noted):
  D2      D.2 as written: idle-epoch_i (a max-counter set to e on going idle, never lowered in e); cons at drain.
  FLAG    (a) D.1's resettable flag: flag:=busy on draining a non-empty lane, flag:=idle when the worklist empties.
  ACT     (b) C5's activity parity counter: +1 at each idle<->busy transition; idle iff even.
  QUIET   (c) C3's quiet mark: on going idle publish (e, cons_i); idle iff mark = (e, cons_i as read).
  DEFER   (d) cons_i published only when the cascade has drained (on going idle), with D.2's idle-epoch kept.
  SEEDS   (d') cons published after the cascade AND the epoch's seeds sent as counted messages from the scheduler;
          no idle indicator at all — two counters per executor (Mattern's counting in the atomic model).
  CREDIT  (e) credit recovery (Mattern 1989 / Huang 1989): seeds hold credit 1 in total; each message carries half
          of its sender's credit; a passive executor adds what it holds to its OWN returned_i (a monotone sum,
          single writer); the detector declares when sum(returned_i) = 1 — ONE scan, a monotone threshold.
  Single-scan variants (scans=1) are the power rows for the double scan.

CHECKS (exhaustive BFS over every interleaving):
  PREMATURE  the detector declares while some worklist/lane/buffered message is non-empty or an executor is mid-fire.
  WRONGFIX   declared at true quiescence, but a cell never reached its least-fixpoint value (a lost wake-up).
  STALE      the handler loaded a cell value below the least fixpoint (premature, or a buffered store not yet visible).
  RACE       after a contradiction boundary started the handler, an S0 store still reached memory or a fire ran.
  LIVE       every reachable state can still reach the boundary (AG EF done); a counterexample is printed.
  LATE-WRITE check (C5-7), when enabled: MISSED = a settled state where the handler read an old value of a cell the
             writer later wrote, and no writer flagged 'late-s0-write.
"""
import sys
from collections import deque
from fractions import Fraction

# ----------------------------------------------------------------------------------------------- workloads ---
# items: name -> (home exec, region, effects); effects: ('send', dst, ('delta', cell, deps)), ('write', cell),
#        ('enq', item), ('freq', item), ('contra',)
# cells: name -> (owner exec, region)
def W(K, seeds, items, cells, expected=None, contra=False, tasks=None, nested=None, upstream=None):
    regions = sorted({r for (_, r, _) in items.values()} | {r for (_, r) in cells.values()})
    exp = expected if expected is not None else {c: 1 for c in cells}
    return dict(K=K, seeds=seeds, items=items, cells=cells, expected=exp, contra=contra, regions=regions,
                tasks=tasks, nested=nested or {})

A, B, C = 0, 1, 2
WORKLOADS = {
    # C1/C3/C5's trace: A's delta to B; B's join enqueues a local chain that sends nothing.
    'CASCADE': W(2, {A: ['p']},
                 {'p': (A, 0, [('send', B, ('delta', 'cB', ('q1',)))]),
                  'q1': (B, 0, [('enq', 'q2')]), 'q2': (B, 0, [('write', 'cB2')])},
                 {'cB': (B, 0), 'cB2': (B, 0)}),
    # C3-5 / C5 S2: A writes its own cell; the dependent r is homed on B (a fire request).
    'FREQ': W(2, {A: ['p']},
              {'p': (A, 0, [('write', 'cA'), ('freq', 'r')]), 'r': (B, 0, [('write', 'cB')])},
              {'cA': (A, 0), 'cB': (B, 0)}),
    # a cascade that sends a message back: cons-after-cascade must not hide the send.
    'BOUNCE': W(2, {A: ['p']},
                {'p': (A, 0, [('send', B, ('delta', 'cB', ('q1',)))]),
                 'q1': (B, 0, [('send', A, ('delta', 'cA', ('s',)))]), 's': (A, 0, [('write', 'cA2')])},
                {'cB': (B, 0), 'cA': (A, 0), 'cA2': (A, 0)}),
    # a fire that does S0 work AFTER its send (count-before-send matters when nothing else marks A busy).
    'SENDWRITE': W(2, {A: ['p']},
                   {'p': (A, 0, [('send', B, ('delta', 'cB', ('q1',))), ('write', 'cA')]),
                    'q1': (B, 0, [('write', 'cB2')])},
                   {'cB': (B, 0), 'cA': (A, 0), 'cB2': (B, 0)}),
    # seeds on both executors, one of them messages the other mid-cascade.
    'SEEDS2': W(2, {A: ['a1'], B: ['b1']},
                {'a1': (A, 0, [('enq', 'a2')]), 'a2': (A, 0, [('send', B, ('delta', 'cB', ('q1',)))]),
                 'b1': (B, 0, [('write', 'cB0')]), 'q1': (B, 0, [('write', 'cB2')])},
                {'cB': (B, 0), 'cB0': (B, 0), 'cB2': (B, 0)}),
    # K = 3: delta A->B, B's cascade writes its own cell whose dependent is homed on C (fire request), C's cascade.
    'K3': W(3, {A: ['p']},
            {'p': (A, 0, [('send', B, ('delta', 'cB', ('q1',)))]),
             'q1': (B, 0, [('write', 'cB2'), ('freq', 'r')]),
             'r': (C, 0, [('enq', 'r2')]), 'r2': (C, 0, [('write', 'cC')])},
            {'cB': (B, 0), 'cB2': (B, 0), 'cC': (C, 0)}),
    # contradiction stop: p sends a delta and raises the contradiction; B's cascade writes.  Fixpoint = TOP:
    # what matters is that the boundary fires (LIVE) and that no S0 write lands after the handler starts (RACE).
    'CONTRA': W(2, {A: ['p']},
                {'p': (A, 0, [('send', B, ('delta', 'cB', ('q1',))), ('contra',)]),
                 'q1': (B, 0, [('enq', 'q2')]), 'q2': (B, 0, [('write', 'cB2')])},
                {'cB': (B, 0), 'cB2': (B, 0)}, contra=True),
    # two regions (network ids 1, 2) live at once; region 2's work sends a delta INTO region 1 (an upstream edge,
    # e.g. an SLG answer flowing to its consumer).  tasks = order in which the detector closes regions.
    'REGIONS': W(2, {A: ['p1'], B: ['q2']},
                 {'p1': (A, 1, [('write', 'cA1')]),
                  'q2': (B, 2, [('enq', 'q3')]), 'q3': (B, 2, [('write', 'cB2'), ('send', A, ('delta', 'cX1', ('a1',)))]),
                  'a1': (A, 1, [('write', 'cA3')])},
                 {'cA1': (A, 1), 'cB2': (B, 2), 'cX1': (A, 1), 'cA3': (A, 1)}),
    # nested run: region 1's boundary handler seeds region 2 (a fork, e.g. NAF's inner solve) — sequential nesting.
    'NESTED': W(2, {A: ['p1']},
                {'p1': (A, 1, [('send', B, ('delta', 'cB1', ('q1',)))]), 'q1': (B, 1, [('write', 'cB2')]),
                 's2': (B, 2, [('send', A, ('delta', 'cA2', ('t2',)))]), 't2': (A, 2, [('write', 'cA3')])},
                {'cB1': (B, 1), 'cB2': (B, 1), 'cA2': (A, 2), 'cA3': (A, 2)},
                nested={1: [(B, 's2')]}),
}

class _Any: pass
ANY = _Any()

SCHEMES = ['D2', 'FLAG', 'ACT', 'QUIET', 'DEFER', 'SEEDS', 'CREDIT']
E = 1  # the (per-region) epoch being detected


class Cfg:
    def __init__(self, scheme, mem='SC', repr='SEP', fr='counted', boundary='Q', scans=2, fences=(),
                 sendorder='lane-prod', pubord='ind-cons', readord='PCI', keyed=True, tasks=None,
                 latecheck=None, detfence=False, post=False, tag='per-network'):
        self.scheme, self.mem, self.repr, self.fr, self.boundary = scheme, mem, repr, fr, boundary
        self.scans = 1 if scheme == 'CREDIT' else scans
        self.fences = set(fences)
        self.sendorder, self.pubord, self.readord, self.keyed = sendorder, pubord, readord, keyed
        self.tasks, self.latecheck, self.detfence, self.post, self.tag = tasks, latecheck, detfence, post, tag

    def label(self):
        f = '+'.join(sorted(self.fences)) or '-'
        s = f'{self.scheme:6s} {self.mem:3s} {self.repr} fr={self.fr:9s} bnd={self.boundary:3s} scans={self.scans} fences={f}'
        if self.scheme in ('FLAG', 'ACT') or self.repr == 'SEP' and self.sendorder != 'lane-prod':
            s += f' send={self.sendorder} pub={self.pubord}'
        if self.readord != 'PCI': s += f' read={self.readord}'
        if not self.keyed: s += ' UNKEYED'
        if self.tasks: s += f' tasks={self.tasks}'
        if self.latecheck: s += f' late={self.latecheck}{"+detF" if self.detfence else ""}'
        return s


# --------------------------------------------------------------------------------------------- the engine ---
class Model:
    def __init__(self, wl, cfg):
        self.w, self.c = wl, cfg
        self.K = wl['K']
        self.items = wl['items']
        self.R = wl['regions']
        self.rk = (lambda r: r) if cfg.keyed else (lambda r: 0)       # counter key for a region
        self.keys = sorted({self.rk(r) for r in self.R})
        self.srcs = {i: [j for j in range(self.K) if j != i] + (['S'] if self.uses_sched() else []) for i in range(self.K)}
        # shared addresses
        addrs = []
        for i in range(self.K):
            for k in self.keys:
                addrs += [('P', k, i), ('C', k, i), ('I', k, i), ('R', k, i)]
            for s in self.srcs[i]:
                addrs += [('L', i, s), ('H', i, s)]
            addrs.append(('PK', i))
        addrs += [('CW',), ('B',)] + [('X', c) for c in wl['cells']]
        self.addrs = addrs
        self.ix = {a: n for n, a in enumerate(addrs)}
        # detector tasks: tuples of regions closed together, in order
        if cfg.tasks is not None:
            self.tasks = cfg.tasks
        elif wl['nested']:
            self.tasks = [(r,) for r in self.R]
        else:
            self.tasks = [tuple(self.R)]
        if not cfg.keyed:
            self.tasks = [tuple(self.R)] if not wl['nested'] else [(r,) for r in self.R]

    def uses_sched(self):
        return self.c.scheme in ('SEEDS', 'EARLY') or bool(self.w['nested'])

    # ---- initial state ----
    def initial(self):
        c, w = self.c, self.w
        mem = [0] * len(self.addrs)
        for i in range(self.K):
            for s in self.srcs[i]:
                mem[self.ix[('L', i, s)]] = ()
            for k in self.keys:
                if c.scheme in ('FLAG', 'FLAGD'):
                    mem[self.ix[('I', k, i)]] = 0          # 0 = busy (conservative start)
                elif c.scheme == 'ACT':
                    mem[self.ix[('I', k, i)]] = 1          # odd = busy
                elif c.scheme == 'QUIET':
                    mem[self.ix[('I', k, i)]] = (0, 0)
                elif c.scheme == 'CREDIT':
                    mem[self.ix[('R', k, i)]] = Fraction(0)
        sched = {k: 0 for k in self.keys}
        execs = []
        seeded = [i for i in range(self.K) if w['seeds'].get(i)]
        for i in range(self.K):
            wl = tuple(w['seeds'].get(i, []))
            held = {k: Fraction(0) for k in self.keys}
            if c.scheme in ('SEEDS', 'EARLY'):
                # seeds travel as counted messages on the scheduler's lane
                msgs = tuple(('seed', self.items[it][1], it, None, Fraction(0)) for it in wl)
                mem[self.ix[('L', i, 'S')]] = msgs
                for m in msgs:
                    sched[self.rk(m[1])] += 1
                wl = ()
            if c.scheme == 'CREDIT' and i in seeded:
                # one unit of credit per counter key, split evenly over that key's seeds
                for it in w['seeds'][i]:
                    k = self.rk(self.items[it][1])
                    nk = sum(1 for j in seeded for it2 in w['seeds'][j] if self.rk(self.items[it2][1]) == k)
                    held[k] += Fraction(1, nk)
            ind = {}
            for k in self.keys:
                ind[k] = {'FLAG': 0, 'FLAGD': 0, 'ACT': 1, 'QUIET': (0, 0)}.get(c.scheme, 0)
            ex = dict(todo=self.top_ops(i), wl=wl,
                      cur=tuple(0 for _ in self.srcs[i]), pubcur=tuple(0 for _ in self.srcs[i]),
                      out=tuple(() for _ in range(self.K)),
                      prod=tuple(0 for _ in self.keys), consp=tuple(0 for _ in self.keys),
                      unack=tuple(0 for _ in self.keys), n=tuple(0 for _ in self.keys),
                      ind=tuple(ind[k] for k in self.keys), held=tuple(held[k] for k in self.keys),
                      ret=tuple(Fraction(0) for _ in self.keys),
                      buf=(), halted=False, late=False, fired_after=False)
            execs.append(self.freeze_ex(ex))
        det = dict(task=0, phase='scan', reads=(), scan1=None, buf=(), hread=(), done=False,
                   declared_premature=False, why=None)
        return (tuple(execs), self.freeze_det(det), tuple(mem), tuple(sched[k] for k in self.keys), ())

    EXF = ['todo', 'wl', 'cur', 'pubcur', 'out', 'prod', 'consp', 'unack', 'n', 'ind', 'held', 'ret', 'buf',
           'halted', 'late', 'fired_after']
    DEF = ['task', 'phase', 'reads', 'scan1', 'buf', 'hread', 'done', 'declared_premature', 'why']

    def freeze_ex(self, d): return tuple(d[f] for f in self.EXF)
    def thaw_ex(self, t): return dict(zip(self.EXF, t))
    def freeze_det(self, d): return tuple(d[f] for f in self.DEF)
    def thaw_det(self, t): return dict(zip(self.DEF, t))

    def ki(self, k): return self.keys.index(k)

    def top_ops(self, i):
        ops = []
        if self.w['contra']:
            ops.append(('LCW',))
        ops += [('LL', s) for s in self.srcs[i]]
        ops += [('POSTDRAIN',), ('POP',)]
        return tuple(ops)

    # ---- memory helpers ----
    def load(self, mem, buf, addr):
        for (a, v) in reversed(buf):
            if a == addr:
                return v
        return mem[self.ix[addr]]

    def store(self, mem, buf, addr, v):
        """returns (mem, buf)"""
        if self.c.mem == 'SC':
            m = list(mem); m[self.ix[addr]] = v
            return tuple(m), buf
        return mem, buf + ((addr, v),)

    def flushes(self, buf):
        """indices of buffer entries that may drain next"""
        if not buf:
            return []
        if self.c.mem == 'TSO':
            return [0]
        seen, out = set(), []
        for n, (a, _) in enumerate(buf):
            if a not in seen:
                seen.add(a); out.append(n)
        return out

    # ---- per-scheme publication op lists ----
    def fence(self, name):
        return [('F',)] if name in self.c.fences else []

    def consume_pub(self, ex, k):
        """ops after draining n>0 messages of key k at the top of the loop"""
        s, c = self.c.scheme, self.c
        kx = self.ki(k)
        n = ex['n'][kx]
        if s in ('D2', 'QUIET', 'EARLY'):
            ex['consp'] = upd(ex['consp'], kx, ex['consp'][kx] + n)
            return self.fence('pub') + self.cons_store_ops(ex, k)
        if s in ('FLAG', 'ACT'):
            ops = []
            busy_ind = None
            if s == 'FLAG' and ex['ind'][kx] != 0:
                busy_ind = 0
            if s == 'ACT' and ex['ind'][kx] % 2 == 0:
                busy_ind = ex['ind'][kx] + 1
            ex['consp'] = upd(ex['consp'], kx, ex['consp'][kx] + n)
            cons_ops = self.cons_store_ops(ex, k)
            if busy_ind is not None:
                ex['ind'] = upd(ex['ind'], kx, busy_ind)
                ind_ops = [('SI', k, busy_ind)]
                if c.pubord == 'ind-cons':
                    ops = ind_ops + self.fence('pub') + cons_ops
                else:
                    ops = cons_ops + self.fence('pub') + ind_ops
            else:
                ops = self.fence('pub') + cons_ops
            return ops
        if s in ('DEFER', 'SEEDS'):
            ex['unack'] = upd(ex['unack'], kx, ex['unack'][kx] + n)
            return []
        if s == 'FLAGD':
            ex['unack'] = upd(ex['unack'], kx, ex['unack'][kx] + n)
            if ex['ind'][kx] != 0:
                ex['ind'] = upd(ex['ind'], kx, 0)
                return [('SI', k, 0)]
            return []
        if s == 'CREDIT':
            return []
        raise ValueError(s)

    def cons_store_ops(self, ex, k):
        if self.c.repr == 'SEP':
            return [('SC', k, ex['consp'][self.ki(k)])]
        # LOG: publish the consumer cursors (heads) of every lane up to the read cursors
        ops = []
        pc = list(ex['pubcur'])
        for n_, s in enumerate(self.srcs[self.cur_i]):
            if pc[n_] != ex['cur'][n_]:
                ops.append(('SH', s, ex['cur'][n_]))
                pc[n_] = ex['cur'][n_]
        ex['pubcur'] = tuple(pc)
        return ops

    def idle_pub(self, ex, k):
        """ops when executor has no work of key k left"""
        s = self.c.scheme
        kx = self.ki(k)
        if s == 'D2':
            if ex['ind'][kx] != E:
                ex['ind'] = upd(ex['ind'], kx, E); return self.fence('pub') + [('SI', k, E)]
            return []
        if s == 'FLAG':
            if ex['ind'][kx] != 1:
                ex['ind'] = upd(ex['ind'], kx, 1); return self.fence('pub') + [('SI', k, 1)]
            return []
        if s == 'ACT':
            if ex['ind'][kx] % 2 == 1:
                v = ex['ind'][kx] + 1
                ex['ind'] = upd(ex['ind'], kx, v); return self.fence('pub') + [('SI', k, v)]
            return []
        if s == 'QUIET':
            mark = (E, ex['consp'][kx])
            if ex['ind'][kx] != mark:
                ex['ind'] = upd(ex['ind'], kx, mark); return self.fence('pub') + [('SI', k, mark)]
            return []
        if s in ('DEFER', 'SEEDS'):
            ops = []
            if ex['unack'][kx] > 0:
                ex['consp'] = upd(ex['consp'], kx, ex['consp'][kx] + ex['unack'][kx])
                ex['unack'] = upd(ex['unack'], kx, 0)
                ops += self.fence('pub') + self.cons_store_ops(ex, k)
            if s == 'DEFER' and ex['ind'][kx] != E:
                ex['ind'] = upd(ex['ind'], kx, E)
                ops += ([] if ops else self.fence('pub')) + [('SI', k, E)]
            return ops
        if s == 'EARLY':
            return []
        if s == 'FLAGD':
            ops = []
            if ex['unack'][kx] > 0:
                ex['consp'] = upd(ex['consp'], kx, ex['consp'][kx] + ex['unack'][kx])
                ex['unack'] = upd(ex['unack'], kx, 0)
                ops += self.fence('pub') + self.cons_store_ops(ex, k)
            if ex['ind'][kx] != 1:
                ex['ind'] = upd(ex['ind'], kx, 1)
                ops += ([] if ops else self.fence('pub')) + [('SI', k, 1)]
            return ops
        if s == 'CREDIT':
            if ex['held'][kx] > 0:
                ex['ret'] = upd(ex['ret'], kx, ex['ret'][kx] + ex['held'][kx])
                ex['held'] = upd(ex['held'], kx, Fraction(0))
                return self.fence('pub') + [('SR', k, ex['ret'][kx])]
            return []
        raise ValueError(s)

    def fire_ops(self, ex, i, item):
        home, reg, effs = self.items[item]
        ops = []
        for e in effs:
            if e[0] == 'send':
                cell, deps = e[2][1], e[2][2]
                ops += self.send_ops(ex, i, e[1], ('delta', self.w['cells'][cell][1], cell, deps))
            elif e[0] == 'write':
                ops += self.write_ops(e[1])
            elif e[0] == 'enq':
                ops.append(('ENQ', e[1]))
            elif e[0] == 'freq':
                ops += self.freq_ops(ex, i, e[1])
            elif e[0] == 'contra':
                ops.append(('SCW',))
        return ops

    def write_ops(self, cell):
        lc = self.c.latecheck
        if lc == 'CTW':
            return [('LBC', cell)]                # load boundary; store only if not late (else flag)
        if lc == 'WTC':
            return [('W', cell), ('LBW', cell)]
        if lc == 'WTCF':
            return [('W', cell), ('F',), ('LBW', cell)]
        return [('W', cell)]

    def freq_ops(self, ex, i, item):
        dst = self.items[item][0]
        reg = self.items[item][1]
        if dst == i:
            return [('ENQ', item)]
        if self.c.fr == 'counted':
            return self.send_ops(ex, i, dst, ('wake', reg, item, None))
        if self.c.fr == 'uncounted':
            return [('PUSH', dst, item)]
        return [('LOST', item)]

    def send_ops(self, ex, i, dst, msg):
        # msg = (kind, region, payload, deps); the credit is attached when the lane store executes
        k = self.rk(msg[1])
        kx = self.ki(k)
        ex['prod'] = upd(ex['prod'], kx, ex['prod'][kx] + 1)     # this send's running count, embedded in SP
        if self.c.repr == 'LOG':
            return [('SL', dst, msg)]
        if self.c.sendorder == 'lane-prod':
            return [('SL', dst, msg)] + self.fence('send') + [('SP', k, ex['prod'][kx])]
        return [('SP', k, ex['prod'][kx])] + self.fence('send') + [('SL', dst, msg)]

    # ---- the executor step ----
    def exec_succ(self, st, i):
        execs, det, mem, sched, ev = st
        ex0 = self.thaw_ex(execs[i])
        out = []
        # buffer drains
        for n in self.flushes(ex0['buf']):
            a, v = ex0['buf'][n]
            m = list(mem); m[self.ix[a]] = v
            buf = ex0['buf'][:n] + ex0['buf'][n + 1:]
            ex = dict(ex0); ex['buf'] = buf
            ev2 = ev
            dd = self.thaw_det(det)
            if a[0] == 'X' and dd['phase'] in ('handler', 'done') and dd['why'] == 'contra':
                ev2 = ev + ('RACE',) if 'RACE' not in ev else ev
            out.append((self.set_ex(st, i, ex, mem=tuple(m), ev=ev2), f'{"ABC"[i]}~{fmt_addr(a)}'))
        if ex0['halted']:
            return out
        # program step: run private ops instantly, then one shared op
        ex = dict(ex0)
        self.cur_i = i
        mem2, ev2, extra = mem, ev, None
        label = None
        guard = 0
        while True:
            guard += 1
            if guard > 200:
                raise RuntimeError('private loop')
            if not ex['todo']:
                ex['todo'] = self.top_ops(i)
            op, rest = ex['todo'][0], ex['todo'][1:]
            kind = op[0]
            if kind == 'POSTDRAIN':
                ops = []
                for k in self.keys:
                    if ex['n'][self.ki(k)] > 0:
                        ops += self.consume_pub(ex, k)
                ex['n'] = tuple(0 for _ in self.keys)
                ex['todo'] = tuple(ops) + rest
                continue
            if kind == 'POP':
                ops = []
                keys_with_work = {self.rk(self.items[it][1]) for it in ex['wl']}
                for k in self.keys:
                    if k not in keys_with_work:
                        ops += self.idle_pub(ex, k)
                if ex['wl']:
                    item, ex['wl'] = ex['wl'][0], ex['wl'][1:]
                    d = self.thaw_det(det)
                    if d['done'] or d['phase'] in ('handler',):
                        ex['fired_after'] = True
                    ops += self.fire_ops(ex, i, item)
                    label = f'{"ABC"[i]}:fire {item}'
                ex['todo'] = tuple(ops) + self.top_ops(i)
                if label is not None and not ops:
                    pass
                continue
            if kind == 'ENQ':
                ex['wl'] = ex['wl'] + (op[1],)
                ex['todo'] = rest
                continue
            if kind == 'LOST':
                ex['todo'] = rest
                continue
            break
        # shared op
        pre = label
        buf = ex['buf']
        if kind == 'F':
            if buf:
                return out          # blocked until the buffer drains
            ex['todo'] = rest
            label = (label + '; ' if label else '') + f'{"ABC"[i]}:FENCE'
        elif kind == 'LCW':
            v = self.load(mem, buf, ('CW',))
            if v:
                ops = []
                if self.c.boundary == 'QCH':
                    ops = self.fence('park') + [('SPK',)]
                ex['todo'] = tuple(ops) + (('HALT',),)
                label = f'{"ABC"[i]}:sees CW -> stop'
            else:
                ex['todo'] = rest
                label = f'{"ABC"[i]}:CW=0'
        elif kind == 'HALT':
            ex['halted'] = True; ex['todo'] = ()
            label = f'{"ABC"[i]}:halted'
        elif kind == 'LL':
            s = op[1]
            sx = self.srcs[i].index(s)
            log = self.load(mem, buf, ('L', i, s))
            new = log[ex['cur'][sx]:]
            ops = []
            nn = list(ex['n']); held = list(ex['held'])
            for msg in new:
                mk, reg, payload, deps = msg[0], msg[1], msg[2], msg[3]
                kx = self.ki(self.rk(reg))
                nn[kx] += 1
                if self.c.scheme == 'CREDIT':
                    held[kx] += msg[4]
                if mk == 'delta':
                    ops += [('J', payload)]                 # the owner's join = a store of its cell
                    for dep in deps:
                        ops += self.freq_ops(ex, i, dep) if self.items[dep][0] != i else [('ENQ', dep)]
                else:  # wake / seed
                    ops.append(('ENQ', payload))
            ex['n'] = tuple(nn); ex['held'] = tuple(held)
            ex['cur'] = upd(ex['cur'], sx, len(log))
            ex['todo'] = tuple(ops) + rest
            label = f'{"ABC"[i]}:drain {"ABCS"[s] if s != "S" else "S"}({len(new)})'
        elif kind in ('W', 'J'):
            mem2, buf = self.store(mem, buf, ('X', op[1]), 1)
            ex['todo'] = rest
            d = self.thaw_det(det)
            if self.c.mem == 'SC' and d['why'] == 'contra' and d['phase'] in ('handler', 'done'):
                ev2 = ev + ('RACE',) if 'RACE' not in ev else ev
            label = f'{"ABC"[i]}:write {op[1]}'
        elif kind in ('LBC', 'LBW'):
            reg = self.w['cells'][op[1]][1]
            bv = self.load(mem, buf, ('B',))
            late = self.is_late(bv, reg)
            if kind == 'LBC':
                if late:
                    ex['late'] = True
                    ex['todo'] = rest
                    label = f'{"ABC"[i]}:check B={bv} -> LATE (write suppressed)'
                else:
                    ex['todo'] = (('W', op[1]),) + rest
                    label = f'{"ABC"[i]}:check B={bv} ok'
            else:
                if late:
                    ex['late'] = True
                ex['todo'] = rest
                label = f'{"ABC"[i]}:check-after-write B={bv}{" LATE" if late else ""}'
        elif kind == 'SL':
            dst, msg = op[1], op[2]
            if self.c.scheme == 'CREDIT':
                kx = self.ki(self.rk(msg[1]))
                h = ex['held'][kx]
                give = h / 2
                ex['held'] = upd(ex['held'], kx, h - give)
                msg = msg + (give,)
            else:
                msg = msg + (0,)
            log = ex['out'][dst] + (msg,)
            ex['out'] = upd(ex['out'], dst, log)
            mem2, buf = self.store(mem, buf, ('L', dst, i), log)
            ex['todo'] = rest
            label = f'{"ABC"[i]}:send {msg[0]}->{"ABC"[dst]}'
        elif kind == 'SP':
            mem2, buf = self.store(mem, buf, ('P', op[1], i), op[2])
            ex['todo'] = rest
            label = f'{"ABC"[i]}:prod={op[2]}'
        elif kind == 'SC':
            mem2, buf = self.store(mem, buf, ('C', op[1], i), op[2])
            ex['todo'] = rest
            label = f'{"ABC"[i]}:cons={op[2]}'
        elif kind == 'SH':
            mem2, buf = self.store(mem, buf, ('H', i, op[1]), op[2])
            ex['todo'] = rest
            label = f'{"ABC"[i]}:head[{op[1]}]={op[2]}'
        elif kind == 'SI':
            mem2, buf = self.store(mem, buf, ('I', op[1], i), op[2])
            ex['todo'] = rest
            label = f'{"ABC"[i]}:ind={op[2]}'
        elif kind == 'SR':
            mem2, buf = self.store(mem, buf, ('R', op[1], i), op[2])
            ex['todo'] = rest
            label = f'{"ABC"[i]}:returned={op[2]}'
        elif kind == 'SCW':
            mem2, buf = self.store(mem, buf, ('CW',), 1)
            ex['todo'] = rest
            label = f'{"ABC"[i]}:CONTRADICTION'
        elif kind == 'SPK':
            mem2, buf = self.store(mem, buf, ('PK', i), 1)
            ex['todo'] = rest
            label = f'{"ABC"[i]}:parked'
        elif kind == 'PUSH':
            dst, item = op[1], op[2]
            ex['todo'] = rest
            execs2 = list(execs)
            o = self.thaw_ex(execs2[dst]); o['wl'] = o['wl'] + (item,)
            execs2[dst] = self.freeze_ex(o)
            st = (tuple(execs2), det, mem, sched, ev)
            label = f'{"ABC"[i]}:push {item}->{"ABC"[dst]} (uncounted)'
        else:
            raise ValueError(op)
        ex['buf'] = buf
        if pre and pre != label:
            label = pre + ': ' + label.split(':', 1)[1]
        out.append((self.set_ex(st, i, ex, mem=mem2, ev=ev2), label))
        return out

    def is_late(self, bv, reg):
        # per-network tags: B holds the max closed region-epoch per network (here: a set of closed regions);
        # process-wide tag: B is one max-counter of closed epochs and every network numbers its epochs from 1
        if self.c.tag == 'per-network':
            return reg in (bv or ())
        return (bv or 0) >= E

    def set_ex(self, st, i, ex, mem=None, ev=None):
        execs, det, m, sched, e = st
        execs = list(execs); execs[i] = self.freeze_ex(ex)
        return (tuple(execs), det, m if mem is None else mem, sched, e if ev is None else ev)

    # ---- the detector ----
    def scan_list(self, regs):
        c = self.c
        ks = sorted({self.rk(r) for r in regs})
        lst = []
        if self.w['contra'] and c.boundary in ('QC', 'QCH'):
            lst.append(('CW',))
        if c.scheme == 'CREDIT':
            for i in range(self.K):
                for k in ks:
                    lst.append(('R', k, i))
            return lst
        if c.repr == 'LOG':
            # heads first, then logs (a head never exceeds the log it was read from)
            for i in range(self.K):
                for s in self.srcs[i]:
                    lst.append(('H', i, s))
            for i in range(self.K):
                for s in self.srcs[i]:
                    lst.append(('L', i, s))
            if c.scheme not in ('SEEDS', 'EARLY'):
                for i in range(self.K):
                    for k in ks:
                        lst.append(('I', k, i))
            return lst
        if c.readord == 'CSPLIT':
            # one pass: every cons word first, then every prod word, then any indicator words
            lst += [('C', k, i) for i in range(self.K) for k in ks]
            lst += [('P', k, i) for i in range(self.K) for k in ks]
            if c.scheme not in ('SEEDS', 'EARLY'):
                lst += [('I', k, i) for i in range(self.K) for k in ks]
            return lst
        for i in range(self.K):
            for k in ks:
                words = {'P': ('P', k, i), 'C': ('C', k, i), 'I': ('I', k, i)}
                for ch in (c.readord if c.readord != 'ANY' else 'PCI'):
                    if ch == 'I' and c.scheme in ('SEEDS', 'EARLY'):
                        continue
                    lst.append(words[ch])
        return lst

    def evaluate(self, regs, reads, sched):
        """the scheme's predicate over one scan's readings"""
        c = self.c
        ks = sorted({self.rk(r) for r in regs})
        rd = dict(reads)
        if c.scheme == 'CREDIT':
            return sum(rd[('R', k, i)] for i in range(self.K) for k in ks) == 1
        if c.repr == 'LOG':
            prod = cons = 0
            for i in range(self.K):
                for s in self.srcs[i]:
                    log = rd[('L', i, s)]
                    h = rd[('H', i, s)]
                    prod += sum(1 for m in log if self.rk(m[1]) in ks) if s != 'S' else 0
                    cons += sum(1 for m in log[:h] if self.rk(m[1]) in ks)
            prod += sum(sched[self.keys.index(k)] for k in ks)
            P, Cc = prod, cons
        else:
            P = sum(rd[('P', k, i)] for i in range(self.K) for k in ks) + sum(sched[self.keys.index(k)] for k in ks)
            Cc = sum(rd[('C', k, i)] for i in range(self.K) for k in ks)
        if P != Cc:
            return False
        if c.scheme in ('SEEDS', 'EARLY'):
            return True
        for i in range(self.K):
            for k in ks:
                v = rd[('I', k, i)]
                if c.scheme in ('D2', 'DEFER') and v != E: return False
                if c.scheme in ('FLAG', 'FLAGD') and v != 1: return False
                if c.scheme == 'ACT' and v % 2 != 0: return False
                if c.scheme == 'QUIET':
                    cons_i = rd[('C', k, i)] if c.repr == 'SEP' else None
                    if c.repr == 'LOG':
                        cons_i = sum(sum(1 for m in rd[('L', i, s)][:rd[('H', i, s)]] if self.rk(m[1]) == k) for s in self.srcs[i])
                    if v != (E, cons_i): return False
        return True

    def det_succ(self, st):
        execs, det, mem, sched, ev = st
        d = self.thaw_det(det)
        out = []
        # detector's own store buffer (boundary word)
        for n in self.flushes(d['buf']):
            a, v = d['buf'][n]
            m = list(mem); m[self.ix[a]] = v
            d2 = dict(d); d2['buf'] = d['buf'][:n] + d['buf'][n + 1:]
            out.append(((execs, self.freeze_det(d2), tuple(m), sched, ev), f'D~{fmt_addr(a)}'))
        if d['phase'] == 'done':
            return out
        regs = self.tasks[d['task']]
        d = dict(d)
        if d['phase'] == 'scan':
            lst = self.scan_list(regs)
            if self.c.readord == 'ANY' and len(d['reads']) < len(lst) and not (self.w['contra'] and self.c.boundary in ('QC', 'QCH') and not d['reads']):
                # the detector may read the unread words of this scan in ANY order (ARM load-load reordering);
                # readings are kept sorted by address so the order they were taken in is not part of the state
                done_a = {x[0] for x in d['reads']}
                for a in lst:
                    if a in done_a:
                        continue
                    v = self.load(mem, d['buf'], a)
                    reads = tuple(sorted(d['reads'] + ((a, v),), key=lambda x: lst.index(x[0])))
                    out += self.after_read(st, d, regs, lst, a, v, reads, execs, mem, sched, ev)
                return out
            n = len(d['reads'])
            a = lst[n]
            v = self.load(mem, d['buf'], a)
            reads = d['reads'] + ((a, v),)
            return out + self.after_read(st, d, regs, lst, a, v, reads, execs, mem, sched, ev)
        return self.det_rest(st, d, out)

    def after_read(self, st, d0, regs, lst, a, v, reads, execs, mem, sched, ev):
        out = []
        d = dict(d0)
        if True:
            label = f'D:read {fmt_addr(a)}={fmtv(v)}'
            if a == ('CW',) and v:
                # contradiction boundary
                d['why'] = 'contra'
                if self.c.boundary == 'QCH':
                    d['phase'] = 'waitpark'; d['reads'] = ()
                else:
                    d['phase'] = 'handler'; d['reads'] = ()
                out.append(((execs, self.freeze_det(d), mem, sched, ev), label + ' -> CONTRADICTION BOUNDARY'))
                return out
            if len(reads) < len(lst):
                d['reads'] = reads
                out.append(((execs, self.freeze_det(d), mem, sched, ev), label))
                return out
            # a full scan
            if self.c.scans == 1 or d['scan1'] is not None:
                ok = self.evaluate(regs, reads, sched) and (self.c.scans == 1 or tuple(x for x in reads if x[0] != ('CW',)) == tuple(x for x in d['scan1'] if x[0] != ('CW',)))
                if ok:
                    d['phase'] = 'declare'; d['reads'] = (); d['scan1'] = None; d['why'] = 'quiescent'
                    prem = self.premature(st, regs)
                    ev2 = ev
                    if prem:
                        ev2 = ev + (('PREMATURE', d['task']),)
                    elif not self.fixpoint_ok(st, regs):
                        ev2 = ev + (('WRONGFIX', d['task']),)
                    out.append(((execs, self.freeze_det(d), mem, sched, ev2), label + f' -> DECLARE {regs}'))
                else:
                    # slide: this scan becomes the first scan of the next pair
                    d['scan1'] = reads if self.c.scans == 2 else None; d['reads'] = ()
                    out.append(((execs, self.freeze_det(d), mem, sched, ev), label))
            else:
                d['scan1'] = reads; d['reads'] = ()
                out.append(((execs, self.freeze_det(d), mem, sched, ev), label))
            return out

    def det_rest(self, st, d, out):
        execs, det, mem, sched, ev = st
        regs = self.tasks[d['task']]
        if d['phase'] == 'waitpark':
            n = len(d['reads'])
            v = self.load(mem, d['buf'], ('PK', n))
            label = f'D:read parked{"ABC"[n]}={v}'
            if not v:
                d['reads'] = ()
            else:
                d['reads'] = d['reads'] + ((n, v),)
                if len(d['reads']) == self.K:
                    d['phase'] = 'handler'; d['reads'] = ()
                    label += ' -> all parked: handler'
            out.append(((execs, self.freeze_det(d), mem, sched, ev), label))
            return out
        if d['phase'] == 'declare':
            # boundary-epoch store (only modelled when the late-write check is on), then the handler
            if self.c.latecheck:
                if self.c.tag == 'per-network':
                    cur = self.load(mem, d['buf'], ('B',)) or ()
                    nv = tuple(sorted(set(cur) | set(regs)))
                else:
                    nv = E
                m2, b2 = self.store(mem, d['buf'], ('B',), nv)
                d['buf'] = b2
                d['phase'] = 'detfence' if self.c.detfence else 'handler'
                out.append(((execs, self.freeze_det(d), m2, sched, ev), f'D:boundary-epoch:={nv}'))
                return out
            d['phase'] = 'handler'
            return self.det_succ((execs, self.freeze_det(d), mem, sched, ev))
        if d['phase'] == 'detfence':
            if d['buf']:
                return out
            d['phase'] = 'handler'
            out.append(((execs, self.freeze_det(d), mem, sched, ev), 'D:FENCE'))
            return out
        if d['phase'] == 'handler':
            cells = [c for c, (o, r) in sorted(self.w['cells'].items()) if r in regs]
            n = len(d['hread'])
            if n < len(cells):
                v = self.load(mem, d['buf'], ('X', cells[n]))
                d['hread'] = d['hread'] + ((cells[n], v),)
                ev2 = ev
                if d['why'] == 'quiescent' and v < self.w['expected'][cells[n]]:
                    ev2 = ev + (('STALE', d['task'], cells[n]),)
                out.append(((execs, self.freeze_det(d), mem, sched, ev2), f'D:handler reads {cells[n]}={v}'))
                return out
            # handler done: next task (a nested run is seeded by this handler) or finished
            mem2 = mem; sched2 = sched
            label = 'D:handler done'
            for r in regs:
                for (ex_i, item) in self.w['nested'].get(r, []):
                    reg = self.items[item][1]
                    a = ('L', ex_i, 'S')
                    log = self.load(mem2, (), a) + (('seed', reg, item, None, Fraction(1, len(self.w['nested'][r]))),)
                    m = list(mem2); m[self.ix[a]] = log; mem2 = tuple(m)
                    sc = list(sched2); sc[self.keys.index(self.rk(reg))] += 1; sched2 = tuple(sc)
                    label += f'; seeds nested {item}'
            d['hread'] = ()
            if d['task'] + 1 < len(self.tasks) and d['why'] != 'contra':
                d['task'] += 1; d['phase'] = 'scan'; d['why'] = None
            else:
                d['phase'] = 'done'; d['done'] = True
            out.append(((execs, self.freeze_det(d), mem2, sched2, ev), label))
            return out
        raise ValueError(d['phase'])

    # ---- ground truth ----
    def pending_work(self, st, regs):
        execs, det, mem, sched, ev = st
        ks = {self.rk(r) for r in regs}
        for i, t in enumerate(execs):
            ex = self.thaw_ex(t)
            if any(self.items[it][1] in regs for it in ex['wl']):
                return f'{"ABC"[i]} has work {ex["wl"]}'
            # mid-fire: any effect op of these regions still to do
            for op in ex['todo']:
                r = self.op_region(op)
                if r is ANY or (r is not None and r in regs):
                    return f'{"ABC"[i]} is mid-fire ({op[0]})'
        for i in range(self.K):
            ex = self.thaw_ex(execs[i])
            for sx, s in enumerate(self.srcs[i]):
                if s == 'S':
                    log = mem[self.ix[('L', i, 'S')]]
                else:
                    log = self.thaw_ex(execs[s])['out'][i]
                if any(m[1] in regs for m in log[ex['cur'][sx]:]):
                    return f'message to {"ABC"[i]} unconsumed'
        return None

    def op_region(self, op):
        k = op[0]
        if k in ('W', 'J', 'LBC', 'LBW'):
            return self.w['cells'][op[1]][1]
        if k == 'SL':
            return op[2][1]
        if k == 'ENQ':
            return self.items[op[1]][1]
        if k == 'PUSH':
            return self.items[op[2]][1]
        if k == 'SCW':
            return ANY
        return None

    def premature(self, st, regs):
        return self.pending_work(st, regs)

    def fixpoint_ok(self, st, regs):
        execs, det, mem, sched, ev = st
        # the cells' program values (memory or a buffered store) must equal the least fixpoint
        for c, (o, r) in self.w['cells'].items():
            if r not in regs:
                continue
            ex = self.thaw_ex(execs[o])
            v = self.load(mem, ex['buf'], ('X', c))
            if v < self.w['expected'][c]:
                return False
        return True

    def settled(self, st):
        execs, det, mem, sched, ev = st
        if not self.thaw_det(det)['done']:
            return False
        if self.pending_work(st, set(self.R)):
            return False
        for t in execs:
            ex = self.thaw_ex(t)
            if ex['buf']:
                return False
        return not self.thaw_det(det)['buf']

    # ---- exploration ----
    def successors(self, st):
        execs, det, mem, sched, ev = st
        out = []
        if self.thaw_det(det)['done'] and not self.c.post:
            return out
        for i in range(self.K):
            out += self.exec_succ(st, i)
        out += self.det_succ(st)
        return out


def upd(t, i, v):
    l = list(t); l[i] = v; return tuple(l)


def fmt_addr(a):
    n = {0: 'A', 1: 'B', 2: 'C', 'S': 'S'}
    if a[0] in ('P', 'C', 'I', 'R'):
        return f'{a[0]}{n[a[2]]}' + (f'[r{a[1]}]' if a[1] else '')
    if a[0] in ('L', 'H'):
        return f'{a[0]}[{n[a[1]]}<-{n[a[2]]}]'
    if a[0] == 'PK':
        return f'parked{n[a[1]]}'
    if a[0] == 'X':
        return a[1]
    return a[0]


def fmtv(v):
    if isinstance(v, tuple) and v and isinstance(v[0], tuple):
        return f'log{len(v)}'
    if isinstance(v, Fraction):
        return str(v)
    return str(v)


def explore(wl_name, cfg, max_states=3_000_000, want_live=True):
    wl = WORKLOADS[wl_name]
    m = Model(wl, cfg)
    s0 = m.initial()
    ids = {s0: 0}
    states = [s0]
    parent = [None]
    succs = []
    q = deque([0])
    first = {}
    done_ids = []
    while q:
        sid = q.popleft()
        st = states[sid]
        lst = []
        for (n, lab) in m.successors(st):
            nid = ids.get(n)
            if nid is None:
                nid = len(states)
                ids[n] = nid
                states.append(n)
                parent.append((sid, lab))
                q.append(nid)
                if len(states) > max_states:
                    raise RuntimeError(f'state limit {max_states}')
                for e in n[4]:
                    tag = e if isinstance(e, str) else e[0]
                    if tag not in first:
                        first[tag] = nid
            lst.append(nid)
        succs.append(lst)
        d = m.thaw_det(st[1])
        if d['done']:
            done_ids.append(sid)
    # late-write outcomes (settled states only)
    late = {}
    if cfg.latecheck:
        # STALE marks a stale handler read; a settled state with STALE and no late flag is a MISSED late write
        for sid, st in enumerate(states):
            if not m.settled(st):
                continue
            stale = any(not isinstance(e, str) and e[0] == 'STALE' for e in st[4])
            flagged = any(m.thaw_ex(t)['late'] for t in st[0])
            key = 'MISSED' if stale and not flagged else ('CAUGHT' if flagged else 'clean')
            if key not in late:
                late[key] = sid
    # liveness: every reachable state can reach a done state
    stuck = None
    if want_live:
        pred = [[] for _ in states]
        for a, lst in enumerate(succs):
            for b in lst:
                pred[b].append(a)
        good = [False] * len(states)
        dq = deque()
        for sid, st in enumerate(states):
            if m.thaw_det(st[1])['done']:
                good[sid] = True; dq.append(sid)
        while dq:
            b = dq.popleft()
            for a in pred[b]:
                if not good[a]:
                    good[a] = True; dq.append(a)
        bad = [sid for sid in range(len(states)) if not good[sid]]
        if bad:
            stuck = bad[0]
    return dict(model=m, states=states, parent=parent, first=first, stuck=stuck, late=late,
                n=len(states), declares=len(done_ids) > 0)


def trace(res, sid):
    out = []
    parent = res['parent']
    while parent[sid] is not None:
        p, lab = parent[sid]
        out.append(lab)
        sid = p
    return list(reversed(out))


def report(wl_name, cfg, show=True, **kw):
    res = explore(wl_name, cfg, **kw)
    f = res['first']
    verdict = []
    for tag in ('PREMATURE', 'WRONGFIX', 'STALE', 'RACE'):
        if tag in f:
            verdict.append(tag)
    live = res['stuck'] is None
    if not live:
        verdict.append('NOT-LIVE')
    if cfg.latecheck:
        verdict.append('late:' + '/'.join(sorted(res['late'])))
    v = 'sound+live' if not verdict else ' '.join(verdict)
    line = f'{wl_name:8s} {cfg.label():78s} states={res["n"]:7d}  {v}'
    print(line)
    if show:
        for tag in ('PREMATURE', 'WRONGFIX', 'STALE', 'RACE'):
            if tag in f:
                t = trace(res, f[tag])
                print(f'    {tag} witness ({len(t)} steps): ' + ' ; '.join(t))
                break
        if not live and not any(t in f for t in ('PREMATURE', 'WRONGFIX', 'STALE', 'RACE')):
            t = trace(res, res['stuck'])
            print(f'    NOT-LIVE witness ({len(t)} steps to a state that can never reach the boundary): ' + ' ; '.join(t))
        if cfg.latecheck and 'MISSED' in res['late']:
            t = trace(res, res['late']['MISSED'])
            print(f'    MISSED-late-write witness ({len(t)} steps): ' + ' ; '.join(t))
    sys.stdout.flush()
    return dict(verdict=v, n=res['n'], live=live, first=list(f), late=sorted(res['late']))
