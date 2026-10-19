#!/usr/bin/env python3
"""W2-3 driver: every row of the verdicts.  Usage: python3 w23_run.py [section ...]  (default: all)"""
import sys, time
from w23_model import *

LIMIT = 6_000_000


def row(wl, cfg, show=True):
    t = time.time()
    try:
        r = report(wl, cfg, show=show, max_states=LIMIT)
    except RuntimeError as e:
        print(f'{wl:8s} {cfg.label():78s} LIMIT ({e})')
        r = None
    print(f'      ({time.time() - t:.1f}s)')
    sys.stdout.flush()
    return r


def q1():
    print('\n=== Q1: D.2 as written (idle-epoch max-counter, cons at drain, double scan) — reproduction ===')
    for m in ('SC', 'TSO', 'PSO'):
        row('CASCADE', Cfg('D2', mem=m), show=(m == 'SC'))
    row('K3', Cfg('D2', mem='SC'), show=True)
    print('  D.2 also has no fire requests (Lane = Set [CellId Delta]):')
    row('FREQ', Cfg('D2', mem='SC', fr='none'), show=True)
    row('FREQ', Cfg('D2', mem='SC', fr='uncounted'), show=True)
    print('  D.2 contradiction stop (boundary only on the counters):')
    row('CONTRA', Cfg('D2', mem='SC', boundary='Q'), show=True)


def q2_matrix():
    print('\n=== Q2 matrix: every repair x workload x memory; recommended protocol (count before send, prod-lane) ===')
    print('    fences: - = none; pub = release (a store-store fence) before every cons/indicator/credit publication')
    wls = ['CASCADE', 'SENDWRITE', 'FREQ', 'BOUNCE', 'SEEDS2']
    for s in SCHEMES[1:]:          # D2's rows: w23_matrix_D2_partial.out (unsound everywhere)
        print(f'--- {s}')
        for wl in wls:
            for m, f in (('SC', ()), ('TSO', ()), ('PSO', ()), ('PSO', ('pub',))):
                row(wl, Cfg(s, mem=m, fences=f, sendorder='prod-lane'), show=False)
        for m in ('SC', 'TSO'):
            row('K3', Cfg(s, mem=m, sendorder='prod-lane'), show=False)


def q2_power():
    print('\n=== Q2 power rows: each must FAIL ===')
    print('  (i) uncounted / missing fire requests, every scheme:')
    for s in SCHEMES:
        row('FREQ', Cfg(s, mem='SC', fr='uncounted', sendorder='prod-lane'), show=(s == 'SEEDS'))
        row('FREQ', Cfg(s, mem='SC', fr='none', sendorder='prod-lane'), show=(s == 'SEEDS'))
    print('  (ii) single scan for every counting scheme (credit is single-scan by design):')
    for s in ['FLAG', 'ACT', 'QUIET', 'DEFER', 'SEEDS']:
        row('BOUNCE', Cfg(s, mem='SC', scans=1, sendorder='prod-lane'), show=(s == 'SEEDS'))
    print('  (iii) ordering invariants between separate cells (SC, no memory model needed):')
    row('CASCADE', Cfg('FLAG', mem='SC', pubord='cons-ind', sendorder='prod-lane'), show=True)
    row('CASCADE', Cfg('ACT', mem='SC', pubord='cons-ind', sendorder='prod-lane'), show=True)
    row('SENDWRITE', Cfg('SEEDS', mem='SC', sendorder='lane-prod'), show=True)
    row('SENDWRITE', Cfg('DEFER', mem='SC', sendorder='lane-prod'), show=False)
    row('SENDWRITE', Cfg('FLAG', mem='SC', sendorder='lane-prod'), show=False)
    print('  (iv) read order inside a scan (QUIET reads the mark before cons):')
    for ro in ('PCI', 'PIC', 'IPC', 'ICP', 'CPI', 'CIP'):
        row('BOUNCE', Cfg('QUIET', mem='SC', readord=ro, sendorder='prod-lane'), show=False)
        row('BOUNCE', Cfg('FLAG', mem='SC', readord=ro, sendorder='prod-lane'), show=False)


