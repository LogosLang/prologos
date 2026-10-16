#!/usr/bin/env python3
"""C5 (PAR 4 D.3, Theory) — exhaustive interleaving check of D.2 §6.7's quiescence detector.

Model: two executors A, B and a detector thread. Each executor step is atomic: pop+fire one local task,
or drain one lane message, or go idle. The detector reads one executor's (prod, cons, indicator) per
step (an atomic per-executor read: GENEROUS to the scheme), does two full scans, then evaluates.
A declaration is FALSE if any worklist or lane is non-empty at that instant.

Detector variants (indicator read per executor):
  D2      idle-epoch_i: a max-counter set to e when i goes idle (D.2 §6.7, §9 `idle-epoch`); never lowered in e
  D1      a resettable busy flag (D.1 §5.4 `idle_i`; the scheme benchmarks/par4/detect.rkt measured)
  ACT     a monotone activity counter: +1 on every idle<->busy transition, idle iff even (proposed fix)
  D2-ACK  D.2's idle-epoch, but cons_i is published only when i goes idle (deferred acknowledgement)
Workloads:
  S1  p@A writes cell c owned by B (lane delta); B's join of c enqueues q1@B; q1 enqueues q2@B (a LOCAL cascade)
  S2u p@A writes its own cell c; c's dependent q is homed on B; the fire request is an UNCOUNTED push to B's worklist
      (D.2's Lane type is Set [CellId Delta]: it carries no fire requests)
  S2c the same fire request sent as a COUNTED lane message (D.1 §5.3)
  S3  as S1 but p also writes the contradiction cell; executors stop at their next lane check (D.2 §6.7)
"""
import sys
from collections import deque

def initial(workload):
    # executor: (wl, lane, prod, cons, unacked, busy, act, idle_ep, stopped)
    A = (('p',), 0, 0, 0, 0, True, 1, 0, False)
    B = ((), 0, 0, 0, 0, True, 1, 0, False)
    return (A, B, 0, (), False)  # (A, B, detector phase, detector readings, contradiction)

def exec_step(st, i, workload, variant):
    ex = list(st[:2]); phase, reads, contra = st[2], st[3], st[4]
    me = list(ex[i]); other = 1 - i
    wl, lane, prod, cons, unacked, busy, act, idle_ep, stopped = me
    if stopped:
        return None
    if contra and workload == 'S3':
        me[8] = True  # sees contradiction at its next lane check and stops
        ex[i] = tuple(me); return (ex[0], ex[1], phase, reads, contra)
    ack_deferred = (variant == 'D2-ACK')
    if wl:
        if not busy:
            busy = True; act += 1
        t, wl = wl[0], wl[1:]
        o = list(ex[other])
        if t == 'p':
            if workload in ('S1', 'S3'):
                o[1] += 1; prod += 1  # delta to B's lane
                if workload == 'S3':
                    contra = True
            elif workload == 'S2u':
                o[0] = o[0] + ('q',)  # uncounted fire request pushed onto B's worklist
            elif workload == 'S2c':
                o[1] += 1; prod += 1  # counted fire request
        elif t == 'q1':
            wl = wl + ('q2',)
        # 'q2', 'q' : no effects
        ex[other] = tuple(o)
        me = [wl, lane, prod, cons, unacked, busy, act, idle_ep, stopped]
    elif lane > 0:
        if not busy:
            busy = True; act += 1
        lane -= 1
        if ack_deferred:
            unacked += 1
        else:
            cons += 1
        # the owner joins the delta / takes the fire request
        if workload in ('S1', 'S3'):
            wl = wl + ('q1',)
        elif workload == 'S2c':
            wl = wl + ('q',)
        me = [wl, lane, prod, cons, unacked, busy, act, idle_ep, stopped]
    elif busy:
        busy = False; act += 1; idle_ep = 1; cons += unacked; unacked = 0
        me = [wl, lane, prod, cons, unacked, busy, act, idle_ep, stopped]
    else:
        return None
    ex[i] = tuple(me)
    return (ex[0], ex[1], phase, reads, contra)

def indicator(e, variant):
    wl, lane, prod, cons, unacked, busy, act, idle_ep, stopped = e
    if variant in ('D2', 'D2-ACK'):
        return idle_ep
    if variant == 'D1':
        return 0 if busy else 1
    if variant == 'ACT':
        return act

def ind_ok(v, variant):
    if variant in ('D2', 'D2-ACK'):
        return v == 1
    if variant == 'D1':
        return v == 1
    if variant == 'ACT':
        return v % 2 == 0

def det_step(st, variant):
    A, B, phase, reads, contra = st
    ex = (A, B)
    if phase < 4:
        e = ex[phase % 2]
        r = (e[2], e[3], indicator(e, variant))
        return (A, B, phase + 1, reads + (r,), contra), False
    # evaluate
    s1, s2 = reads[0:2], reads[2:4]
    ok = (s1 == s2
          and sum(r[0] for r in s1) == sum(r[1] for r in s1)
          and all(ind_ok(r[2], variant) for r in s1))
    if ok:
        return (A, B, 5, reads, contra), True
    return (A, B, 0, (), contra), False

def truly_quiescent(st):
    A, B = st[0], st[1]
    return not A[0] and not B[0] and A[1] == 0 and B[1] == 0

def check(workload, variant):
    start = initial(workload)
    seen = {start}; q = deque([(start, None)])
    parent = {start: None}
    false_decl = None; any_decl = False
    while q:
        st, _ = q.popleft()
        if st[2] == 5:
            continue  # declared: terminal
        succs = []
        for i in (0, 1):
            n = exec_step(st, i, workload, variant)
            if n is not None:
                succs.append((n, f"{'AB'[i]}"))
        n, declared = det_step(st, variant)
        succs.append((n, 'D-declare' if declared else 'D'))
        for n, lab in succs:
            if lab == 'D-declare':
                any_decl = True
                if not truly_quiescent(n) and false_decl is None:
                    false_decl = (n, st)
            if n not in seen:
                seen.add(n); parent[n] = (st, lab); q.append((n, lab))
    trace = None
    if false_decl:
        n, st = false_decl
        path = ['D-declare']; cur = st
        while parent[cur] is not None:
            p, lab = parent[cur]; path.append(lab); cur = p
        trace = list(reversed(path))
        A, B = n[0], n[1]
        trace_state = f"at declaration: A.wl={A[0]} A.lane={A[1]} B.wl={B[0]} B.lane={B[1]}"
    return len(seen), any_decl, trace, (trace_state if false_decl else None)

if __name__ == '__main__':
    print(__doc__.strip().splitlines()[0])
    for workload in ('S1', 'S2u', 'S2c', 'S3'):
        for variant in ('D2', 'D1', 'ACT', 'D2-ACK'):
            nstates, any_decl, trace, ts = check(workload, variant)
            verdict = 'FALSE QUIESCENCE reachable' if trace else ('sound' if any_decl else 'NEVER DECLARES (liveness)')
            print(f"{workload:4s} {variant:7s} states={nstates:6d} declares={'y' if any_decl else 'n'}  {verdict}")
            if trace:
                print(f"       shortest trace: {' '.join(trace)}")
                print(f"       {ts}")
