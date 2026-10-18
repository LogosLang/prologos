#!/usr/bin/env python3
"""W2-1 analysis of gran-probe.rkt output (one JSON per .prologos file).

usage: gran_analyze.py OUT.summary.json FILE1.json [FILE2.json ...]

Free parameters (printed in the header):
  K       executors, in {4, 8, 16}
  t(f)    fire time = median over the timing reps of the wall of fire-and-collect-writes (thread executor OFF)
Home rules (where a fire runs):
  CELL    D.2 §6.7: owner of the first declared output cell, round-robin by cell id (cell-n mod K)
  COMP_D  owner of the first component the fire WROTE (min first-seen index of its changed units, RR mod K);
          fires that wrote nothing fall back to COMP_S.  Post hoc (an oracle), an upper bound for a static rule.
  COMP_S  static per propagator: owner of the first component in the propagator's write profile (the units it
          wrote anywhere in this network epoch); never-writers: first declared #:component-paths unit on an input;
          else first output cell; else pid.  Realizable if outputs declared components.
  COMP_H  COMP_S with crc32(unit) mod K instead of first-seen RR (sensitivity)
  PID     power row: pid mod K
Fence variants (which fires are fenced):
  F_CELL  D.2 §6.3 post-P1a per-cell fence: any declared output is the attribute map or a type cell
  F_COMPd per-component, per fire (oracle): the fire's delta has an attribute-map :type unit or a type-cell write
  F_COMPs per-component, static per propagator: its profile has a :type unit / type-cell unit, or an output is a
          type cell; never-writers with an attribute-map output: FREE (optimistic)
  F_COMPc same, never-writers with an attribute-map output FENCED (conservative)
  NONE    no fence (the type merge became a join)
"""
import json, sys, statistics, zlib
from collections import defaultdict, Counter

KS = (4, 8, 16)


def unit_cell(u):
    # "c49" or "a49:12::type" / "a49:12:*"
    if u.startswith('c'):
        return int(u[1:])
    return int(u[1:].split(':', 1)[0])


def unit_facet(u):
    if u.startswith('c'):
        return None
    parts = u.split(':')
    # a49:12::type -> ['a49','12','','type'];  a49:12:* -> ['a49','12','*']
    if parts[-1] == '*':
        return '*'
    return parts[-1]


def units_match(wu, iu):
    """write unit wu vs declared input unit iu on the same cell"""
    if wu.startswith('c') or iu.startswith('c'):
        return True
    if wu == iu:
        return True
    if wu.endswith(':*') and iu.startswith(wu[:-1]):
        return True
    if iu.endswith(':*') and wu.startswith(iu[:-1]):
        return True
    return False