def q3_log():
    print('\n=== Q3b: lanes as logs with cursors (prod, cons = derived reads), PSO, with/without the pub fence ===')
    for s in ['SEEDS', 'DEFER', 'QUIET', 'FLAG']:
        for wl in ['SENDWRITE', 'BOUNCE', 'SEEDS2']:
            for f in ((), ('pub',)):
                row(wl, Cfg(s, mem='PSO', repr='LOG', fences=f), show=False)
    print('  SEP with lane-prod order under PSO+pub (the separate-cell invariant the log removes):')
    row('SENDWRITE', Cfg('SEEDS', mem='PSO', fences=('pub',), sendorder='lane-prod'), show=True)
    row('SENDWRITE', Cfg('SEEDS', mem='PSO', repr='LOG', fences=('pub',)), show=False)
    print('  LOG with the K=3 workload under TSO:')
    row('K3', Cfg('SEEDS', mem='TSO', repr='LOG'), show=False)


def contra():
    print('\n=== contradiction stop: boundary = counters only (Q) / quiescence-or-contradiction (QC) / with parking handshake (QCH) ===')
    for s in ['SEEDS', 'DEFER', 'FLAG', 'CREDIT']:
        for b in ('Q', 'QC', 'QCH'):
            for m, f in (('SC', ()), ('TSO', ()), ('PSO', ('pub',)), ('PSO', ('pub', 'park'))):
                if b != 'QCH' and 'park' in f:
                    continue
                row('CONTRA', Cfg(s, mem=m, boundary=b, fences=f, sendorder='prod-lane'),
                    show=(m == 'SC' and s == 'SEEDS') or (s == 'SEEDS' and m == 'PSO' and b == 'QCH' and 'park' not in f))


def regions():
    print('\n=== regions keyed by network id ===')
    print('  REGIONS: region 2 sends a delta INTO region 1 (an upstream edge).')
    for s in ['SEEDS', 'DEFER', 'CREDIT', 'FLAG']:
        for m in ('SC', 'TSO'):
            row('REGIONS', Cfg(s, mem=m, tasks=[(1,), (2,)], sendorder='prod-lane'), show=(m == 'SC' and s == 'SEEDS'))
            row('REGIONS', Cfg(s, mem=m, tasks=[(2,), (1,)], sendorder='prod-lane'), show=False)
            row('REGIONS', Cfg(s, mem=m, keyed=False, sendorder='prod-lane'), show=False)
    print('  NESTED: region 1\'s boundary handler seeds region 2 (a fork run inside a handler), sequentially.')
    for s in ['SEEDS', 'DEFER']:
        for m in ('SC', 'TSO'):
            row('NESTED', Cfg(s, mem=m, sendorder='prod-lane'), show=False)
            row('NESTED', Cfg(s, mem=m, keyed=False, sendorder='prod-lane'), show=False)
    print('  NESTED with the late-write tag: per-network boundary set vs one process-wide boundary-epoch:')
    row('NESTED', Cfg('SEEDS', mem='SC', latecheck='WTC', tag='per-network', post=True, sendorder='prod-lane'), show=False)
    row('NESTED', Cfg('SEEDS', mem='SC', latecheck='WTC', tag='process', post=True, sendorder='prod-lane'), show=False)


def late():
    print('\n=== Q3a: the late-write check (C5-7) — does it catch a premature declaration? (detector = D2, which is unsound) ===')
    for m in ('SC', 'TSO'):
        for lc in ('CTW', 'WTC', 'WTCF'):
            for df in (False, True):
                row('CASCADE', Cfg('D2', mem=m, latecheck=lc, detfence=df, post=True), show=False)
    print('  with a sound detector the check has nothing to catch (vacuous): ')
    for s in ['SEEDS', 'DEFER']:
        row('CASCADE', Cfg(s, mem='TSO', latecheck='WTC', post=True, sendorder='prod-lane'), show=False)
        row('K3', Cfg(s, mem='SC', latecheck='WTC', post=True, sendorder='prod-lane'), show=False)


