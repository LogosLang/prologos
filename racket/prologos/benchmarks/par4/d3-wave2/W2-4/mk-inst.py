#!/usr/bin/env python3
"""W2-4: make an in-memory-instrumented copy of propagator.rkt (scratch only; never compiled to disk).

The copy differs from production in exactly three ways:
  1. relative requires become absolute (file "...") requires, so the copy can live in scratch;
  2. run-to-quiescence-bsp is renamed run-to-quiescence-bsp/orig and a wrapper of the original name
     calls an optional hook (a box, #f by default => behaviour-neutral) with
     ('enter net tier1-eligible?) before and ('exit net result tier1-eligible?) after the original;
  3. the outer loop calls the hook with ('outer outer-round) at the top of each iteration.
"""
import re, sys, pathlib
SRC = pathlib.Path(sys.argv[1])
DST = pathlib.Path(sys.argv[2])
ROOT = SRC.parent
s = SRC.read_text()

# 1. absolute requires for the top-level require block (string module paths ending .rkt)
n_req = 0
def absreq(m):
    global n_req
    n_req += 1
    return '(file "%s")' % (ROOT / m.group(1))
head, sep, rest = s.partition('(require "champ.rkt"')
assert sep, "require block not found"
block_end = rest.index('\n\n')
block = sep + rest[:block_end]
block2 = re.sub(r'"([A-Za-z0-9_./-]+\.rkt)"', absreq, block)
s = head + block2 + rest[block_end:]
# other string requires elsewhere (e.g. (require "x.rkt") later in the file)
s, k = re.subn(r'\(require "([A-Za-z0-9_./-]+\.rkt)"\)', lambda m: '(require (file "%s"))' % (ROOT / m.group(1)), s)
n_req += k

# 2. rename + wrapper
old_def = '(define (run-to-quiescence-bsp net #:executor [executor (or (current-parallel-executor)'
assert s.count(old_def) == 1
s = s.replace(old_def, '(define (run-to-quiescence-bsp/orig net #:executor [executor (or (current-parallel-executor)')
outer = '(let outer-loop ([net net] [outer-round 0])'
assert s.count(outer) == 1
s = s.replace(outer, outer + ' (let ([h (unbox w24-hook)]) (when h (h \'outer outer-round)))')

wrapper = r'''
;; ==== W2-4 instrumentation (scratch copy only) ====
(provide w24-hook w24-tier1-eligible?)
(define w24-hook (box #f))
(define (w24-tier1-eligible? net)
  (and (zero? (net-cell-read net worldview-cache-cell-id))
       (pair? (prop-network-worklist net))
       (not (prop-network-contradiction net))
       (> (net-cell-read net fuel-cell-id) 0)
       (let ([naf-p (net-cell-read net naf-pending-cell-id)])
         (or (not naf-p) (and (hash? naf-p) (hash-empty? naf-p))))
       (for/and ([pid (in-list (prop-network-worklist net))])
         (define prop (champ-lookup (prop-network-propagators net) (prop-id-hash pid) pid))
         (and (not (eq? prop 'none))
              (= (bitwise-and (propagator-flags prop) (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))
                 (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))))))
(define (run-to-quiescence-bsp net #:executor [executor #f])
  (define h (unbox w24-hook))
  (cond
    [(not h) (if executor (run-to-quiescence-bsp/orig net #:executor executor) (run-to-quiescence-bsp/orig net))]
    [else
     (define t1? (w24-tier1-eligible? net))
     (define tok (h 'enter net t1?))
     (define r (if executor (run-to-quiescence-bsp/orig net #:executor executor) (run-to-quiescence-bsp/orig net)))
     (h 'exit tok net r t1?)
     r]))
'''
# insert the wrapper right before the Parallel Executor section header
marker = ';; ========================================\n;; Parallel Executor (Phase 2.5c)'
assert s.count(marker) == 1
s = s.replace(marker, wrapper + '\n' + marker)
DST.parent.mkdir(parents=True, exist_ok=True)
DST.write_text(s)
print("requires rewritten:", n_req, "->", DST)
