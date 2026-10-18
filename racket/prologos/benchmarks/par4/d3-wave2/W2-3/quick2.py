import time
from w23_model import *
t=time.time()
report('CASCADE', Cfg('D2', mem='SC'))
for wl in ['FREQ','K3']:
  for fr in ['uncounted','none']:
    for s in ['FLAG','SEEDS','CREDIT']:
        report(wl, Cfg(s, mem='SC', fr=fr), show=False)
for s in ['SEEDS','DEFER','FLAG','QUIET']:
    report('BOUNCE', Cfg(s, mem='SC', scans=1), show=True)
report('CASCADE', Cfg('FLAG', mem='SC', pubord='cons-ind'))
report('CASCADE', Cfg('ACT', mem='SC', pubord='cons-ind'))
print('t',time.time()-t)
for m in ['TSO','PSO']:
  for s in SCHEMES:
    t=time.time(); report('K3', Cfg(s, mem=m), show=False); print('   t=%.1f'%(time.time()-t))
