#lang racket/base

;;;
;;; test-general-body-01.rkt — PPN 4C Addendum Phase 4B.5.a (§18.21.26)
;;;
;;; General-body / mutual-fn forward-ref residuation via the demand-driven
;;; sweep: `def a := [f b]` (body NOT a bare var) with forward referents
;;; DEFERS (the elaborate-var pending arm is the detector; the placeholder
;;; stores the ORIGINAL SURF); the sweep re-runs the def — fresh context via
;;; process-command's own reset — when the referents ground, alternating with
;;; the NET-1 drive to fixpoint. Mutual FNS land via the annotated path's
;;; meta-free pre-register (specs or defn hole-types): the type-level cycle
;;; breaks at the pre-register — the (c-1)≡(c-2) degenerate case (§18.21.25.3).
;;;
;;; Residuation is process-file-GATED (DQ4) — all fixtures run via process-file.
;;;
;;; Boundaries pinned here (NOT bugs):
;;;   - inferred self-recursion stays unbound at file-end (status-quo-
;;;     equivalent; 4B.5.b's size-1 SCC pass owns it)
;;;   - genuine multi-arity defn clauses with forward refs error with the
;;;     status-quo unbound (the in-def-group guard; PM Track 12B)
;;;   - uses depending on textually-LATER defs stay unbound (4C territory)
;;;

(require rackunit
         racket/list
         racket/file
         "../driver.rkt"
         "../namespace.rkt"
         "../errors.rkt")

;; process-file a fixture string under a fresh per-file mnr (isolation).
(define (run-file-fixture str)
  (define tmp (make-temporary-file "genbody-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display str out)))
  (define result
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f])
      (process-file (path->string tmp))))
  (delete-file tmp)
  result)

(define (unbound-for? results name)
  (for/or ([r (in-list results)])
    (and (unbound-variable-error? r)
         (eq? (unbound-variable-error-name r) name))))

