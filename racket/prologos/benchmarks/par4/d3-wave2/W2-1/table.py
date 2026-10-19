#!/usr/bin/env python3
"""W2-1: print the summary table from all.summary.json"""
import json, sys
d = json.load(open(sys.argv[1]))
print('selftest alternations (power):', d['selftest_alternations'])
hdr = ('file', 'fires', 'runs', 'rnd/run', 'S0ms', 'S0/cmd', 'cellK8 n', 'cellK8 t', 'compK8 t', 'pidK8 t',
       'parT c4/8/16', 'parT comp4/8/16', 'parT pid8', 'W/S',
       'fen cell f/t', 'fen comp f/t', 'fen compC f/t', 'alt cell m/x', 'alt comp m/x', 'alt rand m/x',
       'cell+F', 'comp+F 8', 'comp+0 8', 'pid+0 8', 'p2l W/S', 'p2l comp+F/+0 8')
print(' | '.join(hdr))
for r in d['files']:
    if r['fires'] == 0:
        print(' | '.join([r['file'].replace('.prologos', ''), '0', '-', '-', '0', '0'] + ['-'] * (len(hdr) - 6)))
        continue
    h = r['homes']; fz = r['fences']; b = r['bounds']; p = r['p2lite_estimate']
    def g(rule, K, k):
        return h[rule][str(K)][k] if str(K) in h[rule] else h[rule][K][k]
    def bb(key, K, typ='async', src=b):
        x = src[key]
        x = x[str(K)] if str(K) in x else x[K]
        return x[typ]
    row = [r['file'].replace('.prologos', ''), r['fires'], r['runs'], r['rounds_per_run_mean'], r['fire_ms_total'],
           r['S0_fire_share_of_command'],
           g('CELL', 8, 'busiest_share_count'), g('CELL', 8, 'busiest_share_time'), g('COMP_S', 8, 'busiest_share_time'),
           g('PID', 8, 'busiest_share_time'),
           '/'.join(str(g('CELL', K, 'par_round_time')) for K in (4, 8, 16)),
           '/'.join(str(g('COMP_S', K, 'par_round_time')) for K in (4, 8, 16)),
           g('PID', 8, 'par_round_time'), r['work_over_span'],
           '%s/%s' % (fz['F_CELL']['fenced_fire_share'], fz['F_CELL']['fenced_time_share']),
           '%s/%s' % (fz['F_COMPs']['fenced_fire_share'], fz['F_COMPs']['fenced_time_share']),
           '%s/%s' % (fz['F_COMPc']['fenced_fire_share'], fz['F_COMPc']['fenced_time_share']),
           '%s/%s' % (fz['F_CELL']['crit_path_alternations_per_run_mean'], fz['F_CELL']['crit_path_alternations_per_run_max']),
           '%s/%s' % (fz['F_COMPs']['crit_path_alternations_per_run_mean'], fz['F_COMPs']['crit_path_alternations_per_run_max']),
           '%s/%s' % (fz['F_RAND']['crit_path_alternations_per_run_mean'], fz['F_RAND']['crit_path_alternations_per_run_max']),
           bb('CELL+F_CELL', 8), bb('COMP_S+F_COMPs', 8), bb('COMP_S+NONE', 8), bb('PID+NONE', 8),
           p['work_over_span'], '%s/%s' % (bb('COMP_S+F_COMPs', 8, src=p['bounds']), bb('COMP_S+NONE', 8, src=p['bounds']))]
    print(' | '.join(str(x) for x in row))
