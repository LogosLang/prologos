#!/usr/bin/env python3
"""W2-3: the one-pass counting detector (SEEDS: read every cons, then every prod; no second scan)."""
import sys, time
from w23_model import *
from w23_run import row

print('=== one pass, cons before prod (CSPLIT), scans=1 — SEEDS (deferred acks, seeds counted, no indicator) ===')
for wl in ['CASCADE', 'SENDWRITE', 'FREQ', 'BOUNCE', 'SEEDS2', 'K3']:
    for m, f in (('SC', ()), ('TSO', ()), ('PSO', ('pub', 'send'))):
        if wl == 'K3' and m == 'PSO':
            continue
        row(wl, Cfg('SEEDS', mem=m, scans=1, readord='CSPLIT', fences=f, sendorder='prod-lane'), show=False)
print('  LOG representation (heads before tails), one pass:')
for wl in ['SENDWRITE', 'BOUNCE', 'SEEDS2']:
    row(wl, Cfg('SEEDS', mem='PSO', repr='LOG', scans=1, fences=('pub',)), show=False)
row('K3', Cfg('SEEDS', mem='TSO', repr='LOG', scans=1), show=False)
print('  contradiction handshake and regions, one pass:')
row('CONTRA', Cfg('SEEDS', mem='TSO', boundary='QCH', scans=1, readord='CSPLIT', sendorder='prod-lane'), show=False)
row('REGIONS', Cfg('SEEDS', mem='TSO', tasks=[(2,), (1,)], scans=1, readord='CSPLIT', sendorder='prod-lane'), show=False)
row('NESTED', Cfg('SEEDS', mem='TSO', scans=1, readord='CSPLIT', sendorder='prod-lane'), show=False)
print('=== power rows (must fail) ===')
print('  one pass with prod read BEFORE cons (PCI order):')
row('BOUNCE', Cfg('SEEDS', mem='SC', scans=1, readord='PCI', sendorder='prod-lane'), show=True)
print('  one pass, cons first, but the sender counts AFTER publishing (lane-prod):')
row('SENDWRITE', Cfg('SEEDS', mem='SC', scans=1, readord='CSPLIT', sendorder='lane-prod'), show=True)
print('  EARLY = SEEDS with cons published at drain (D.2\'s ack point), one pass and two scans:')
row('CASCADE', Cfg('EARLY', mem='SC', scans=1, readord='CSPLIT', sendorder='prod-lane'), show=True)
row('CASCADE', Cfg('EARLY', mem='SC', scans=2, sendorder='prod-lane'), show=False)
print('  one pass, cons first, PSO without the send release:')
row('SENDWRITE', Cfg('SEEDS', mem='PSO', scans=1, readord='CSPLIT', fences=('pub',), sendorder='prod-lane'), show=True)
