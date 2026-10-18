#!/bin/bash
# W2-4 Q4 tests: outer-round instrument on a sample of test files most likely to drive the strata loop
# (tabling, narrowing, trait/method resolution, retraction, decomposition, fork-on-union, NAF). One per process.
W=/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-4
P=/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos
RKT="/Applications/Racket v9.3/bin/racket"
mkdir -p $W/q4/tests
cd $P
for t in test-tabling-integration test-tabling test-wf-tabling-01 test-narrowing-01 test-narrowing-search-01 test-narrowing-search-02 \
         test-trait-resolution test-trait-resolution-propagator test-method-resolution test-resolution-confluence-01 \
         test-retraction-stratum test-structural-decomp test-union-types-atms test-classify-inhabit test-readiness-propagator \
         test-rel-t1-naf test-rel-t1-pol test-constraint-postponement test-relational-e2e; do
  PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 150 "$RKT" $W/w24-test-outer.rkt tests/$t.rkt > $W/q4/tests/$t.out 2>&1
  echo "$t exit=$? $(grep -E 'tests passed|test failures|RAISE' $W/q4/tests/$t.out | tr '\n' ' ' | cut -c1-80) $(grep '^W24O' $W/q4/tests/$t.out)"
done
