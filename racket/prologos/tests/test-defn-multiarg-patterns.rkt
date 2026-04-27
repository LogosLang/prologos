#lang racket/base

;;;
;;; Tests for Multi-Arg Pattern Disambiguation in `defn name | ... -> ...`
;;;
;;; Eigentrust pitfalls doc #7 fix: bare-token patterns after `|` in
;;; `defn name | pat -> body | ...` were ambiguous between
;;;   (a) one compound pattern: `cons r nil` → cons-of-(r,nil)   [ML/Haskell-like]
;;;   (b) N separate arg patterns: `cons r nil` → cons, r, nil   [old behavior]
;;;
;;; The fix in parser.rkt's parse-defn-clause auto-detects (a) when the
;;; leading token is a known constructor whose field count matches the
;;; remaining tokens. Otherwise it falls back to (b), preserving genuinely
;;; multi-arg defns like `defn add | x y -> [+ x y]`.
;;;
;;; Coverage:
;;; - Single-arg multi-clause (regression of canonical multi-clause defn)
;;; - Multi-arg multi-clause with all-variable patterns (regression of (b))
;;; - Eigentrust reproducer (sum-rows): `cons r nil` → one compound
;;; - Multi-arg with constructor patterns in non-first positions
;;; - Wildcards `_` mixed in
;;;

(require rackunit
         racket/string
         "test-support.rkt")

;; ========================================
;; Helpers
;; ========================================
;; Use test-support.rkt's run-ns-* helpers (canonical post-S2.e pattern;
;; the manual parameterize block here referenced retired
;; `current-mult-meta-store` and friends — fixed 2026-04-27).

;; Prepend namespace declarations so test strings (which lack their own
;; ns headers) get a namespace context — needed for prelude refs.
(define (run-last s) (run-ns-last (string-append "(ns test)\n" s)))
(define (run-ws s) (run-ns-ws-all (string-append "ns test\n" s)))
(define (run-ws-last s) (run-ns-ws-last (string-append "ns test\n" s)))

;; ========================================
;; A. Single-arg multi-clause regression
;; ========================================
;; The canonical `is-zero` example from prologos-syntax.md.

(test-case "marg/single-arg-is-zero"
  (check-equal?
   (run-ws-last
    "defn iz-marg\n  | zero  -> true\n  | suc _ -> false\neval [iz-marg 0N]")
   "true : Bool")
  (check-equal?
   (run-ws-last
    "defn iz-marg2\n  | zero  -> true\n  | suc _ -> false\neval [iz-marg2 3N]")
   "false : Bool"))

;; ========================================
;; B. Multi-arg with all-variable patterns: must NOT be packed
;; ========================================
;; `x y` does not have a leading ctor, so falls back to N args.
;; Critical regression: confirms genuinely multi-arg defns still work.

(test-case "marg/all-var-two-arg"
  ;; `defn add-marg | x y -> [+ x y]` — 2 args, both variables
  ;; Use Nat constructors so the type infers as Nat -> Nat -> Nat
  (check-equal?
   (run-ws-last
    "spec add-marg Nat -> Nat -> Nat\ndefn add-marg\n  | x y -> [+ x y]\neval [add-marg 3N 4N]")
   "7N : Nat"))

(test-case "marg/all-var-three-arg"
  ;; 3 args, all variable — must be parsed as 3 args
  (check-equal?
   (run-ws-last
    "spec triple-add Nat -> Nat -> Nat -> Nat\ndefn triple-add\n  | x y z -> [+ [+ x y] z]\neval [triple-add 1N 2N 3N]")
   "6N : Nat"))

;; ========================================
;; C. Eigentrust reproducer: `cons r nil` packs to one compound
;; ========================================

(test-case "marg/eigentrust-sum-rows-typechecks"
  ;; The eigentrust reproducer: previously failed with `Unbound variable
  ;; sum-rows::1` because bare-token clauses produced split arities
  ;; (1, 3, 3 instead of 1, 1, 1). With the fix, all three clauses are
  ;; arity 1 and `sum-rows-eig` defines as `[List Nat] -> Nat` — a single
  ;; function, no per-clause helpers, no unbound reference.
  ;;
  ;; This test verifies the *parsing* fix (single arity, single function).
  ;; A latent compile-match-tree bug (variable bindings for outer-param
  ;; names broken across nested compound dispatch) is orthogonal and
  ;; tracked separately; see commit message for details. We exercise the
  ;; eigentrust case at empty + singleton inputs which are unaffected.
  (define results
    (run-ws
     (string-append
      "spec sum-rows-eig [List Nat] -> Nat\n"
      "defn sum-rows-eig\n"
      "  | nil            -> 0N\n"
      "  | cons r nil     -> r\n"
      "  | cons r rest    -> [+ r [sum-rows-eig rest]]\n"
      "eval [sum-rows-eig '[5N]]")))
  ;; First non-error result line confirms parse + type-check + arity-1 def.
  (check-true (for/or ([r (in-list results)])
                (and (string? r)
                     (string-contains? r "sum-rows-eig")
                     (string-contains? r "List Nat] -> Nat")))))

