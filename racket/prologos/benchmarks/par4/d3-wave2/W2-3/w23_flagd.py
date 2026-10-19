#!/usr/bin/env python3
"""W2-3: D.1 §5.4 read literally — 'cons = received and processed': a resettable flag with the ack deferred (FLAGD)."""
from w23_model import *
from w23_run import row
print('=== FLAGD: reset flag (busy at drain, idle when the worklist empties) + cons published after the cascade ===')
for wl in ['CASCADE', 'SENDWRITE', 'FREQ', 'BOUNCE', 'SEEDS2']:
    row(wl, Cfg('FLAGD', mem='SC', sendorder='prod-lane'), show=False)
    row(wl, Cfg('FLAGD', mem='SC', readord='ANY', sendorder='prod-lane'), show=True)
    row(wl, Cfg('FLAGD', mem='TSO', readord='ANY', sendorder='prod-lane'), show=False)
    row(wl, Cfg('FLAGD', mem='PSO', fences=('pub', 'send'), sendorder='prod-lane'), show=False)
row('K3', Cfg('FLAGD', mem='SC', readord='ANY', sendorder='prod-lane'), show=False)
row('CONTRA', Cfg('FLAGD', mem='TSO', boundary='QCH', sendorder='prod-lane'), show=False)
print('  FLAG (cons at drain) with every fixed read order, for comparison — CASCADE and BOUNCE:')
for ro in ('PCI', 'PIC', 'IPC', 'ICP', 'CPI', 'CIP'):
    row('BOUNCE', Cfg('FLAGD', mem='SC', readord=ro, sendorder='prod-lane'), show=False)
