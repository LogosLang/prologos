import re,glob,os,collections
legs=['fresh','prod','persist','persistcap']
files=sorted(set(os.path.basename(p).rsplit('.',2)[0] for p in glob.glob('dynA/*.out')))
norm=lambda s: re.sub(r'_g\d+','_g#',re.sub(r'meta\d+','meta#',s))
nres=0; out=collections.defaultdict(list)
for b in files:
    def load(leg):
        p=f'dynA/{b}.{leg}.out'
        return [norm(l.split(': ',1)[1]) for l in open(p,errors='replace') if l.startswith('RESULT')] if os.path.exists(p) else None
    s=load('seq'); nres+=len(s)
    for leg in legs:
        d=load(leg)
        nd=sum(1 for a,c in zip(s,d) if a!=c)+abs(len(s)-len(d))
        if nd: out[leg].append((b,nd))
print('files',len(files),'seq results',nres,'(gensym/meta suffixes normalised)')
for leg in legs: print(leg,'files with differing results:',out[leg] or 'none')