def analyze(path, tmode='raw'):
    d = json.load(open(path))
    F = d['fires']
    F.sort(key=lambda f: (f['call'], f['idx']))
    n = len(F)
    reps = d['rep_ms']
    assert all(len(r) == n for r in reps), (path, [len(r) for r in reps], n)
    seq_ok = all(d['rep_seq_match'])
    assert max((f['depth'] for f in F), default=1) == 1, 'nested executor calls: alignment assumption broken'
    gc_fire = d['rep_gc_fire']
    for j, f in enumerate(F):
        f['t'] = statistics.median([r[j] for r in reps]) if seq_ok else f['ms']
        f['gc_any'] = any(g[j] > 0 for g in gc_fire)
    # ESTIMATE (tmode='p2lite'): remove the full pu-value-diff an in-fire write to a component-watched compound
    # cell pays; ONE diff per written compound cell per fire (a lower bound on the in-fire diffs: a fire that
    # writes k facets through k that-writes pays k).  Floor: 1 us.
    diff_removed = 0.0
    for f in F:
        f['t_raw'] = f['t']
        dsum = sum(w.get('diff_ms', 0.0) for w in f['writes'] + f['undeclared'] if w.get('map_size', -1) > 0)
        if tmode == 'p2lite':
            nt = max(f['t'] - dsum, min(f['t'], 0.001))
            diff_removed += f['t'] - nt
            f['t'] = nt
    # network epochs: next-prop-id only grows within one network
    ep, prev = 0, None
    for f in F:
        if prev is not None and f['npid'] < prev:
            ep += 1
        prev = f['npid']
        f['ep'] = ep
    # write units, type flags
    for f in F:
        ws = f['writes'] + f['undeclared']
        f['wunits'] = [u for w in ws for u in w['units']]
        f['wtype'] = any(w['cell']['type'] for w in ws) or any(
            w['cell']['am'] and any(unit_facet(u) in ('type', '*') or u.startswith('c') for u in w['units']) for w in ws)
        f['out_am'] = any(o['am'] for o in f['outs'])
        f['out_type'] = any(o['type'] for o in f['outs'])
    # unit first-seen index
    uidx = {}
    for f in F:
        for u in f['wunits']:
            uidx.setdefault(u, len(uidx))
        for i in f['ins']:
            for u in i['units']:
                uidx.setdefault(u, len(uidx))
        for o in f['outs']:
            uidx.setdefault('c%d' % o['n'], len(uidx))
    # per-propagator profile (epoch, pid)
    prof = defaultdict(list)
    prof_type = defaultdict(bool)
    for f in F:
        key = (f['ep'], f['pid'])
        for u in f['wunits']:
            if u not in prof[key]:
                prof[key].append(u)
        if f['wtype']:
            prof_type[key] = True

    def static_unit(f):
        key = (f['ep'], f['pid'])
        if prof[key]:
            return min(prof[key], key=lambda u: uidx[u]), 'profile'
        for i in f['ins']:
            for u in i['units']:
                if not u.startswith('c'):
                    return u, 'declared-path'
        if f['outs']:
            return 'c%d' % f['outs'][0]['n'], 'out-cell'
        return None, 'pid'

    src = Counter()
    for f in F:
        su, s = static_unit(f)
        f['su'] = su
        src[s] += 1
        f['du'] = min(f['wunits'], key=lambda u: uidx[u]) if f['wunits'] else su

    def home(f, rule, K):
        if rule == 'CELL':
            if f['outs']:
                return f['outs'][0]['n'] % K
            if f['ins']:
                return f['ins'][0]['n'] % K
            return 0
        if rule == 'PID':
            return f['pid'] % K
        if rule == 'COMP_D':
            u = f['du']
            return uidx[u] % K if u is not None else f['pid'] % K
        if rule == 'COMP_S':
            u = f['su']
            return uidx[u] % K if u is not None else f['pid'] % K
        if rule == 'COMP_H':
            u = f['su']
            return zlib.crc32(u.encode()) % K if u is not None else f['pid'] % K
        raise ValueError(rule)

    def fenced(f, var):
        if var == 'NONE':
            return False
        if var == 'F_CELL':
            return f['out_am'] or f['out_type']
        if var == 'F_RAND':
            return f['pid'] % 2 == 1
        if var == 'F_COMPd':
            return f['wtype'] or (f['out_type'] and not f['wunits'])
        key = (f['ep'], f['pid'])
        if f['out_type'] or prof_type[key]:
            return True
        if not prof[key] and f['out_am']:
            return var == 'F_COMPc'
        return False

    # rounds and runs
    runs = defaultdict(list)
    for f in F:
        runs[f['run']].append(f)
    rounds = defaultdict(list)
    for f in F:
        rounds[(f['run'], f['round'])].append(f)

    # dependency DAG: preds = fires of round r-1 (same run) whose changed units meet f's declared input units
    for f in F:
        f['preds'] = []
    covered = no_pred = 0
    for (rid, rnd), fs in rounds.items():
        if rnd == 0:
            continue
        prevfs = rounds.get((rid, rnd - 1), [])
        bycell = defaultdict(list)
        for g in prevfs:
            for w in g['writes'] + g['undeclared']:
                bycell[w['cell']['n']].append((g, w['units']))
        installers = [g for g in prevfs if g['new_props'] > 0 or g['new_cells'] > 0]
        for f in fs:
            ps = set()
            for i in f['ins']:
                for g, wus in bycell.get(i['n'], []):
                    if any(units_match(wu, iu) for wu in wus for iu in i['units']):
                        ps.add(id(g))
                        f['preds'].append(g)
            if ps:
                covered += 1
            else:
                no_pred += 1
                f['preds'] = list(installers)  # deferred installs: attach to the installing round
    T = sum(f['t'] for f in F)
    N = n

    res = {'file': d['file'].split('/')[-1], 'fires': N, 'runs': len(runs), 'rounds': len(rounds),
           'epochs': ep + 1, 'seq_match': seq_ok, 'fire_ms_total': round(T, 3),
           'fire_ms_total_repA': round(sum(f['ms'] for f in F), 3),
           'wall_ms_median': round(statistics.median(d['rep_wall_ms']), 2),
           'S0_fire_share_of_command': round(T / statistics.median(d['rep_wall_ms']), 3),
           'raised': d.get('raised'),
           'fires_with_gc': sum(1 for f in F if f['gc_any']),
           'productive_fires': sum(1 for f in F if f['wunits']),
           'productive_time_share': round(sum(f['t'] for f in F if f['wunits']) / T, 3) if T else 0,
           'mean_fire_us': round(1000 * T / N, 2) if N else 0,
           'static_home_source': dict(src),
           'dep_coverage_round_gt0': round(covered / (covered + no_pred), 3) if covered + no_pred else None,
           'units_distinct': len(uidx),
           'written_facets': dict(Counter((unit_facet(u) or 'whole') for f in F for u in f['wunits'])),
           'written_cell_merges': dict(Counter(w['cell']['merge'] + ('[type]' if w['cell']['type'] else '')
                                               for f in F for w in f['writes'] + f['undeclared'])),
           }
    if N == 0:
        return res

    # ---- Q1/Q2: busiest share (global) and effective parallelism (per round)
    def share_and_par(rule, K):
        cnt = Counter(); tm = defaultdict(float)
        for f in F:
            h = home(f, rule, K)
            cnt[h] += 1; tm[h] += f['t']
        sc = max(cnt.values()) / N
        st = max(tm.values()) / T
        # per round
        sw = smx = 0; st_r = 0.0; smt = 0.0; sw2 = smx2 = 0; st2 = smt2 = 0.0
        for fs in rounds.values():
            c = Counter(); tt = defaultdict(float)
            for f in fs:
                h = home(f, rule, K)
                c[h] += 1; tt[h] += f['t']
            sw += len(fs); smx += max(c.values()); st_r += sum(tt.values()); smt += max(tt.values())
            if len(fs) >= 2:
                sw2 += len(fs); smx2 += max(c.values()); st2 += sum(tt.values()); smt2 += max(tt.values())
        return {'busiest_share_count': round(sc, 3), 'busiest_share_time': round(st, 3),
                'par_round_count': round(sw / smx, 2), 'par_round_time': round(st_r / smt, 2),
                'par_round_count_w2': round(sw2 / smx2, 2) if smx2 else None,
                'par_round_time_w2': round(st2 / smt2, 2) if smt2 else None}

    res['homes'] = {rule: {K: share_and_par(rule, K) for K in KS}
                    for rule in ('CELL', 'COMP_D', 'COMP_S', 'COMP_H', 'PID')}

    # ---- Q3: fenced share, alternations
    def alternations(var):
        col = {id(f): fenced(f, var) for f in F}
        alt = {}
        per_run = []
        for rid, fs in runs.items():
            fs_sorted = sorted(fs, key=lambda f: (f['round'], f['idx']))
            m = 0
            for f in fs_sorted:
                a = 0
                for g in f['preds']:
                    a = max(a, alt[id(g)] + (1 if col[id(g)] != col[id(f)] else 0))
                alt[id(f)] = a
                m = max(m, a)
            per_run.append(m)
        # D.2 §6.3 schedule: phases alternate free (even p) / fenced (odd p), starting free; each phase runs its
        # colour to quiescence, so a fire sits in the first phase of its colour at or after all its preds' phases.
        ph = {}
        d2 = []
        for rid, fs in runs.items():
            m = 0
            for f in sorted(fs, key=lambda f: (f['round'], f['idx'])):
                want = 1 if col[id(f)] else 0
                lo = max((ph[id(g)] for g in f['preds']), default=0)
                p_ = lo if lo % 2 == want else lo + 1
                ph[id(f)] = p_
                m = max(m, p_)
            d2.append(m)
        # round-order proxy (C3): phase switches between rounds that are F / U / M
        sw_total = 0
        for rid, fs in runs.items():
            last = None
            for rnd in sorted(set(f['round'] for f in fs)):
                rf = [col[id(f)] for f in rounds[(rid, rnd)]]
                kind = 'M' if (any(rf) and not all(rf)) else ('F' if all(rf) else 'U')
                if last is not None and kind != last:
                    sw_total += 1
                last = kind
        nf = sum(1 for f in F if col[id(f)])
        tf = sum(f['t'] for f in F if col[id(f)])
        runs_with_both = sum(1 for rid, fs in runs.items()
                             if any(col[id(f)] for f in fs) and not all(col[id(f)] for f in fs))
        return {'fenced_fire_share': round(nf / N, 3), 'fenced_time_share': round(tf / T, 3),
                'crit_path_alternations_total': sum(per_run),
                'crit_path_alternations_per_run_mean': round(sum(per_run) / len(per_run), 2),
                'crit_path_alternations_per_run_max': max(per_run),
                'runs_with_alternation': sum(1 for x in per_run if x > 0),
                'runs_mixing_fenced_and_free': runs_with_both,
                'round_order_phase_switches_total': sw_total,
                'd2_schedule_switches_total': sum(d2),
                'd2_schedule_switches_per_run_mean': round(sum(d2) / len(d2), 2),
                'd2_schedule_switches_per_run_max': max(d2)}

    res['fences'] = {v: alternations(v) for v in ('F_CELL', 'F_COMPd', 'F_COMPs', 'F_COMPc', 'F_RAND')}
    res['tmode'] = tmode
    res['diff_ms_removed'] = round(diff_removed, 3)

    # ---- span (dependency-limited parallelism)
    span = {}
    run_span = {}
    for rid, fs in runs.items():
        m = 0.0
        for f in sorted(fs, key=lambda f: (f['round'], f['idx'])):
            s = f['t'] + max((span[id(g)] for g in f['preds']), default=0.0)
            span[id(f)] = s
            m = max(m, s)
        run_span[rid] = m
    res['work_over_span'] = round(T / sum(run_span.values()), 2)
    res['rounds_per_run_mean'] = round(len(rounds) / len(runs), 2)

    # ---- combined bounds: round-barrier and async, with homes x fence
    def bounds(rule, var, K):
        col = {id(f): fenced(f, var) for f in F}
        rb = 0.0
        for fs in rounds.values():
            Fr = sum(f['t'] for f in fs if col[id(f)])
            U = defaultdict(float)
            for f in fs:
                if not col[id(f)]:
                    U[home(f, rule, K)] += f['t']
            rb += Fr + (max(U.values()) if U else 0.0)
        ab = 0.0
        for rid, fs in runs.items():
            Fr = sum(f['t'] for f in fs if col[id(f)])
            U = defaultdict(float)
            for f in fs:
                if not col[id(f)]:
                    U[home(f, rule, K)] += f['t']
            ab += max(run_span[rid], Fr + (max(U.values()) if U else 0.0))
        return {'round_barrier': round(T / rb, 2), 'async': round(T / ab, 2)}

    res['bounds'] = {}
    for rule, var in (('CELL', 'F_CELL'), ('CELL', 'NONE'), ('COMP_S', 'F_COMPs'), ('COMP_S', 'F_COMPc'),
                      ('COMP_D', 'F_COMPd'), ('COMP_S', 'NONE'), ('COMP_D', 'NONE'), ('PID', 'NONE')):
        res['bounds']['%s+%s' % (rule, var)] = {K: bounds(rule, var, K) for K in KS}
    # fire-time distribution
    ts = sorted(f['t'] for f in F)
    res['fire_us_p50_p90_p99_max'] = [round(1000 * ts[int(q * (len(ts) - 1))], 1) for q in (0.5, 0.9, 0.99)] + [round(1000 * ts[-1], 1)]
    res['top_decile_time_share'] = round(sum(ts[int(0.9 * len(ts)):]) / T, 3)
    return res


