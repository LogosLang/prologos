#!/bin/bash
# mut-sw24.sh <racket/prologos> — each mutation of tools/dep-graph.rkt must turn tests/test-dep-graph.rkt RED;
# the file is restored from a pristine copy after each, and a final green run proves the restore.
set -u
cd "$1"
RK="/Applications/Racket v9.3/bin/racket"; RACO="/Applications/Racket v9.3/bin/raco"
F=tools/dep-graph.rkt; S=$(mktemp -d); cp $F $S/orig
run() { PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 300 "$RACO" make $F tests/test-dep-graph.rkt >/dev/null 2>&1
        timeout -k 10 300 "$RK" tools/run-affected-tests.rkt --no-record --tests tests/test-dep-graph.rkt 2>&1 | grep -E '^[0-9]+ tests in'; }
mut() { perl -0pi -e "$2" $F
        if cmp -s $F $S/orig; then echo "MUTATION DID NOT APPLY: $1"; return; fi
        echo "$1 -> $(run)"; cp $S/orig $F; }
mut "M1 cache keyed by path only (content ignored)" 's/\[\(and hit \(equal\? \(car hit\) h\)\) \(hash-set! new rel hit\) \(cadr hit\)\]/[hit (hash-set! new rel hit) (cadr hit)]/'
mut "M2 cache from another dep-graph.rkt trusted"   's/\(equal\? \(cadr d\) self-key\) \(hash\? \(caddr d\)\)/(hash? (caddr d))/'
mut "M3 hidden files treated as modules"             's/\(define \(visible\? name\) \(not \(string-prefix\? name "\."\)\)\)/(define (visible? name) #t)/'
mut "M4 compute-affected-tests ignores #:graph"      's/\(define g \(or graph\n/(define g (or #f\n/'
mut "M5 cache never written"                         's/\(unless \(equal\? entries old\)\n      \(write-cache! cache-path self-key entries\)\)/(void)/'
cmp $F $S/orig && echo "restored: byte-identical"
echo "after restore -> $(run)"
rm -rf $S
