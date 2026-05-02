
# Lowering Inventory — coverage of ast-to-low-pnet across all .prologos files

Total files probed: 113

## Bucket summary

| Bucket | Count | What it means | Gate |
|---|---|---|---|
| PASS | 55 | Round-trips through ast-to-low-pnet → run-low-pnet | — |
| NO_MAIN | 44 | Library file or no `main` value (not lowerable target) | — |
| TIMEOUT | 3 | Probe exceeded per-file timeout (likely infinite loop in elab/lowering) | — |
| GATE2_RECURSION | 3 | Non-tail / mutual recursion, bare fvar, undefined symbols | Gate 2 (PReduce) |
| GATE3_STRING | 5 | Strings, bytes, chars (heuristic: source matches str:: / char-at / etc.) | Gate 3 |
| OTHER_LOWERING | 3 | Closures, records, partial app, effects, other unsupported AST | Future |

## Per-bucket file listings

### PASS (55 files)

- `examples/llvm/tier0/exit-0.prologos`
- `examples/llvm/tier0/exit-42.prologos`
- `examples/llvm/tier0/exit-7.prologos`
- `examples/llvm/tier1/add.prologos`
- `examples/llvm/tier1/deep.prologos`
- `examples/llvm/tier1/div.prologos`
- `examples/llvm/tier1/mul.prologos`
- `examples/llvm/tier1/nested.prologos`
- `examples/llvm/tier1/sub.prologos`
- `examples/llvm/tier2/composed.prologos`
- `examples/llvm/tier2/simple-call.prologos`
- `examples/llvm/tier2/three-args.prologos`
- `examples/llvm/tier2/two-fns.prologos`
- `examples/llvm/tier3/choose-false.prologos`
- `examples/llvm/tier3/choose.prologos`
- `examples/llvm/tier3/cmp-eq.prologos`
- `examples/llvm/tier3/cmp-le-driven.prologos`
- `examples/llvm/tier3/is-positive.prologos`
- `examples/network/n0/exit-0.prologos`
- `examples/network/n0/exit-42.prologos`
- `examples/network/n0/exit-7.prologos`
- `examples/network/n1-arith/add.prologos`
- `examples/network/n1-arith/deep.prologos`
- `examples/network/n1-arith/div.prologos`
- `examples/network/n1-arith/eq-pick.prologos`
- `examples/network/n1-arith/fib10.prologos`
- `examples/network/n1-arith/fib20.prologos`
- `examples/network/n1-arith/let-shared.prologos`
- `examples/network/n1-arith/let.prologos`
- `examples/network/n1-arith/max.prologos`
- `examples/network/n1-arith/min.prologos`
- `examples/network/n1-arith/mul.prologos`
- `examples/network/n1-arith/nested.prologos`
- `examples/network/n1-arith/sub.prologos`
- `examples/network/n2-tailrec/countdown.prologos`
- `examples/network/n2-tailrec/factorial-iter.prologos`
- `examples/network/n2-tailrec/fib-iter.prologos`
- `examples/network/n2-tailrec/sum-to.prologos`
- `examples/network/n3-helpers/double.prologos`
- `examples/network/n3-helpers/quadruple.prologos`
- `examples/network/n3-helpers/sum-times.prologos`
- `examples/network/n4-pairs/nested-fst.prologos`
- `examples/network/n4-pairs/pair-add.prologos`
- `examples/network/n4-pairs/pair-mul.prologos`
- `examples/network/n4-pairs/swap-then-diff.prologos`
- `examples/network/n5-pair-state/accum-pair.prologos`
- `examples/network/n5-pair-state/count-pair.prologos`
- `examples/network/n5-pair-state/fib-pair.prologos`
- `examples/network/n5-pair-state/pell.prologos`
- `examples/network/n6-nat-match/is-zero-false.prologos`
- `examples/network/n6-nat-match/is-zero.prologos`
- `examples/network/n6-nat-match/pred.prologos`
- `examples/network/n6-nat-match/safe-pred.prologos`
- `examples/network/n6-nat-match/suc-suc.prologos`
- `examples/network/n7-showcase/showcase.prologos`

### NO_MAIN (44 files)

- `examples/2026-03-09-fc-trait-rel-dom.prologos`
  - no `main` value defined
- `examples/2026-03-10-surface-ergonomics.prologos`
  - no `main` value defined
- `examples/2026-03-15-track3-acceptance.prologos`
  - no `main` value defined
- `examples/2026-03-16-track4-acceptance.prologos`
  - no `main` value defined
- `examples/2026-03-18-track7-acceptance.prologos`
  - no `main` value defined
- `examples/2026-03-19-punify-acceptance.prologos`
  - no `main` value defined
- `examples/2026-03-20-punify-p3-acceptance.prologos`
  - no `main` value defined
- `examples/2026-03-21-track8-acceptance.prologos`
  - no `main` value defined
- `examples/2026-03-24-track10.prologos`
  - no `main` value defined
- `examples/2026-03-25-track10b.prologos`
  - no `main` value defined
- `examples/2026-03-26-ppn-track0.prologos`
  - no `main` value defined
- `examples/2026-03-28-sudoku-demo.prologos`
  - no `main` value defined
- `examples/2026-03-30-ppn-track2b.prologos`
  - no `main` value defined
- `examples/2026-04-02-ppn-track3.prologos`
  - no `main` value defined
- `examples/2026-04-02-sre-track2h.prologos`
  - no `main` value defined
