#!/usr/bin/env python3
"""check-xlinks.py — CROSS-FILE link resolution for prologos documents (md + org).

Written for the PPN move into docs/tracking/tracks/PPN/ (2026-10-13), after
lhc's tools/check-xlinks.py. A document move breaks links in BOTH directions:
the inbound links that name the old path, and every relative link INSIDE the
moved file (its directory changed). An intra-file anchor checker sees neither.
This tool resolves every relative link target against its linking file and
reports the ones that name nothing.

What it checks:  RESOLUTION only — does `](path)` / `[[file:path]]` name an
existing file or directory? Fragments (`#anchor`, org `::search`) and `:line`
suffixes are stripped, not checked.

What it skips:   URLs, `#anchors`, org `id:`/`elisp:`/`shell:` links, targets that
are prose rather than paths (contain a space, start with `:` or `§`, or have no
`.`/`/`), code spans (md backticks, org `~…~` `=…=`), fenced blocks
(``` and #+begin_src/#+begin_example), and SYMLINKS (a symlink is an alias whose
relative links resolve from the real file, not from the alias's directory).

Usage:
    tools/check-xlinks.py [--json OUT] [ROOT ...]   # default roots: docs .claude CLAUDE.md
    tools/check-xlinks.py --self-test               # prove the instrument can fail

Exit: 0 clean · 1 broken links found · 2 usage error.
A clean run means every link lands on something real — not that the cited text
says what the citation claims.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

MD_LINK = re.compile(r'\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')
ORG_LINK = re.compile(r'\[\[([^\]\n]+)\](?:\[[^\]\n]*\])?\]')
MD_CODE = re.compile(r'`[^`\n]*`')
ORG_CODE = re.compile(r'(?<![\w])[~=][^~=\n]+[~=](?![\w])')
FENCE = re.compile(r'^(\s*)(```|~~~)')
ORG_BLOCK_BEGIN = re.compile(r'^\s*#\+begin_(src|example)\b', re.I)
ORG_BLOCK_END = re.compile(r'^\s*#\+end_(src|example)\b', re.I)
SKIP_PREFIXES = ('http://', 'https://', 'mailto:', '#', 'id:', 'elisp:', 'shell:', 'news:', 'doi:')
LINE_SUFFIX = re.compile(r':\d+(?:-\d+)?$')


def is_pathlike(t):
    if ' ' in t or t.startswith((':', '§', '…', '*')):
        return False
    if not re.search(r'[A-Za-z0-9]', t):
        return False
    return '/' in t or '.' in t


def strip_target(t, org):
    if org and t.startswith('file:'):
        t = t[5:]
    if org and '::' in t:
        t = t.split('::', 1)[0]
    t = t.split('#', 1)[0]
    t = LINE_SUFFIX.sub('', t)
    return t


def links_in(text, org):
    """Yield (lineno, raw_target, path) for each candidate relative link."""
    in_fence = False
    in_block = False
    for n, line in enumerate(text.split('\n'), 1):
        if org:
            if ORG_BLOCK_BEGIN.match(line):
                in_block = True
                continue
            if ORG_BLOCK_END.match(line):
                in_block = False
                continue
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence or in_block:
            continue
        body = ORG_CODE.sub('', line) if org else MD_CODE.sub('', line)
        cands = [(m.group(1), False) for m in MD_LINK.finditer(body)]
        if org or '[[' in body:
            for m in ORG_LINK.finditer(body):
                cands.append((m.group(1), True))
        for raw, is_org in cands:
            if raw.startswith(SKIP_PREFIXES):
                continue
            path = strip_target(raw, is_org)
            if not path or path.startswith('/') or not is_pathlike(path):
                continue
            yield n, raw, path


def tracked_docs(repo, roots):
    out = subprocess.run(['git', '-C', repo, 'ls-files', '-z', '--', *roots],
                         capture_output=True, check=True).stdout.decode()
    for p in out.split('\0'):
        if p.endswith(('.md', '.org')) and not os.path.islink(os.path.join(repo, p)):
            yield p


def check(repo, roots):
    broken = []
    total = 0
    for p in tracked_docs(repo, roots):
        full = os.path.join(repo, p)
        try:
            with open(full, encoding='utf-8') as fh:
                text = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        for n, raw, path in links_in(text, p.endswith('.org')):
            total += 1
            resolved = os.path.normpath(os.path.join(os.path.dirname(p), path))
            if not os.path.exists(os.path.join(repo, resolved)):
                broken.append({'file': p, 'line': n, 'target': raw, 'resolved': resolved})
    return total, broken


def self_test():
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(['git', 'init', '-q', d], check=True)
        os.makedirs(os.path.join(d, 'docs/a/b'))
        files = {
            'docs/a/x.md': '[ok](b/y.md) [bad](b/missing.md) `[code](nope.md)` [url](https://x) [frag](b/y.md#s2) [line](b/y.md:12)\n',
            'docs/a/b/y.md': '[up](../x.md) [prose](see the § above) [bad-up](../../x.md)\n```\n[fenced](zzz.md)\n```\n',
            'docs/a/r.org': '[[file:b/y.md][ok]] [[file:gone.org][bad]] ~[[file:code.org]]~ [[*Heading]] [[:space:]]\n',
        }
        for p, t in files.items():
            with open(os.path.join(d, p), 'w') as fh:
                fh.write(t)
        os.symlink('b/y.md', os.path.join(d, 'docs/a/alias.md'))
        subprocess.run(['git', '-C', d, 'add', '-A'], check=True)
        total, broken = check(d, ['docs'])
        got = sorted((b['file'], b['target']) for b in broken)
        want = sorted([('docs/a/x.md', 'b/missing.md'), ('docs/a/b/y.md', '../../x.md'),
                       ('docs/a/r.org', 'file:gone.org')])
        assert got == want, f'self-test FAILED:\n got  {got}\n want {want}'
        assert total == 8, f'self-test FAILED: counted {total} links, want 8'
    print('self-test OK: 3 planted broken links found, 0 false positives, symlink skipped')
    return 0


def main(argv):
    if '--self-test' in argv:
        return self_test()
    out = None
    if '--json' in argv:
        i = argv.index('--json')
        out = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    roots = argv or ['docs', '.claude', 'CLAUDE.md']
    repo = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True,
                          check=True).stdout.decode().strip()
    total, broken = check(repo, roots)
    if out:
        with open(out, 'w') as fh:
            json.dump(broken, fh, indent=1)
    for b in broken:
        print(f"{b['file']}:{b['line']}: {b['target']}  ->  {b['resolved']}")
    print(f'{total} relative links checked, {len(broken)} broken', file=sys.stderr)
    return 1 if broken else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
