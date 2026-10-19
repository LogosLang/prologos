#!/bin/bash
# C1 census (D.3 wave 1). Read-only greps at the worktree HEAD; production = racket/prologos minus tests/benchmarks/tools/compiled/data.
W=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors
cd "$W/racket/prologos" || exit 1
echo "HEAD: $(git -C "$W" rev-parse --short HEAD); production .rkt diff vs c1f389ab:"
git -C "$W" diff --stat c1f389ab HEAD -- racket/prologos | grep '\.rkt' | grep -v benchmarks || echo "  (none outside benchmarks)"
prod() { grep -rn "$1" --include=*.rkt . | grep -v "/tests/\|/benchmarks/\|/tools/\|/compiled/\|/data/" | grep -v ":[0-9]*:\s*;"; }

echo; echo "== 1. production expressions that READ current-source-loc (D.2 §6.5 says 13) =="
prod "(current-source-loc)"
echo "count: $(prod "(current-source-loc)" | wc -l)"
echo "-- of which inside a parameterize form (elaboration-entry fallback, outside any fire):"
prod "(current-source-loc)" | grep parameterize
echo "-- power: the same pipeline finds a known reader and skips a comment"
mkdir -p "$TMPDIR/c1pw"; printf 'x (current-source-loc) y\n  ;; (current-source-loc)\n' > "$TMPDIR/c1pw/p.rkt"; (cd "$TMPDIR/c1pw" && prod "(current-source-loc)")
echo "-- the data-path precedent: a reader of the propagator record's srcloc"
prod "propagator-srcloc"

echo; echo "== 2. fire-once is implemented by the scheduler =="
grep -n "scheduler implements fire-once" propagator.rkt
grep -n "fired-set (make-hasheq)\|hash-set! fired-set\|hash-has-key? fired-set\|net-remove-propagator-from-dependents net pid cid" propagator.rkt
echo "fire-once install sites (production): $(prod '(net-add-fire-once-propagator' | grep -v '(define (net-add-fire-once-propagator' | wc -l)"

echo; echo "== 3. propagator struct fields (a flags word exists) =="
grep -n "(struct propagator " propagator.rkt; grep -n "^(define PROP-" propagator.rkt

echo; echo "== 4. merges minted per cell at runtime =="
grep -n "new-merge (make-tagged-merge domain-merge)\|(lambda (o n) n) old-merge" propagator.rkt
echo "promote-cell-to-tagged production call sites: $(prod 'promote-cell-to-tagged' | grep -v 'define (promote' | grep -v 'propagator.rkt:260' | wc -l)"
grep -n "scaffolding-merge-fn-registry (make-hasheq)" merge-fn-registry.rkt

echo; echo "== 5. SRE property lattice and the existing capability gating (fail-closed) =="
sed -n 246,249p sre-core.rkt
grep -n "Returns #t only for prop-confirmed" sre-core.rkt

echo; echo "== 6. P0 detect.rkt: the measured detector uses a reset flag and counts cons after processing =="
sed -n 117,126p benchmarks/par4/detect.rkt
