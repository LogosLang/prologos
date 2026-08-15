#!/usr/bin/env python3
"""theme-survey.py — resolve candidate scopes against the INSTALLED themes.

The instrument behind the convention-parity principle's measurement clause
(src/semanticTokens.ts, CAPTURE_MAP header).  Four scope-fallback guesses
failed in one day because each was judged by convention folklore instead of
against the themes actually in use; this resolves any scope list against every
theme in ~/.vscode/extensions and prints the colour table, so the choice is a
measurement.

Usage:
  python3 parity/theme-survey.py                          # default candidates
  python3 parity/theme-survey.py scope1 scope2 ...        # your own

Matching is the segment-prefix approximation (longest selector wins, later
rules break ties; descendant selectors matched by their last element).  Good
enough to rank candidates; not a full TextMate matcher — verify a winner in
the editor before shipping it.
"""
import json, glob, re, sys, os

def loadc(p):
    s = open(p, encoding='utf-8', errors='ignore').read()
    s = re.sub(r'//[^\n"]*$', '', s, flags=re.M)
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r',(\s*[}\]])', r'\1', s)
    return json.loads(s)

def theme_files():
    for p in glob.glob(os.path.expanduser('~/.vscode/extensions/*/package.json')):
        try: d = loadc(p)
        except Exception: continue
        for t in d.get('contributes', {}).get('themes', []):
            tp = t.get('path')
            if tp: yield t.get('label', '?'), os.path.join(os.path.dirname(p), tp)

def load_theme(path, seen=None):
    seen = seen or set()
    if path in seen: return [], {}
    seen.add(path)
    try: d = loadc(path)
    except Exception: return [], {}
    rules, sem = [], {}
    if 'include' in d:
        r2, s2 = load_theme(os.path.join(os.path.dirname(path), d['include']), seen)
        rules += r2; sem.update(s2)
    rules += d.get('tokenColors', [])
    sem.update(d.get('semanticTokenColors', {}) or {})
    return rules, sem

def resolve(rules, scope):
    best = (-1, -1, None)
    segs = scope.split('.')
    for i, r in enumerate(rules):
        sel = r.get('scope'); fg = (r.get('settings') or {}).get('foreground')
        if not fg: continue
        sels = sel if isinstance(sel, list) else re.split(r',\s*', sel or '')
        for s in sels:
            s = s.strip().split()[-1] if s.strip() else ''
            if not s: continue
            ss = s.split('.')
            if segs[:len(ss)] == ss and (len(ss), i) > (best[0], best[1]):
                best = (len(ss), i, fg)
    return best[2]

CANDS = sys.argv[1:] or [
    'constant.numeric.prologos', 'support.type.prologos',
    'support.type.property-name.prologos', 'entity.name.tag.prologos',
    'entity.other.attribute-name.prologos',
]
short = [c.replace('.prologos', '').split('.')[-1][:8] for c in CANDS]
print(f"{'theme':40s}" + ''.join(f"{n:>10s}" for n in short))
for label, path in sorted(theme_files()):
    rules, _sem = load_theme(path)
    if not rules: continue
    row = [resolve(rules, sc) for sc in CANDS]
    print(f"{label[:40]:40s}" + ''.join(f"{(c or '--')[:9]:>10s}" for c in row))
