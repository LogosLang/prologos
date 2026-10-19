import re,sys
lines=open('out/census-summary.txt').read().split('\n')
start=[i for i,l in enumerate(lines) if l.startswith('== FIRE-REACHABLE parameter READS')][0]
for l in lines[start+1:]:
    if not l.strip(): break
    parts=[p.strip() for p in l.split(' | ')]
    name=parts[0]; d=parts[1]; asg=parts[2].replace('assigned: ',''); fr=parts[3]; rr=parts[4].replace('reached-from-root-modules: ','')
    n=re.match(r'fire-reads (\d+)',fr).group(1)
    mods=rr.split(',')
    print(f"{name:42s} {d.replace('def ',''):36s} {asg:38s} n={n:>2s} R={len(mods):>2d} {rr[:110]}")