(test-case "marg/eigentrust-sum-rows-empty"
  ;; Empty list → first clause matches: nil → 0N (no nested binding bug).
  (define results
    (run-ws
     (string-append
      "spec sum-rows-eig2 [List Nat] -> Nat\n"
      "defn sum-rows-eig2\n"
      "  | nil            -> 0N\n"
      "  | cons r nil     -> r\n"
      "  | cons r rest    -> [+ r [sum-rows-eig2 rest]]\n"
      "eval [sum-rows-eig2 [the [List Nat] nil]]")))
  (check-true (for/or ([r (in-list results)])
                (and (string? r) (string-contains? r "0N")))))

(test-case "marg/eigentrust-sum-rows-singleton"
  ;; Singleton list → second clause matches: cons r nil → r.
  ;; This is the boundary that the fix unlocks — pre-fix the function
  ;; was arity-1 with only the nil clause, so any non-empty list would
  ;; hit ??__match-fail.
  (define results
    (run-ws
     (string-append
      "spec sum-rows-eig3 [List Nat] -> Nat\n"
      "defn sum-rows-eig3\n"
      "  | nil            -> 0N\n"
      "  | cons r nil     -> r\n"
      "  | cons r rest    -> [+ r [sum-rows-eig3 rest]]\n"
      "eval [sum-rows-eig3 '[42N]]")))
  (check-true (for/or ([r (in-list results)])
                (and (string? r) (string-contains? r "42N")))))

;; ========================================
;; D. Constructor patterns in non-first positions
;; ========================================
;; `[+ ... 0N]`-like patterns: peano addition with zero on the right.

(test-case "marg/ctor-pattern-non-first-position"
  ;; `add-zero-r | n zero -> n | n [suc m] -> [suc [add-zero-r n m]]`
  ;; Bare `n zero` has leading `n` (variable, not ctor) → falls back to 2 args.
  ;; This is the "bare patterns" case where the user genuinely wants N args.
  (check-equal?
   (run-ws-last
    (string-append
     "spec add-zr Nat -> Nat -> Nat\n"
     "defn add-zr\n"
     "  | n zero    -> n\n"
     "  | n [suc m] -> [suc [add-zr n m]]\n"
     "eval [add-zr 2N 3N]"))
   "5N : Nat"))

;; ========================================
;; E. Wildcards mixed in
;; ========================================

(test-case "marg/wildcard-in-bare-tokens"
  ;; `cons _ nil` — `cons` is leading ctor with 2 fields, 2 remaining tokens.
  ;; Should be packed as one pattern: cons-of-(_,nil).
  (check-equal?
   (run-ws-last
    (string-append
     "defn singleton?\n"
     "  | nil          -> false\n"
     "  | cons _ nil   -> true\n"
     "  | cons _ _     -> false\n"
     "eval [singleton? '[42N]]"))
   "true : Bool")
  (check-equal?
   (run-ws-last
    (string-append
     "defn singleton?2\n"
     "  | nil          -> false\n"
     "  | cons _ nil   -> true\n"
     "  | cons _ _     -> false\n"
     "eval [singleton?2 '[1N 2N]]"))
   "false : Bool"))

(test-case "marg/wildcard-in-all-var"
  ;; `_ _` — both wildcards, no leading ctor → 2 args.
  (check-equal?
   (run-ws-last
    (string-append
     "spec const-zero-2 Nat -> Nat -> Nat\n"
     "defn const-zero-2\n"
     "  | _ _ -> 0N\n"
     "eval [const-zero-2 5N 7N]"))
   "0N : Nat"))

;; ========================================
;; F. Mixed: some clauses pack, others don't
;; ========================================
;; All clauses must end up at the SAME arity. A bare-pattern clause
;; whose leading token is a ctor with matching arity packs to one
;; pattern; a `nil` clause is already one pattern. Both → arity 1.

(test-case "marg/mixed-leading-ctor-and-nullary"
  ;; nil (1 token, nullary ctor) + cons _ _ (3 tokens, packs to 1 compound)
  (check-equal?
   (run-ws-last
    (string-append
     "spec list-len-marg [List Nat] -> Nat\n"
     "defn list-len-marg\n"
     "  | nil          -> 0N\n"
     "  | cons _ rest  -> [suc [list-len-marg rest]]\n"
     "eval [list-len-marg '[10N 20N 30N]]"))
   "3N : Nat"))

;; ========================================
;; G. Bracketed form continues to work (regression)
;; ========================================
;; `[cons r nil]` (single bracket) is the explicit way to write a
;; compound pattern in a multi-arg context. This remains supported.

(test-case "marg/double-bracket-compound-still-works"
  ;; [[cons _ nil]] (double bracket) is the legacy way to write a
  ;; compound pattern as a single arg in the bracketed form: outer
  ;; bracket = "this is the params list with 1 element"; inner bracket
  ;; = "the element is the compound pattern (cons _ nil)". This path
  ;; is unchanged by the fix (regression check).
  (check-equal?
   (run-ws-last
    (string-append
     "defn singleton?-dblbracket\n"
     "  | [[nil]]        -> false\n"
     "  | [[cons _ nil]] -> true\n"
     "  | [[cons _ _]]   -> false\n"
     "eval [singleton?-dblbracket '[42N]]"))
   "true : Bool"))
