#lang racket/base

;;;
;;; PROLOGOS PRELUDE SYSTEM TESTS
;;; Verifies that `ns foo` auto-imports the prelude (Nat, Bool, List, Option,
;;; Result, Pair, traits, instances) without explicit require statements.
;;; Also tests :no-prelude opt-out, own-definition shadowing, and
;;; prelude-dependency circularity guard.
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../errors.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: check that a run-ns result contains an error
(define (result-has-error? results)
  (and (list? results)
       (ormap prologos-error? results)))


;; ================================================================
;; Tier 1: Containers — Option
;; ================================================================

(test-case "prelude: option constructors available"
  (check-equal?
   (run-ns "(ns test.pre19)\n(check (some Nat zero) : (Option Nat))")
   '("OK"))
  (check-equal?
   (run-ns "(ns test.pre20)\n(check (none Nat) : (Option Nat))")
   '("OK")))


(test-case "prelude: option predicates available"
  (check-equal?
   (run-ns "(ns test.pre21)\n(eval (some? Nat (some Nat zero)))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns test.pre22)\n(eval (none? Nat (none Nat)))")
   '("true : Bool")))


;; ================================================================
;; Tier 1: Containers — Option qualified alias (opt::)
;; ================================================================

(test-case "prelude: opt:: qualified access"
  (check-equal?
   (run-ns "(ns test.pre23)\n(eval (opt::unwrap-or Nat zero (some Nat (suc zero))))")
   '("1N : Nat"))
  (check-equal?
   (run-ns "(ns test.pre24)\n(eval (opt::unwrap-or Nat (suc (suc zero)) (none Nat)))")
   '("2N : Nat")))


;; ================================================================
;; Tier 1: Containers — Result
;; ================================================================

(test-case "prelude: result constructors available"
  (check-equal?
   (run-ns "(ns test.pre25)\n(check (ok Nat Bool zero) : (Result Nat Bool))")
   '("OK"))
  (check-equal?
   (run-ns "(ns test.pre26)\n(check (err Nat Bool true) : (Result Nat Bool))")
   '("OK")))


(test-case "prelude: result predicates available"
  (check-equal?
   (run-ns "(ns test.pre27)\n(eval (ok? Nat Bool (ok Nat Bool zero)))")
   '("true : Bool"))
  (check-equal?
   (run-ns "(ns test.pre28)\n(eval (err? Nat Bool (err Nat Bool true)))")
   '("true : Bool")))


;; ================================================================
;; Tier 2: Traits available
;; ================================================================

(test-case "prelude: Eq trait dict available"
  (check-equal?
   (run-ns "(ns test.pre29)\n(check nat-eq : (Eq Nat))")
   '("OK")))


(test-case "prelude: Ord trait dict available"
  (check-equal?
   (run-ns "(ns test.pre30)\n(check nat-ord : (Ord Nat))")
   '("OK")))


(test-case "prelude: ord comparison available"
  (check-equal?
   (run-ns "(ns test.pre32)\n(eval (ord-lt Nat nat-ord zero (suc zero)))")
   '("true : Bool")))


(test-case "prelude: Add trait instance dict available"
  ;; Nat--Add--dict is the Nat instance of Add, registered via instance loading
  (check-equal?
   (run-ns "(ns test.pre33)\n(check Nat--Add--dict : (Add Nat))")
   '("OK")))


;; ================================================================
;; :no-prelude opt-out
;; ================================================================

(test-case "no-prelude: core still available"
  ;; :no-prelude falls back to prologos.core only
  (check-equal?
   (run-ns "(ns test.pre36 :no-prelude)\n(eval (id Nat zero))")
   '("0N : Nat")))


(test-case "no-prelude: library names unbound"
  ;; add is from prologos.data.nat, should NOT be available with :no-prelude.
  ;; process-string returns error structs (not Racket exceptions).
  (check-true
   (result-has-error?
    (run-ns "(ns test.pre37 :no-prelude)\n(eval (add zero zero))"))))


;; ================================================================
;; Own-definition shadows prelude
;; ================================================================

(test-case "own def shadows prelude name"
  ;; User defines their own `map` — should shadow the prelude's list::map
  ;; Result includes "map : Nat defined." followed by the eval result
  (define results (run-ns "(ns test.pre38)\n(def map : Nat\n  (suc zero))\n(eval map)"))
  (check-not-false (member "1N : Nat" results)
                   "User's own map should evaluate to 1N"))


;; ================================================================
;; Prelude deps get only prologos.core (no circularity)
;; ================================================================

(test-case "prelude dependency gets core only"
  ;; A namespace starting with prologos.data.* should NOT get the full prelude
  ;; (would cause circular loading). It should still get prologos.core.
  (check-equal?
   (run-ns "(ns prologos.data.test-dep)\n(eval (id Nat zero))")
   '("0N : Nat")))


(test-case "prelude dependency does not get prelude names"
  ;; prologos.data.* namespace should NOT have `add` auto-imported
  (check-true
   (result-has-error?
    (run-ns "(ns prologos.data.test-dep2)\n(eval (add zero zero))"))))


(test-case "core dependency gets core only"
  ;; prologos.core.* should also only get core, not full prelude
  (check-true
   (result-has-error?
    (run-ns "(ns prologos.core.test-dep)\n(eval (add zero zero))"))))


;; ================================================================
;; Int operations (built-in, confirms no interference)
;; ================================================================

(test-case "prelude: int ops still work"
  (check-equal?
   (run-ns "(ns test.pre39)\n(eval (int+ 3 4))")
   '("7 : Int"))
  (check-equal?
   (run-ns "(ns test.pre40)\n(eval (int* 3 4))")
   '("12 : Int")))
