import time, resource
from w23_model import *
for s in ['CREDIT','SEEDS']:
    t=time.time()
    try:
        report('K3', Cfg(s, mem='TSO'), show=False, max_states=12_000_000)
    except RuntimeError as e: print(s, e)
    print('   t=%.1f maxrss=%.1f GB'%(time.time()-t, resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1e9))