(define (has? results s) (and (member s results) #t))

(define (error-count results)
  (for/sum ([r (in-list results)]) (if (prologos-error? r) 1 0)))

;; ① the .a deliverable: a general body with a forward referent defers, the
;; file-end sweep re-runs it when the referent grounds.
(test-case "4B.5.a: forward general body resolves (def a := [int+ b 1]; def b := 5)"
  (define rs (run-file-fixture "ns gb1\ndef a := [int+ b 1]\ndef b := 5"))
  (check-true (has? rs "a : Int defined."))
  (check-true (has? rs "b : Int defined."))
  (check-equal? (error-count rs) 0))

;; ② G2 parity: backward control commits the same surface result.
(test-case "4B.5.a: backward control parity (def b := 5; def a := [int+ b 1])"
  (define rs (run-file-fixture "ns gb2\ndef b := 5\ndef a := [int+ b 1]\na"))
  (check-true (has? rs "a : Int defined."))
  (check-true (has? rs "6 : Int")))

;; ③ general chain — multi-pass sweep (a waits on b, b waits on c).
(test-case "4B.5.a: general-body chain resolves (a←b←c)"
  (define rs (run-file-fixture
              "ns gb3\ndef a := [int+ b 2]\ndef b := [int+ c 1]\ndef c := 5"))
  (check-true (has? rs "a : Int defined."))
  (check-true (has? rs "b : Int defined."))
  (check-true (has? rs "c : Int defined."))
  (check-equal? (error-count rs) 0))

;; ④ the W4 demand trigger: a mid-file USE of a deferred general-body def
;; sweeps + retries, then evaluates (the amended DEF-vs-USE boundary).
(test-case "4B.5.a: mid-file use of a deferred def resolves via the demand sweep"
  (define rs (run-file-fixture "ns gb4\ndef a := [int+ b 1]\ndef b := 5\na"))
  (check-true (has? rs "a : Int defined."))
  (check-true (has? rs "6 : Int"))
  (check-equal? (error-count rs) 0))

;; ⑤ mixed δ + general: x := a is the 4B.3 bare-ref δ tier; a := [int+ b 1] is
;; the sweep tier — the fixpoint alternation (drive ↔ sweep) resolves both.
(test-case "4B.5.a: mixed bare-ref δ + general body resolve together"
  (define rs (run-file-fixture
              "ns gb5\ndef x := a\ndef a := [int+ b 1]\ndef b := 5"))
  (check-true (has? rs "x : Int defined."))
  (check-true (has? rs "a : Int defined."))
  (check-true (has? rs "b : Int defined."))
  (check-equal? (error-count rs) 0))

;; ⑥ G1 (PR #14 literal): spec'd single-arity mutual fns — the type-level
;; cycle breaks at the annotated path's meta-free pre-register; the use
;; demand-sweeps and evaluates.
(test-case "4B.5.a (G1): spec'd mutual recursion resolves + evaluates"
  (define rs (run-file-fixture
              (string-append
               "ns gb6\n"
               "spec even? Nat -> Bool\n"
               "defn even?\n  | zero  -> true\n  | suc n -> [odd? n]\n"
               "spec odd? Nat -> Bool\n"
               "defn odd?\n  | zero  -> false\n  | suc n -> [even? n]\n"
               "[even? 4N]")))
  (check-true (has? rs "even? : Nat -> Bool defined."))
  (check-true (has? rs "odd? : Nat -> Bool defined."))
  (check-true (has? rs "true : Bool"))
  (check-equal? (error-count rs) 0))

;; ⑦ bare (spec-less) mutual fns — defn's hole-typed annotation routes through
;; the same mechanism (hole-wildcard pre-register).
(test-case "4B.5.a: spec-less mutual recursion resolves + evaluates"
  (define rs (run-file-fixture
              (string-append
               "ns gb7\n"
               "defn myeven\n  | zero  -> true\n  | suc n -> [myodd n]\n"
               "defn myodd\n  | zero  -> false\n  | suc n -> [myeven n]\n"
               "[myeven 4N]")))
  (check-true (has? rs "true : Bool"))
  (check-equal? (error-count rs) 0))

;; ⑧ typo in a general body — `zzz` is never a def-head (absent, not pending)
;; → NOT deferred; the unbound error stays immediate at the command.
(test-case "4B.5.a: typo in general body errors immediately (absent ≠ pending)"
  (define rs (run-file-fixture "ns gb8\ndef a := [int+ zzz 1]"))
  (check-true (unbound-for? rs 'zzz)))

;; ⑨ annotated general body with a TYPE MISMATCH — the deferred re-run's
;; check fails: a TYPE error (not Unbound) lands in a's slot; b still defines.
(test-case "4B.5.a: deferred annotated mismatch → type error, not unbound"
  (define rs (run-file-fixture "ns gb9\ndef a : String := [int+ b 1]\ndef b := 5"))
  (check-true (has? rs "b : Int defined."))
  (check-equal? (error-count rs) 1)
  (check-false (unbound-for? rs 'a))   ;; it's a TYPE error, not unbound
  (check-false (has? rs "a : String defined.")))

;; ⑩ BOUNDARY (4B.5.b's): inferred self-recursion — self-pending defers and
;; stalls (no SCC pass yet) → file-end unbound; status-quo-equivalent (this
;; errored before 4B.5.a too, at the command). Pinned so .b's fix is visible.
(test-case "4B.5.a boundary: inferred self-recursion stays unbound (→ 4B.5.b SCC)"
  (define rs (run-file-fixture
              "ns gb10\ndef rec1 := [fn [x : Int] [rec1 x]]"))
  (check-true (unbound-for? rs 'rec1)))

;; ⑪ BOUNDARY (PM 12B's): genuine multi-arity defn with a forward ref in a
;; clause — the in-def-group guard emits the status-quo unbound (no clause
;; residuation; the group flattening is untouched).
(test-case "4B.5.a boundary: multi-arity clause forward ref → status-quo unbound"
  (define rs (run-file-fixture
              (string-append
               "ns gb11\n"
               "defn pick\n  | a -> [later a]\n  | a b -> a\n"
               "def later := [fn [x : Nat] x]")))
  ;; the guard fires inside the def-group (clause references pending `later`)
  (check-true (ormap prologos-error? rs)))

;; ⑫ BOUNDARY (4C's): a use depending on a textually-LATER def stays unbound
;; (the demand sweep resolves against the residue-so-far only).
(test-case "4B.5.a boundary: use before the referenced def stays unbound (4C)"
  (define rs (run-file-fixture "ns gb12\na\ndef a := [int+ b 1]\ndef b := 5"))
  (check-true (unbound-for? rs 'a))
  ;; the defs themselves still resolve at file-end
  (check-true (has? rs "a : Int defined.")))
