#lang racket/base

;; test-ast-to-low-pnet.rkt — translator unit tests.

(require rackunit
         "../syntax.rkt"
         "../low-pnet-ir.rkt"
         "../ast-to-low-pnet.rkt")

(define (count-by lp pred)
  (for/sum ([n (in-list (low-pnet-nodes lp))] #:when (pred n)) 1))

(test-case "Int literal: 1 cell, 0 propagators, entry points at it"
  (define lp (ast-to-low-pnet (expr-Int) (expr-int 42) "test.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 1)
  (check-equal? (count-by lp propagator-decl?) 0)
  (define entry (for/first ([n (in-list (low-pnet-nodes lp))]
                            #:when (entry-decl? n)) n))
  (check-equal? (entry-decl-main-cell-id entry) 0))

(test-case "[int+ 1 2]: 3 cells (1, 2, r) + 1 propagator + 2 deps"
  (define body (expr-int-add (expr-int 1) (expr-int 2)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 3)
  (check-equal? (count-by lp propagator-decl?) 1)
  (check-equal? (count-by lp dep-decl?) 2)
  (define p (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (propagator-decl? n)) n))
  (check-equal? (propagator-decl-fire-fn-tag p) 'kernel-int-add)
  ;; Inputs are the two literal cells (in order); output is the third.
  (check-equal? (propagator-decl-input-cells p) (list 0 1))
  (check-equal? (propagator-decl-output-cells p) (list 2)))

(test-case "[int* 6 7]: kernel-int-mul propagator"
  (define body (expr-int-mul (expr-int 6) (expr-int 7)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (define p (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (propagator-decl? n)) n))
  (check-equal? (propagator-decl-fire-fn-tag p) 'kernel-int-mul))

(test-case "Nested [int+ [int* 2 3] 4]: with F.5 lag alignment"
  ;; Pre-F.5: 5 cells (2, 3, m, 4, r), 2 propagators.
  ;; F.5 (2026-05-01): int-add inputs are m (depth 1) and 4 (depth 0).
  ;; emit-aligned-propagator! lifts 4 to depth 1 via 1 identity bridge,
  ;; adding 1 cell + 1 propagator. Total: 6 cells, 3 propagators.
  (define body (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                             (expr-int 4)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 6)
  (check-equal? (count-by lp propagator-decl?) 3))

(test-case "expr-true / expr-false → Bool cells"
  (define lp-true  (ast-to-low-pnet (expr-Bool) (expr-true)  "t.prologos"))
  (define lp-false (ast-to-low-pnet (expr-Bool) (expr-false) "t.prologos"))
  (check-true (validate-low-pnet lp-true))
  (check-true (validate-low-pnet lp-false))
  (define c-true (for/first ([n (in-list (low-pnet-nodes lp-true))]
                             #:when (cell-decl? n)) n))
  (define c-false (for/first ([n (in-list (low-pnet-nodes lp-false))]
                              #:when (cell-decl? n)) n))
  (check-equal? (cell-decl-init-value c-true) #t)
  (check-equal? (cell-decl-init-value c-false) #f))

(test-case "expr-ann strips wrapper"
  (define body (expr-ann (expr-int 7) (expr-Int)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  (define c (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (cell-decl? n)) n))
  (check-equal? (cell-decl-init-value c) 7))

(test-case "unsupported node raises ast-translation-error"
  ;; expr-Pi is a type expression, not a value — translator should reject
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int)
                       (expr-Pi 'mw (expr-Int) (expr-Int))
                       "t.prologos"))))

(test-case "non-Int/Bool main type raises"
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Type 0) (expr-int 0) "t.prologos"))))

;; ============================================================
;; let-binding extension (2026-05-02)
;; ============================================================

(test-case "let-binding via beta-redex: ((fn x -> x+1) 5) → 6 shape"
  ;; (expr-app (expr-lam mw Int (expr-int-add (expr-bvar 0) (expr-int 1))) (expr-int 5))
  (define body
    (expr-app
     (expr-lam 'mw (expr-Int)
               (expr-int-add (expr-bvar 0) (expr-int 1)))
     (expr-int 5)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; cells: 5 (literal arg), 1 (literal in body), result
  (check-equal? (count-by lp cell-decl?) 3)
  (check-equal? (count-by lp propagator-decl?) 1))

(test-case "let-binding shares cell across multiple bvar uses"
  ;; ((fn x -> x + x) 5) → 10
  ;; Both bvar 0 occurrences should point at the SAME cell-id (the cell
  ;; holding 5), so the int-add propagator's two inputs are both that cell.
  (define body
    (expr-app
     (expr-lam 'mw (expr-Int)
               (expr-int-add (expr-bvar 0) (expr-bvar 0)))
     (expr-int 5)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; cells: 5 (literal), result. NO duplicate cell for the second bvar.
  (check-equal? (count-by lp cell-decl?) 2)
  (define p (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (propagator-decl? n)) n))
  (check-equal? (length (propagator-decl-input-cells p)) 2)
  ;; Both inputs are the same cell-id (sharing)
  (check-equal? (car (propagator-decl-input-cells p))
                (cadr (propagator-decl-input-cells p))))

(test-case "nested let-bindings: ((fn x -> ((fn y -> y+x) 3)) 5) → 8"
  ;; (let x = 5 in (let y = 3 in y + x))
  ;; bvar 0 refers to y (innermost), bvar 1 refers to x
  (define body
    (expr-app
     (expr-lam 'mw (expr-Int)
               (expr-app
                (expr-lam 'mw (expr-Int)
                          (expr-int-add (expr-bvar 0) (expr-bvar 1)))
                (expr-int 3)))
     (expr-int 5)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; cells: 5, 3, result. 3 cells, 1 propagator.
  (check-equal? (count-by lp cell-decl?) 3))

(test-case "expr-bvar out-of-scope raises"
  ;; bvar 0 with empty env → escape
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int) (expr-bvar 0) "t.prologos"))))

(test-case "m0 let-binding: arg not evaluated; bvar to it raises"
  ;; ((fn m0 _A:Type -> 7) Int) — m0 binder; body returns 7.
  (define body
    (expr-app
     (expr-lam 'm0 (expr-Type 0) (expr-int 7))
     (expr-Int)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; Only the result cell (the literal 7); the m0 arg was not evaluated.
  (check-equal? (count-by lp cell-decl?) 1))

(test-case "m0 binder referenced at runtime raises"
  ;; ((fn m0 _A:Type -> bvar 0) Int) — body uses the m0-bound thing
  (define body
    (expr-app
     (expr-lam 'm0 (expr-Type 0) (expr-bvar 0))
     (expr-Int)))
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int) body "t.prologos"))))

;; ============================================================
;; Sprint A: comparisons + boolrec/select (2026-05-01)
;; ============================================================

(test-case "[int-lt 3 5] : Bool — kernel-int-lt propagator"
  (define lp (ast-to-low-pnet (expr-Bool)
                              (expr-int-lt (expr-int 3) (expr-int 5))
                              "t.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 3)        ; 3, 5, result
  (check-equal? (count-by lp propagator-decl?) 1)
  (define p (for/first ([n (in-list (low-pnet-nodes lp))]
                        #:when (propagator-decl? n)) n))
  (check-equal? (propagator-decl-fire-fn-tag p) 'kernel-int-lt)
  ;; Result cell domain is Bool, init #f
  (define entry (for/first ([n (in-list (low-pnet-nodes lp))]
                            #:when (entry-decl? n)) n))
  (define result-cell
    (for/first ([n (in-list (low-pnet-nodes lp))]
                #:when (and (cell-decl? n)
                            (= (cell-decl-id n) (entry-decl-main-cell-id entry)))) n))
  (check-equal? (cell-decl-domain-id result-cell) 1)        ; BOOL-DOMAIN-ID
  (check-equal? (cell-decl-init-value result-cell) #f))

(test-case "[int-eq a b] and [int-le a b] dispatch to correct kernel tags"
  (define lp-eq (ast-to-low-pnet (expr-Bool)
                                 (expr-int-eq (expr-int 1) (expr-int 1))
                                 "t.prologos"))
  (define lp-le (ast-to-low-pnet (expr-Bool)
                                 (expr-int-le (expr-int 1) (expr-int 2))
                                 "t.prologos"))
  (define (tag lp)
    (propagator-decl-fire-fn-tag
     (for/first ([n (in-list (low-pnet-nodes lp))]
                 #:when (propagator-decl? n)) n)))
  (check-equal? (tag lp-eq) 'kernel-int-eq)
  (check-equal? (tag lp-le) 'kernel-int-le))

(test-case "boolrec produces kernel-select propagator with 3 inputs"
  ;; if 3 < 5 then 42 else 99 → 42
  (define body (expr-boolrec (expr-Int)
                             (expr-int 42)
                             (expr-int 99)
                             (expr-int-lt (expr-int 3) (expr-int 5))))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; Pre-F.5: 6 cells (3, 5, lt-result, 42, 99, select-result), 2 props.
  ;; F.5 (2026-05-01): select inputs are cond=lt-result (depth 1),
  ;; then=42 (depth 0), else=99 (depth 0). Aligning lifts 42 and 99
  ;; to depth 1 via 2 identity bridges. +2 cells, +2 props.
  ;; Total: 8 cells, 4 propagators.
  (check-equal? (count-by lp cell-decl?) 8)
  (check-equal? (count-by lp propagator-decl?) 4)
  ;; The select propagator still has 3 inputs.
  (define select-prop
    (for/first ([n (in-list (low-pnet-nodes lp))]
                #:when (and (propagator-decl? n)
                            (eq? (propagator-decl-fire-fn-tag n) 'kernel-select))) n))
  (check-true (propagator-decl? select-prop))
  (check-equal? (length (propagator-decl-input-cells select-prop)) 3)
  (check-equal? (length (propagator-decl-output-cells select-prop)) 1))

(test-case "boolrec with same-cell branches still emits two cells"
  ;; if true then 7 else 7 — both branches translate independently;
  ;; no CSE in this pass. Just verifying we don't crash on duplicate
  ;; literal subexpressions.
  (define body (expr-boolrec (expr-Int) (expr-int 7) (expr-int 7) (expr-true)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; cells: cond=true, then=7, else=7, result = 4
  (check-equal? (count-by lp cell-decl?) 4)
  (check-equal? (count-by lp propagator-decl?) 1))

;; ============================================================
;; Sprint E.3: tail-recursive defn lowering (2026-05-01)
;; ============================================================
;;
;; The matcher is exercised end-to-end via the n2-tailrec acceptance
;; .prologos files (CI step "pnet-compile tail-recursive iteration").
;; These tests focus on edge cases of the matcher itself: bare error
;; messages, AST shapes that DON'T match.

(test-case "bare expr-fvar reference (no application) raises"
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int) (expr-fvar 'undefined-fn) "t.prologos"))))

(test-case "expr-app of unknown fvar raises with clear message"
  ;; main := (some-undefined-fn 42) — fvar resolves to nothing.
  (define body (expr-app (expr-fvar 'unknown-fn) (expr-int 42)))
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int) body "t.prologos"))))

;; ============================================================
;; Sprint F.1: non-recursive function inlining (2026-05-01)
;; ============================================================
;;
;; The end-to-end inlining behavior is exercised via the n3-helpers
;; acceptance .prologos files (CI step "pnet-compile non-recursive
;; helpers"). These tests focus on edge cases of the inlining matcher.

(test-case "multi-arg beta-redex chain: ((λ x. λ y. x+y) 3 4) → 7 shape"
  ;; (expr-app (expr-app (expr-lam mw Int (expr-lam mw Int (int-add (bvar 1) (bvar 0)))) 3) 4)
  (define body
    (expr-app
     (expr-app
      (expr-lam 'mw (expr-Int)
                (expr-lam 'mw (expr-Int)
                          (expr-int-add (expr-bvar 1) (expr-bvar 0))))
      (expr-int 3))
     (expr-int 4)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; cells: 3, 4, result = 3
  (check-equal? (count-by lp cell-decl?) 3)
  (check-equal? (count-by lp propagator-decl?) 1))

(test-case "multi-arg with mixed multiplicities m0 + mw"
  ;; ((λm0 _:Type. λmw x:Int. x+1) Int 5) — m0 binder erased.
  (define body
    (expr-app
     (expr-app
      (expr-lam 'm0 (expr-Type 0)
                (expr-lam 'mw (expr-Int)
                          (expr-int-add (expr-bvar 0) (expr-int 1))))
      (expr-Int))
     (expr-int 5)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; m0 binder doesn't allocate; runtime cells are 5 (literal arg) +
  ;; 1 (literal in body) + 1 (result) = 3.
  (check-equal? (count-by lp cell-decl?) 3))

;; ============================================================
;; Sprint F.2: non-dependent pair lowering (2026-05-01)
;; ============================================================

(test-case "expr-pair + expr-fst: int+ (fst <3;4>) (snd <3;4>) → 7"
  ;; (int+ (fst (pair 3 4)) (snd (pair 3 4)))
  (define body
    (expr-int-add
     (expr-fst (expr-pair (expr-int 3) (expr-int 4)))
     (expr-snd (expr-pair (expr-int 3) (expr-int 4)))))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; Each (pair 3 4) builds 2 cells (3 and 4). Two pair constructions
  ;; (no CSE) = 4 cells. Plus 1 result cell from int+ = 5 cells.
  (check-equal? (count-by lp cell-decl?) 5)
  (check-equal? (count-by lp propagator-decl?) 1))

(test-case "let-binding with pair-typed arg: ((λp. fst p + snd p) <10;20>) → 30"
  ;; The lambda binder is pair-typed; bvar 0 in body resolves to a
  ;; vtree (list of cell-ids), and fst/snd project it.
  (define body
    (expr-app
     (expr-lam 'mw (expr-Sigma (expr-Int) (expr-Int))
               (expr-int-add (expr-fst (expr-bvar 0))
                             (expr-snd (expr-bvar 0))))
     (expr-pair (expr-int 10) (expr-int 20))))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; Pair components get 2 cells (10, 20). Result int+ allocates 1
  ;; more. Total 3 cells.
  (check-equal? (count-by lp cell-decl?) 3)
  (check-equal? (count-by lp propagator-decl?) 1))

(test-case "expr-fst on non-pair raises"
  ;; (fst 42) — 42 is a scalar, fst should error.
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int)
                       (expr-fst (expr-int 42))
                       "t.prologos"))))

(test-case "main with pair type raises (entry must be scalar)"
  ;; def main : <Int*Int> := <1;2>  — should error (binary exit
  ;; codes are single-valued; pair-typed main is rejected).
  ;; We can't trigger this via expr-Pair at the top because the
  ;; entry-point asserts scalar. Verify by constructing main as
  ;; a pair.
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int)  ; type says Int but body is a pair
                       (expr-pair (expr-int 1) (expr-int 2))
                       "t.prologos"))))

;; ============================================================
;; Sprint F.4: Nat match + zero/suc/nat-val (2026-05-01)
;; ============================================================

(test-case "expr-nat-val and expr-zero produce single Int cell"
  (define lp1 (ast-to-low-pnet (expr-Nat) (expr-nat-val 42) "t.prologos"))
  (check-true (validate-low-pnet lp1))
  (check-equal? (count-by lp1 cell-decl?) 1)
  (define lp2 (ast-to-low-pnet (expr-Nat) (expr-zero) "t.prologos"))
  (check-true (validate-low-pnet lp2))
  (check-equal? (count-by lp2 cell-decl?) 1))

(test-case "expr-suc adds 1 via int-add propagator"
  ;; (suc (suc (suc zero))) → cells: 0, 1, +1, 1, +1, 1, +1 = 7? Let's see.
  ;; zero → 1 cell. suc inner → inner + new(1) + new(result) = 2 new cells.
  ;; (suc zero): 3 cells (0, 1, result), 1 propagator.
  (define lp (ast-to-low-pnet (expr-Nat)
                              (expr-suc (expr-zero))
                              "t.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 3)
  (check-equal? (count-by lp propagator-decl?) 1))

(test-case "Nat match (zero/suc): is-zero shape"
  ;; (expr-reduce scrutinee
  ;;   (list (expr-reduce-arm 'zero 0 (expr-true))
  ;;         (expr-reduce-arm 'suc 1 (expr-false))) #t)
  (define body
    (expr-reduce (expr-nat-val 0)
                 (list (expr-reduce-arm 'zero 0 (expr-true))
                       (expr-reduce-arm 'suc 1 (expr-false)))
                 #t))
  (define lp (ast-to-low-pnet (expr-Bool) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; Pre-F.5: 8 cells (scrut, zero-lit, cond, one-lit, pred, true,
  ;; false, select-result), 3 propagators (int-eq, int-sub, select).
  ;; F.5 (2026-05-01): the select on the Bool branches has cond at
  ;; depth 1 (int-eq) and true/false branches at depth 0. Alignment
  ;; lifts the two Bool literals via 2 identity bridges. +2 cells,
  ;; +2 props. Total: 10 cells, 5 propagators.
  (check-equal? (count-by lp cell-decl?) 10)
  (check-equal? (count-by lp propagator-decl?) 5))

(test-case "Nat match arms in reverse order (suc first, zero second)"
  (define body
    (expr-reduce (expr-nat-val 0)
                 (list (expr-reduce-arm 'suc 1 (expr-false))
                       (expr-reduce-arm 'zero 0 (expr-true)))
                 #t))
  (define lp (ast-to-low-pnet (expr-Bool) body "t.prologos"))
  (check-true (validate-low-pnet lp)))

(test-case "expr-reduce with 3 arms raises (only 2-arm supported)"
  (define body
    (expr-reduce (expr-nat-val 0)
                 (list (expr-reduce-arm 'zero 0 (expr-int 0))
                       (expr-reduce-arm 'suc 1 (expr-int 1))
                       (expr-reduce-arm 'foo 0 (expr-int 2)))
                 #t))
  (check-exn ast-translation-error?
    (lambda ()
      (ast-to-low-pnet (expr-Int) body "t.prologos"))))

;; ============================================================
;; Sprint F.6: bridge coalescing + depth-balance invariant (2026-05-02)
;; ============================================================

(test-case "depth-balance invariant: every multi-input prop has equal-depth inputs"
  ;; Validate via a synthetic deep arithmetic expression: int+(int*(2,3),
  ;; int*(4,5)). Both int-mul outputs are depth 1; int-add reads both at
  ;; depth 1, no lifting needed; depth-balance trivially holds.
  (define body
    (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                  (expr-int-mul (expr-int 4) (expr-int 5))))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  ;; cells: 4 literals + 2 int-mul outputs + 1 int-add output = 7
  (check-equal? (count-by lp cell-decl?) 7)
  (check-equal? (count-by lp propagator-decl?) 3))

(test-case "asymmetric depth — F.5 lifts shallower input"
  ;; int+ (int* 2 3) 4: int-mul at depth 1, literal 4 at depth 0.
  ;; F.5 lifts 4 to depth 1 via 1 identity bridge. Total cells: 5
  ;; (3 literals + 1 mul-result + 1 add-result) + 1 bridge = 6.
  (define body (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                             (expr-int 4)))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 6)
  (check-equal? (count-by lp propagator-decl?) 3))

(test-case "F.6: depth-balance invariant succeeds on balanced tree"
  ;; int+(int*(2,3), int+(4,5)): two depth-1 children feeding outer add.
  ;; Outer add inputs at equal depth → no lifts. 4 literals + 2 inner
  ;; results + 1 outer result = 7 cells. 3 propagators.
  ;; (Successful depth-balance is implicit — the assertion at end of
  ;; ast-to-low-pnet would raise if any prop had mismatched inputs.)
  (define body
    (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                  (expr-int-add (expr-int 4) (expr-int 5))))
  (define lp (ast-to-low-pnet (expr-Int) body "t.prologos"))
  (check-true (validate-low-pnet lp))
  (check-equal? (count-by lp cell-decl?) 7)
  (check-equal? (count-by lp propagator-decl?) 3))

;; ============================================================
;; kernel-PU Phase 4 Day 9: tail-rec substrate iteration signature
;; ============================================================
;;
;; The Day 9 test gate: tail-rec acceptance examples produce a meta-decl
;; signature documenting that lower-tail-rec emitted the dissolved
;; substrate iteration pattern (cells + identity-feedback + per-leaf
;; arithmetic + select halt-guard), as opposed to Sprint G's never-shipped
;; iter-block-decl pattern. Non-tail-rec programs MUST NOT emit the
;; signature (it'd be a false positive). The version pair must be (1 1)
;; (V1.1, kernel-PU Phase 3 Day 8).
;;
;; The acceptance examples themselves (n2-tailrec/*.prologos) are exercised
;; end-to-end through the network-lower CI workflow + the Day 7 acceptance
;; sweep; here we test the lowering-pass invariant directly via constructed
;; AST shapes.

(define (find-meta-value lp key)
  (for/or ([n (in-list (low-pnet-nodes lp))]
           #:when (and (meta-decl? n) (eq? (meta-decl-key n) key)))
    (meta-decl-value n)))

(test-case "Day 9 signature: non-tail-rec program does NOT emit tail-rec-pattern meta"
  (define lp (ast-to-low-pnet (expr-Int) (expr-int 42) "test.prologos"))
  (check-false (find-meta-value lp 'tail-rec-pattern))
  (check-false (find-meta-value lp 'tail-rec-count)))

(test-case "Day 9 signature: arithmetic program does NOT emit tail-rec-pattern meta"
  (define body (expr-int-add (expr-int-mul (expr-int 2) (expr-int 3))
                             (expr-int 4)))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-false (find-meta-value lp 'tail-rec-pattern)))

(test-case "Day 9: low-pnet version is (1 1) after Phase 3 Day 8 bump"
  (define lp (ast-to-low-pnet (expr-Int) (expr-int 7) "test.prologos"))
  (check-equal? (low-pnet-version lp) '(1 1)))

;; The end-to-end "tail-rec emits the signature" test is exercised by
;; acceptance: the n2-tailrec/*.prologos fixtures lower through ast-to-low-pnet
;; and produce the meta. We can't easily construct an elaborated tail-rec
;; AST in unit-test isolation (it requires the full type elaborator's output
;; with global env populated), so the gate runs in the network-lower
;; integration sweep. The negative tests above confirm the signature is
;; not spuriously emitted.

;; ============================================================
;; Gate 1 (rev 1.0): tagged-union ctor lowering
;; ============================================================
;;
;; These tests construct synthetic ctor-meta entries (no elaborator)
;; and verify ast-to-low-pnet's ctor-application + N-arm match logic.

(require (only-in "../macros.rkt" register-ctor! ctor-meta))

;; Register a synthetic Color = red | green | blue ADT for tests.
(register-ctor! 'tst:red   (ctor-meta 'tst:Color '() '() '() 0))
(register-ctor! 'tst:green (ctor-meta 'tst:Color '() '() '() 1))
(register-ctor! 'tst:blue  (ctor-meta 'tst:Color '() '() '() 2))
(require (only-in racket/base hash-set))
(require (only-in "../macros.rkt" current-type-meta))
(current-type-meta (hash-set (current-type-meta) 'tst:Color '(tst:red tst:green tst:blue)))

;; Register a synthetic Pair-Int-Int = mkPair Int Int ADT (1 ctor, 2 fields).
(register-ctor! 'tst:mkPair (ctor-meta 'tst:Pair '() (list 'Int 'Int) '(#f #f) 0))
(current-type-meta (hash-set (current-type-meta) 'tst:Pair '(tst:mkPair)))

(test-case "Gate 1: nullary ctor in a 1-arm match position works"
  ;; A ctor-vt at the program entry would fail assert-scalar!; that's
  ;; fine — `main` always has a scalar type. We exercise nullary ctor
  ;; construction inside a match (which IS the realistic use site).
  (define body
    (expr-reduce (expr-fvar 'tst:red)
                 (list (expr-reduce-arm 'tst:red   0 (expr-int 1))
                       (expr-reduce-arm 'tst:green 0 (expr-int 2))
                       (expr-reduce-arm 'tst:blue  0 (expr-int 3)))
                 #t))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp)))

(test-case "Gate 1: 3-arm match dispatches via select cascade"
  (define body
    (expr-reduce (expr-fvar 'tst:green)
                 (list (expr-reduce-arm 'tst:red   0 (expr-int 100))
                       (expr-reduce-arm 'tst:green 0 (expr-int 200))
                       (expr-reduce-arm 'tst:blue  0 (expr-int 300)))
                 #t))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp))
  ;; 3-arm match needs 2 tag-eq propagators (for arms 0 and 1; the last
  ;; is the fallthrough) + 2 select propagators (one per cond) per
  ;; result leaf (1 leaf for Int).
  ;; tag-eq count = arms-1 = 2; select count = arms-1 = 2.
  (define n-eq
    (count-by lp (lambda (n) (and (propagator-decl? n)
                                   (eq? (propagator-decl-fire-fn-tag n) 'kernel-int-eq)))))
  (define n-sel
    (count-by lp (lambda (n) (and (propagator-decl? n)
                                   (eq? (propagator-decl-fire-fn-tag n) 'kernel-select)))))
  (check-equal? n-eq 2)
  (check-equal? n-sel 2))

(test-case "Gate 1: 2-arm match (non-Bool/Nat) goes through ctor path"
  ;; Synthesize a 2-ctor type (Choice = yes | no), use it in a match.
  (register-ctor! 'tst:yes (ctor-meta 'tst:Choice '() '() '() 0))
  (register-ctor! 'tst:no  (ctor-meta 'tst:Choice '() '() '() 1))
  (current-type-meta (hash-set (current-type-meta) 'tst:Choice '(tst:yes tst:no)))
  (define body
    (expr-reduce (expr-fvar 'tst:yes)
                 (list (expr-reduce-arm 'tst:yes 0 (expr-int 1))
                       (expr-reduce-arm 'tst:no  0 (expr-int 0)))
                 #t))
  (define lp (ast-to-low-pnet (expr-Int) body "test.prologos"))
  (check-true (validate-low-pnet lp))
  ;; 2-arm match: 1 tag-eq + 1 select.
  (define n-eq
    (count-by lp (lambda (n) (and (propagator-decl? n)
                                   (eq? (propagator-decl-fire-fn-tag n) 'kernel-int-eq)))))
  (define n-sel
    (count-by lp (lambda (n) (and (propagator-decl? n)
                                   (eq? (propagator-decl-fire-fn-tag n) 'kernel-select)))))
  (check-equal? n-eq 1)
  (check-equal? n-sel 1))

(test-case "Gate 1: ctor with scalar field flows the value through identity prop"
  ;; (mkPair 7 9) — 1 ctor with 2 Int fields.
  (define body
    (expr-app (expr-app (expr-fvar 'tst:mkPair) (expr-int 7)) (expr-int 9)))
  ;; Match it with a 1-arm match to extract field 0.
  (define m
    (expr-reduce body
                 (list (expr-reduce-arm 'tst:mkPair 2 (expr-bvar 1)))
                 #t))
  ;; bvar 1 refers to the FIRST-bound field (field 0 = 7) — see
  ;; build-ctor-match: fields are pushed in REVERSE so bvar 0 is the
  ;; LAST field.
  (define lp (ast-to-low-pnet (expr-Int) m "test.prologos"))
  (check-true (validate-low-pnet lp))
  ;; Should have at least 2 kernel-identity propagators (one per field
  ;; flowed into a slot cell at construction time).
  (define n-id
    (count-by lp (lambda (n) (and (propagator-decl? n)
                                   (eq? (propagator-decl-fire-fn-tag n) 'kernel-identity)))))
  (check >= n-id 2))