def supplement():
    print('\n=== S1: PSO with BOTH releases — pub (before cons/indicator/credit publication) and send (prod store before the lane publish) ===')
    for s in ['FLAG', 'ACT', 'QUIET', 'DEFER', 'SEEDS', 'CREDIT']:
        for wl in ['CASCADE', 'SENDWRITE', 'FREQ', 'BOUNCE', 'SEEDS2']:
            row(wl, Cfg(s, mem='PSO', fences=('pub', 'send'), sendorder='prod-lane'), show=False)
        print('    send alone (no pub):')
        row('SENDWRITE', Cfg(s, mem='PSO', fences=('send',), sendorder='prod-lane'), show=(s == 'SEEDS'))
    print('  K=3 under PSO with both releases:')
    for s in ['SEEDS', 'DEFER']:
        row('K3', Cfg(s, mem='PSO', fences=('pub', 'send'), sendorder='prod-lane'), show=False)
    row('K3', Cfg('SEEDS', mem='PSO', repr='LOG', fences=('pub',)), show=False)
    print('\n=== S2: the detector reads each scan\'s words in ANY order (ARM load-load reordering inside a scan) ===')
    for s in SCHEMES:
        for wl in ['CASCADE', 'SENDWRITE', 'BOUNCE', 'SEEDS2', 'FREQ']:
            for m in ('SC', 'TSO'):
                row(wl, Cfg(s, mem=m, readord='ANY', sendorder='prod-lane'), show=(s == 'FLAG' and wl == 'BOUNCE' and m == 'SC'))
    for s in ['SEEDS', 'DEFER', 'QUIET', 'ACT']:
        row('K3', Cfg(s, mem='SC', readord='ANY', sendorder='prod-lane'), show=False)
    row('BOUNCE', Cfg('SEEDS', mem='PSO', readord='ANY', fences=('pub', 'send'), sendorder='prod-lane'), show=False)
    row('BOUNCE', Cfg('SEEDS', mem='PSO', repr='LOG', readord='ANY', fences=('pub',)), show=False)
    print('\n=== S3: re-runs after fixes (credit = one unit per region; contradiction handshake with all releases) ===')
    for m in ('SC', 'TSO'):
        row('REGIONS', Cfg('CREDIT', mem=m, tasks=[(1,), (2,)], sendorder='prod-lane'), show=(m == 'SC'))
        row('REGIONS', Cfg('CREDIT', mem=m, tasks=[(2,), (1,)], sendorder='prod-lane'), show=(m == 'SC'))
        row('REGIONS', Cfg('CREDIT', mem=m, keyed=False, sendorder='prod-lane'), show=False)
    for s in ['SEEDS', 'DEFER', 'FLAG', 'CREDIT']:
        row('CONTRA', Cfg(s, mem='PSO', boundary='QCH', fences=('pub', 'send', 'park'), sendorder='prod-lane'), show=False)
        row('CONTRA', Cfg(s, mem='PSO', boundary='QCH', fences=('pub', 'send'), sendorder='prod-lane'), show=(s == 'SEEDS'))
    row('CONTRA', Cfg('SEEDS', mem='PSO', repr='LOG', boundary='QCH', fences=('pub', 'park')), show=False)
    row('CONTRA', Cfg('SEEDS', mem='TSO', boundary='QCH', readord='ANY', sendorder='prod-lane'), show=False)


SECTIONS = dict(q1=q1, matrix=q2_matrix, power=q2_power, log=q3_log, contra=contra, regions=regions, late=late,
                supplement=supplement)

if __name__ == '__main__':
    names = sys.argv[1:] or list(SECTIONS)
    t0 = time.time()
    for n in names:
        SECTIONS[n]()
    print(f'\ntotal {time.time() - t0:.0f}s')
