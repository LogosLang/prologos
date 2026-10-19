import time
from w23_model import *
t=time.time()
for s in ['FLAG','DEFER','SEEDS','QUIET','ACT','CREDIT']:
    for f in [(),('pub',)]:
        report('CASCADE', Cfg(s, mem='PSO', fences=f), show=True)
for s in ['SEEDS','DEFER']:
    for f in [(),('pub',)]:
        report('BOUNCE', Cfg(s, mem='PSO', fences=f), show=True)
        report('BOUNCE', Cfg(s, mem='PSO', repr='LOG', fences=f), show=True)
print('t',time.time()-t)
for b in ['Q','QC','QCH']:
    for m in ['SC','TSO','PSO']:
        report('CONTRA', Cfg('SEEDS', mem=m, boundary=b), show=(m=='SC'))
report('CONTRA', Cfg('SEEDS', mem='PSO', boundary='QCH', fences=('park',)))
report('CONTRA', Cfg('SEEDS', mem='PSO', boundary='QCH', fences=('park','pub')))
print('t',time.time()-t)
