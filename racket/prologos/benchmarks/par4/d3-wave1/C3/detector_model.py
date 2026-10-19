#!/usr/bin/env python3
"""C3 probe: exhaustive interleaving check of D.2 §6.7 / §9's quiescence detector on a 2-executor model.

Model (one S0 epoch e = 1).  Executor state: worklist (local items), inbound lane (messages),
prod, cons, mark.  One atomic executor step is one of:
  DRAIN  : top of loop — take every inbound message, cons += n, join, enqueue each message's local
           dependents (D.2 §6.7: "the owner drains its K−1 lanes at the top of each loop iteration and joins")
  FIRE   : pop one local item and fire it (may send messages: prod += 1 per message)
  IDLE   : worklist and lanes empty -> write the idle mark (a max-merged cell)
The detector reads ONE executor's (prod, cons, mark) per step (the realization is per-executor
padded slots, D.2 §6.7), scans all executors twice, and declares quiescence iff the two scans are
identical, sum(prod) == sum(cons), and every executor is "idle" by its mark.
PREMATURE = declared while some executor still has a worklist item or an undelivered message.

Variants:
  mark=epoch      : D.2 §9 `idle-epoch : Cell (Vec K Epoch)`, idle iff mark == e
  mark=epoch+cons : fix: mark = (e, cons at the moment of going idle), idle iff mark == (e, cons)
  fr=counted|uncounted|none : how a change on owner A notifies a dependent homed on B
     (D.1 §5.3 had counted "fire requests"; D.2's Lane = Set [CellId Delta] has none).
Scenarios:
  S1: A fires an item that sends a DELTA to B; B's drained delta enqueues one local dependent.
  S2: A fires an item writing A's own cell whose dependent is homed on B (a notification).
"""
import itertools, sys
from collections import deque

def run(scenario, mark_kind, fr_kind):
    E = 1
    # executor tuple: (wl tuple, lane tuple, prod, cons, mark)
    def mk(wl): return (tuple(wl), tuple(), 0, 0, (0, 0) if mark_kind == 'epoch+cons' else 0)
    if scenario == 'S1':
        execs = (mk(['sendB']), mk([]))
    else:
        execs = (mk(['writeA_depB']), mk([]))
    # detector: (scan_no, idx, scan1 tuple, scan2 tuple)
    det0 = (0, 0, (), ())
    start = (execs, det0, False, False)
    seen = set([start]); q = deque([(start, [])])
    found = None; declared_ok = 0; states = 0; wrong = None
    def idle_by_mark(ex):
        _, _, p, c, m = ex
        return (m == (E, c)) if mark_kind == 'epoch+cons' else (m == E)
    while q:
        (execs, det, declared, lost), trace = q.popleft(); states += 1
        if declared:
            busy = any(ex[0] or ex[1] for ex in execs)
            if busy and found is None:
                found = trace
            elif not busy and lost and wrong is None:
                wrong = trace
            elif not busy:
                declared_ok += 1
            continue
        succ = []
        for i in range(2):
            wl, lane, p, c, m = execs[i]
            other = 1 - i
            # DRAIN
            if lane:
                newwl = list(wl)
                for msg in lane:
                    newwl.append('local')       # a delta or a fire request enqueues one local dependent
                ex2 = list(execs); ex2[i] = (tuple(newwl), tuple(), p, c + len(lane), m)
                succ.append((tuple(ex2), f'E{i}:DRAIN({len(lane)})'))
            # FIRE
            if wl:
                item = wl[0]; rest = wl[1:]
                ex2 = list(execs)
                if item == 'sendB':
                    ow = execs[other]
                    ex2[other] = (ow[0], ow[1] + ('delta',), ow[2], ow[3], ow[4])
                    ex2[i] = (rest, lane, p + 1, c, m)
                elif item == 'writeA_depB':
                    ow = execs[other]
                    if fr_kind == 'counted':
                        ex2[other] = (ow[0], ow[1] + ('fire-req',), ow[2], ow[3], ow[4])
                        ex2[i] = (rest, lane, p + 1, c, m)
                    elif fr_kind == 'uncounted':   # pushed straight onto B's worklist
                        ex2[other] = (ow[0] + ('local',), ow[1], ow[2], ow[3], ow[4])
                        ex2[i] = (rest, lane, p, c, m)
                    else:                          # 'none': nobody tells B (D.2 as written)
                        ex2[i] = (rest, lane, p, c, m)
                        succ.append((tuple(ex2), f'E{i}:FIRE({item}) [dependent on B never notified]', 'LOST'))
                        continue
                else:
                    ex2[i] = (rest, lane, p, c, m)
                succ.append((tuple(ex2), f'E{i}:FIRE({item})'))
            # IDLE mark
            if not wl and not lane:
                newm = (E, c) if mark_kind == 'epoch+cons' else E
                if m != newm:
                    ex2 = list(execs); ex2[i] = (wl, lane, p, c, newm)
                    succ.append((tuple(ex2), f'E{i}:IDLE-MARK'))
        # detector step
        scan_no, idx, s1, s2 = det
        ex = execs[idx]
        reading = (ex[2], ex[3], idle_by_mark(ex))
        nd_declared = False
        if scan_no == 0:
            s1n = s1 + (reading,)
            nd = (0, idx + 1, s1n, ()) if idx + 1 < 2 else (1, 0, s1n, ())
        else:
            s2n = s2 + (reading,)
            if idx + 1 < 2:
                nd = (1, idx + 1, s1, s2n)
            else:
                ok = (s1 == s2n and sum(r[0] for r in s2n) == sum(r[1] for r in s2n)
                      and all(r[2] for r in s2n))
                if ok: nd_declared = True
                nd = (0, 0, (), ())       # restart the double scan
        succ.append((execs, f'DET:read E{idx}{" -> DECLARE" if nd_declared else ""}', nd, nd_declared))
        for s in succ:
            if len(s) == 2:
                st = (s[0], det, False, lost); lab = s[1]
            elif len(s) == 3:
                st = (s[0], det, False, True); lab = s[1]
            else:
                st = (s[0], s[2], s[3], lost); lab = s[1]
            if st not in seen:
                seen.add(st); q.append((st, trace + [lab]))
    return found, declared_ok, states, wrong

if __name__ == '__main__':
    rows = [('S1', 'epoch', 'none'), ('S1', 'epoch+cons', 'none'),
            ('S2', 'epoch+cons', 'none'), ('S2', 'epoch+cons', 'uncounted'),
            ('S2', 'epoch+cons', 'counted'), ('S2', 'epoch', 'counted')]
    for sc, mk_, fr in rows:
        found, ok, n, wrong = run(sc, mk_, fr)
        print(f'{sc} mark={mk_:10s} notify={fr:9s} states={n:6d} correct-declarations={ok:5d} '
              f'PREMATURE={"YES" if found else "no"} WRONG-FIXPOINT={"YES" if wrong else "no"}')
        if found:
            print('   shortest premature witness:', ' ; '.join(found))
        if wrong:
            print('   shortest wrong-fixpoint witness:', ' ; '.join(wrong))