def power_alternation_selftest():
    """a chain F U F U (one fire per round) must give 3 alternations; a chain F F F must give 0"""
    def mk(colors):
        fs = []
        for i, c in enumerate(colors):
            fs.append({'c': c, 'preds': [fs[-1]] if fs else []})
        alt = {}
        for f in fs:
            alt[id(f)] = max((alt[id(g)] + (g['c'] != f['c']) for g in f['preds']), default=0)
        return max(alt.values())
    return {'FUFU': mk([1, 0, 1, 0]), 'FFF': mk([1, 1, 1]), 'FUUUF': mk([1, 0, 0, 0, 1])}
    # (the D.2-schedule count adds the start-free phase: a fenced root costs one switch)


if __name__ == '__main__':
    out = sys.argv[1]
    allres = {'selftest_alternations': power_alternation_selftest(), 'files': []}
    for p in sys.argv[2:]:
        r = analyze(p)
        if r['fires'] == 0:
            allres['files'].append(r)
            continue
        a = analyze(p, 'p2lite')
        r['p2lite_estimate'] = {k: a.get(k) for k in ('fire_ms_total', 'diff_ms_removed', 'work_over_span', 'bounds')}
        r['p2lite_estimate']['fences'] = {v: {'fenced_time_share': x['fenced_time_share']} for v, x in a.get('fences', {}).items()}
        r['p2lite_estimate']['homes_K8_time'] = {rule: a['homes'][rule][8]['busiest_share_time'] for rule in a.get('homes', {})}
        allres['files'].append(r)
    json.dump(allres, open(out, 'w'), indent=1)
    print(json.dumps(allres['selftest_alternations']))
    for r in allres['files']:
        print(r['file'], r['fires'], r.get('fire_ms_total'), r.get('S0_fire_share_of_command'))