- `examples/2026-04-03-sre-track2d.prologos`
  - no `main` value defined
- `examples/2026-04-04-ppn-track4.prologos`
  - no `main` value defined
- `examples/2026-04-08-bsp-le-track2.prologos`
  - no `main` value defined
- `examples/2026-04-17-ppn-track4c-adversarial.prologos`
  - no `main` value defined
- `examples/2026-04-17-ppn-track4c.prologos`
  - no `main` value defined
- `examples/2026-04-22-1A-iii-probe.prologos`
  - no `main` value defined
- `examples/audit/audit-01-literals-types.prologos`
  - no `main` value defined
- `examples/audit/audit-02-def-spec-defn.prologos`
  - no `main` value defined
- `examples/audit/audit-03-data-constructors.prologos`
  - no `main` value defined
- `examples/audit/audit-04-match-if-cond.prologos`
  - no `main` value defined
- `examples/audit/audit-05-fn-let-do.prologos`
  - no `main` value defined
- `examples/audit/audit-06-traits-instances.prologos`
  - no `main` value defined
- `examples/audit/audit-07-collections.prologos`
  - no `main` value defined
- `examples/audit/audit-08-narrowing-logic.prologos`
  - no `main` value defined
- `examples/audit/audit-10-pipe-compose.prologos`
  - no `main` value defined
- `examples/audit/audit-11-modules-imports.prologos`
  - no `main` value defined
- `examples/audit/audit-12-advanced.prologos`
  - no `main` value defined
- `examples/generic-numerics.prologos`
  - no `main` value defined
- `examples/homoiconicity.prologos`
  - no `main` value defined
- `examples/narrowing-demo.prologos`
  - no `main` value defined
- `examples/piping.prologos`
  - no `main` value defined
- `examples/relational-demo.prologos`
  - no `main` value defined
- `examples/strings-tutorial-demo.prologos`
  - no `main` value defined
- `examples/sudoku-solver-demo.prologos`
  - no `main` value defined
- `examples/unified-matching.prologos`
  - no `main` value defined
- `examples/varargs.prologos`
  - no `main` value defined
- `lib/examples/foray-min.prologos`
  - no `main` value defined
- `lib/examples/foray.prologos`
  - no `main` value defined
- `lib/examples/prop-viz-demo.prologos`
  - no `main` value defined

### TIMEOUT (3 files)

- `examples/2026-03-16-track5-acceptance.prologos`
  - exceeded 15000ms
- `examples/2026-03-16-track6-acceptance.prologos`
  - exceeded 15000ms
- `examples/audit/audit-09-numerics.prologos`
  - exceeded 15000ms

### GATE2_RECURSION (3 files)

- `examples/llvm/tier3/fact.prologos`
  - ast-to-low-pnet cannot translate (expr-app (expr-fvar 'fact) (expr-int-sub (expr-bvar 0) (expr-int 1))): inlining depth limit 64 exceeded while expanding 'fact'. Likely cause: deeply nested helper fun
- `examples/llvm/tier3/fib.prologos`
  - ast-to-low-pnet cannot translate (expr-app (expr-fvar 'fib) (expr-int-sub (expr-bvar 0) (expr-int 1))): inlining depth limit 64 exceeded while expanding 'fib'. Likely cause: deeply nested helper funct
- `examples/llvm/tier3/sum-to.prologos`
  - ast-to-low-pnet cannot translate (expr-app (expr-fvar 'sum-to) (expr-int-sub (expr-bvar 0) (expr-int 1))): inlining depth limit 64 exceeded while expanding 'sum-to'. Likely cause: deeply nested helper

### GATE3_STRING (5 files)

- `examples/2026-03-14-wfle-acceptance.prologos`
  - explain: Unknown relation: parent
- `examples/2026-03-20-first-class-paths.prologos`
  - mixfix: Unexpected token after expression: version
- `examples/map-tutorial-demo.prologos`
  - imports: Cannot find module: prologos::core::map-ops (searched lib paths: (/Users/xyz/Development/prologos/racket/prologos/lib))
- `examples/numerics-tutorial-demo.prologos`
  - if: if requires: (if cond then else) or (if ResultType cond then else)
- `lib/examples/foreign.prologos`
  - imports: Cannot find module: prologos::core::abs-trait (searched lib paths: (/Users/xyz/Development/prologos/racket/prologos/lib))

### OTHER_LOWERING (3 files)

- `examples/llvm/tier1/abs.prologos`
  - ast-to-low-pnet cannot translate (expr-int-abs (expr-int-neg (expr-int 99))): Phase 2.D supports Int/Bool literals, int+/-/*//, int-eq/lt/le, boolrec, expr-bvar, let-binding, and saturated tail-recurs
- `examples/llvm/tier1/mod.prologos`
  - ast-to-low-pnet cannot translate (expr-int-mod (expr-int 100) (expr-int 7)): Phase 2.D supports Int/Bool literals, int+/-/*//, int-eq/lt/le, boolrec, expr-bvar, let-binding, and saturated tail-recursi
- `examples/llvm/tier3/fact-7.prologos`
  - ast-to-low-pnet cannot translate (expr-int-mod (expr-app (expr-fvar 'fact) (expr-int 7)) (expr-int 256)): Phase 2.D supports Int/Bool literals, int+/-/*//, int-eq/lt/le, boolrec, expr-bvar, let-bindin
