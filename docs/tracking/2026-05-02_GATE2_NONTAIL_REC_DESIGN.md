# Gate 2 — Non-tail / general recursion (rev 1.0, static-eval variant)
**Date**: 2026-05-02
**Status**: Design (rev 1.0, compile-time static-evaluation variant)
**Branch**: `lowering-yolo`
**Predecessor**: [`2026-05-02_LOWERING_INVENTORY.md`](2026-05-02_LOWERING_INVENTORY.md)

## 1. The actual gap

Day 0 inventory bucketed 3 files as `GATE2_RECURSION`:

  - `examples/llvm/tier3/fact.prologos`   — `defn fact | 0 → 1 | n → [int* n [fact (n-1)]]`, then `def main := [fact 5]`
  - `examples/llvm/tier3/fib.prologos`    — classic Fibonacci, `[fib 10]`
  - `examples/llvm/tier3/sum-to.prologos` — `defn sum-to | 0 → 0 | n → [int+ n [sum-to (n-1)]]`, then `[sum-to 15]`

All three fail with **"inlining depth limit 64 exceeded"**. The inliner
substitutes the function body and recurses on the result; each recursive
call site of e.g. `[fact (n-1)]` produces another `(expr-app (expr-fvar
'fact) (expr-int-sub <bvar> 1))`, which the inliner re-expands. The
arithmetic argument `(int-sub n 1)` is never folded to a literal at
compile time, so the recursion never bottoms out.

Looking at these three programs, the root issue is **NOT** that they
need a runtime call stack — `fact 5`, `fib 10`, and `sum-to 15` are
fully concrete. They're recursion over **statically known** integer
arguments. The natural lowering is **compile-time partial evaluation**:
fold the entire call tree to its result value at compile time, and
emit a single result cell.

## 2. PReduce vs. Gate 2 (and why this is rev 1)

The kernel-PU PIR (open follow-up #5) describes Gate 2 as the entry
point for **PM Track 9 (Reduction as Propagators)**, the long-running
"PReduce" track that re-expresses the entire reduction engine as
propagator topology. PReduce would handle non-tail recursion through
runtime activation records (cells) and dynamic propagator installation
(topology mutation), exactly like the kernel-PU substrate is designed
for. That's the correct **rev 2** answer.

But PReduce is multi-week work that's currently Stage 1 research
(per the PIR). For lowering-yolo, we want the smallest change that
unblocks the 3 inventory failures. **rev 1.0 = compile-time static
evaluation** — handles the concrete-argument case (which is all of
the inventory failures) without touching the kernel.

If a future user writes `def main : Int := fib symbolic-n` where
`symbolic-n` isn't statically known, rev 1.0 will still fail with
the same "non-tail-recursive" error. Rev 2 (PReduce) is the path
forward for that case.

## 3. Implementation: `try-static-eval`

In `racket/prologos/ast-to-low-pnet.rkt`:

```racket
;; try-static-eval : expr × literal-env × depth → value | #f
;; Returns a Racket value (Int / #t / #f) if expr reduces to a literal
;; at compile time, else #f. literal-env is a list of literal values
;; corresponding to bvar bindings (parallel to the cell-id env).
(define MAX-STATIC-EVAL-DEPTH 200000)
(define (try-static-eval e lit-env [depth 0])
  (cond
    [(>= depth MAX-STATIC-EVAL-DEPTH) #f]    ; budget exhausted
    [else
     (match e
       [(expr-int n) n]
       [(expr-true)  #t]
       [(expr-false) #f]
       [(expr-ann inner _) (try-static-eval inner lit-env (+ 1 depth))]
       [(expr-bvar i)
        (and (< i (length lit-env))
             (let ([v (list-ref lit-env i)])
               (and (not (eq? v 'unknown)) v)))]
       [(expr-int-add a b) (bin + a b lit-env depth)]
       [(expr-int-sub a b) (bin - a b lit-env depth)]
       [(expr-int-mul a b) (bin * a b lit-env depth)]
       [(expr-int-div a b) (bin int-div-trunc a b lit-env depth)]
       [(expr-int-mod a b) (bin modulo a b lit-env depth)]
       [(expr-int-eq a b)  (bin =  a b lit-env depth)]
       [(expr-int-lt a b)  (bin <  a b lit-env depth)]
       [(expr-int-le a b)  (bin <= a b lit-env depth)]
       [(expr-int-neg a)   (un - a lit-env depth)]
       [(expr-int-abs a)   (un abs a lit-env depth)]
       [(expr-boolrec _ tc fc cond)
        (define cv (try-static-eval cond lit-env (+ 1 depth)))
        (cond [(eq? cv #t) (try-static-eval tc lit-env (+ 1 depth))]
              [(eq? cv #f) (try-static-eval fc lit-env (+ 1 depth))]
              [else #f])]
       [(expr-app (expr-lam _ _ body) arg)
        ;; Beta-reduce.
        (define av (try-static-eval arg lit-env (+ 1 depth)))
        (and av (try-static-eval body (cons av lit-env) (+ 1 depth)))]
       [(expr-app f-expr arg-expr)
        ;; If f-expr peels to an fvar with a lambda value, inline.
        (let-values ([(head args) (peel-fvar-app-chain e)])
          (and head
               (let ([v (global-env-lookup-value head)])
                 (and (expr-lam? v)
                      (let loop ([body v] [args args] [lit-env lit-env])
                        (cond
                          [(and (pair? args) (expr-lam? body))
                           (define av (try-static-eval (car args) lit-env (+ 1 depth)))
                           (and av (loop (expr-lam-body body) (cdr args) (cons av lit-env)))]
                          [(null? args) (try-static-eval body lit-env (+ 1 depth))]
                          [else #f]))))))]
       [_ #f])]))
```

In `build`, near the top (after `expr-ann` strip), try static-eval first:

```racket
(define lit-env (or (current-static-env) '()))
(define static-result (try-static-eval expr lit-env))
(cond
  [(and static-result (not (eq? static-result #f)))
   ;; Successfully folded to a literal — emit a single cell.
   (cond [(eq? static-result #t) (emit-cell! b BOOL-DOMAIN-ID #t)]
         [(eq? static-result #f) (emit-cell! b BOOL-DOMAIN-ID #f)]
         [(exact-integer? static-result) (emit-cell! b INT-DOMAIN-ID static-result)])]
  [else (existing-build-dispatch ...)])
```

The `current-static-env` parameter mirrors `env` (the cell-id list)
with parallel literal values; non-literal binders push `'unknown`
onto the static env. This way, deep inside a recursive call where
some bvar is bound to a runtime cell, static-eval correctly fails
and falls through to runtime lowering.

For the inventory failures, **all** binders are statically known
(`fact 5` has no runtime bvars); static-eval succeeds and folds the
whole call tree.

## 4. Acceptance suite (rev 1.0)

Three examples (the inventory failures) move to PASS, plus three new
ones for additional coverage. Under `examples/network/n12-rec/`:

  1. `fact-5.prologos`     — `[fact 5]` → 120
  2. `fact-7.prologos`     — `[fact 7]` → 5040 mod 256 = 144
  3. `fib-10.prologos`     — `[fib 10]` → 55
  4. `fib-15.prologos`     — `[fib 15]` → 610 mod 256 = 98
  5. `sum-to-15.prologos`  — `[sum-to 15]` → 120
  6. `mutual-even-odd.prologos` — `def main := [even? 10]` → 1 (true)
                            (mutual recursion specializing on literal arg)

If all 6 pass round-trip + native, **Gate 2 rev 1.0 is met**.

## 5. What rev 1.0 does NOT enable

  - `defn main := [fib n]` for symbolic `n` (caller has runtime arg)
  - Any non-tail recursion where some argument is runtime-unknown
  - Coinductive / fix-point reductions
  - Tail recursion through helper functions (already shipped)

For rev 2 → PReduce.

## 6. Risks & sanity check

  - **Compile-time blowup**: static-eval for `fib 30` does ~2.7M
    recursive calls. With `MAX-STATIC-EVAL-DEPTH=200000` this will
    abort cleanly and fall through. We test with `fib 15` (~1973
    calls) to keep compile times in ms.
  - **Wrong-result risk**: the static-eval semantics must match the
    runtime semantics. We use the same operators (`+`, `-`, `*`,
    `int-div-trunc`, `modulo`) that the kernel implements — these
    are validated by the existing prop-network adapter.
  - **Boolean → exit code**: when `main` is `Bool`, `#t`/`#f` flow
    through `init-value-normalize` already (Day 10 fix); same path
    here.

## 7. Path to rev 2 (PReduce)

Per kernel-PU PIR open follow-up #5: PM Track 9 implementation. Sketch:

  - Lower each recursive call to a kernel `prop_install` of an
    activation-record propagator (mid-fire allocation handled by
    Phase 1 Day 2 topology-mutation deferral).
  - Each call site allocates a result cell + dependency cells; the
    fire-fn reads those, dispatches the body, and writes back.
  - Use the kernel scope APIs only if/when divergence isolation is
    needed (the typical case doesn't require this).
  - Recursion termination relies on the program actually terminating
    (the substrate doesn't try to detect non-termination — the
    BSP fuel limit catches it instead).

Estimated scope: 2-3 weeks. Out-of-scope for lowering-yolo.
