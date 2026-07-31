#lang racket/base

;;;
;;; Tests for Phase B: QTT Pipeline Integration
;;;
;;; Verifies that the QTT multiplicity checker is actually called from driver.rkt
;;; and that multiplicity violations produce structured errors.
;;;
;;; Positive tests: definitions with correct multiplicities pass.
;;; Negative tests: definitions violating `:0` or `:1` produce multiplicity-error.
;;; Regression guards: stdlib loads, mult-inference, and defn paths still work.
;;;

(require rackunit
         racket/path
         racket/list
         racket/string
         "test-support.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt"
         ;; QTT P4: pins the message-text → LSP diagnostic-code coupling (E1003)
         (only-in "../lsp/diagnostics.rkt" error->diagnostic))

;; Helper: run prologos code in a fresh environment
(define (run s)
  (with-fresh-meta-env
    (process-string s)))

;; Helper: run prologos code and return the first result
(define (run-first s)
  (first (run s)))

;; Helper: run prologos code and return the last result
(define (run-last s)
  (last (run s)))

;; Helper: run code with namespace system active (for module loading)
(define (run-ns s)
  (with-fresh-meta-env
    (parameterize ([current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry])
      (install-module-loader!)
      (process-string s))))

;; Helper: run code with namespace and return last result
(define (run-ns-last s)
  (last (run-ns s)))

;; ========================================
;; Positive tests: correct multiplicities pass QTT
;; ========================================

(test-case "qtt-pipeline/unrestricted-identity"
  ;; Default multiplicity (mw) — any usage is fine
  (check-equal?
   (run-last "(def id <(-> Nat Nat)> (fn [x <Nat>] x))\n(eval (id zero))")
   "0N : Nat"))

(test-case "qtt-pipeline/linear-identity"
  ;; Linear (:1) used exactly once — correct
  (check-equal?
   (run-last "(def lin-id <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] x))\n(eval (lin-id zero))")
   "0N : Nat"))

(test-case "qtt-pipeline/erased-const"
  ;; Erased (:0) not used in body — correct
  (check-equal?
   (run-last "(def erased-c <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] zero))\n(eval (erased-c zero))")
   "0N : Nat"))

(test-case "qtt-pipeline/unrestricted-used-twice"
  ;; Unrestricted (mw) can be used any number of times — use natrec to reference x twice
  (check-equal?
   (run-first "(def use-twice <(-> Nat Nat)> (fn [x <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))")
   "use-twice : Nat -> Nat defined."))

(test-case "qtt-pipeline/unrestricted-used-zero"
  ;; Unrestricted (mw) — not using is fine too
  (check-equal?
   (run-first "(def drop <(-> Nat Nat)> (fn [x <Nat>] zero))")
   "drop : Nat -> Nat defined."))

(test-case "qtt-pipeline/inferred-path-simple"
  ;; Type-inferred def (no annotation) — should pass QTT
  (check-equal?
   (run-last "(def one (suc zero))\n(eval one)")
   "1N : Nat"))

(test-case "qtt-pipeline/defn-natrec-based"
  ;; defn with natrec — uses bare match on Nat
  ;; spec+defn goes through process-def-group → process-def
  (check-equal?
   (run-last "(def double <(-> Nat Nat)> (fn [n <Nat>] (natrec (fn [_ <Nat>] Nat) zero (fn [_ <Nat>] (fn [r <Nat>] (suc (suc r)))) n)))\n(eval (double (suc (suc zero))))")
   "4N : Nat"))

(test-case "qtt-pipeline/let-in-def"
  ;; Let expressions elaborate to app(lam, arg) — QTT beta-typed app handles this
  (check-equal?
   (run-last "(def r <Nat> (let a : Nat := (suc zero) a))\n(eval r)")
   "1N : Nat"))

;; ========================================
;; Negative tests: multiplicity violations produce errors
;; ========================================

(test-case "qtt-pipeline/linear-used-twice-is-error"
  ;; Linear (:1) used twice → multiplicity violation
  ;; natrec uses the target twice (base=x, step uses x again implicitly via the recursion)
  ;; But simpler: add x x uses x twice
  (define result
    (run-first "(def dup <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for linear variable used twice"))

(test-case "qtt-pipeline/linear-not-used-is-error"
  ;; Linear (:1) not used → multiplicity violation
  (define result
    (run-first "(def drop <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for linear variable not used"))

(test-case "qtt-pipeline/erased-used-is-error"
  ;; Erased (:0) used at runtime → multiplicity violation
  (define result
    (run-first "(def use-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] x))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for erased variable used at runtime"))

(test-case "qtt-pipeline/erased-used-in-suc-is-error"
  ;; Erased (:0) used in suc — multiplicity violation
  (define result
    (run-first "(def suc-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] (suc x)))"))
  (check-true (multiplicity-error? result)
              "Expected multiplicity-error for erased variable used in suc"))

(test-case "qtt-pipeline/error-message-contains-multiplicity"
  ;; The error message should mention "Multiplicity violation"
  (define result
    (run-first "(def use-erased <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] x))"))
  (check-true (multiplicity-error? result))
  (check-true (string-contains? (prologos-error-message result) "Multiplicity")
              "Error message should mention 'Multiplicity'"))

(test-case "qtt-pipeline/linear-violation-removes-def"
  ;; After a QTT failure, the definition should be removed from global env
  ;; (not left as a half-registered entry)
  (define results
    (run "(def bad <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))\n(eval bad)"))
  (check-true (multiplicity-error? (first results))
              "First result should be multiplicity-error")
  ;; Second result should be an unbound variable error (def was removed)
  (check-true (prologos-error? (second results))
              "Second result should be an error (bad is not defined)"))

;; ========================================
;; Pattern matching IS multiplicity-checked (QTT P2, 2026-07-30)
;; ========================================
;; `contains-unsupported-qtt?` used to return #t for expr-reduce, so the driver
;; skipped checkQ-top for every `match` and every multi-clause `defn` — the
;; language's primary dispatch form. These pin that the arm now runs, that its
;; arms JOIN (one runs), and that sequential use inside an arm still ADDs.

(test-case "qtt-reduce/linear-used-once-in-EACH-arm-is-legal"
  ;; `y` is linear and appears in both arms; only one arm runs. The scrutinee
  ;; `s` is unrestricted, so it contributes nothing to y's count.
  (define result
    (run-first
     (string-append
      "(def m1ok <(Pi [y :1 <Nat>] (Pi [s <Nat>] Nat))> "
      "(fn [y :1 <Nat>] (fn [s <Nat>] (match s (zero -> y) (suc _ -> y)))))")))
  (check-false (multiplicity-error? result)
               (format "linear var once per arm must be legal; got: ~v" result)))

(test-case "qtt-reduce/linear-used-in-NEITHER-arm-is-error"
  ;; m1 demands exactly one use; m0 join m0 = m0.
  (define result
    (run-first
     (string-append
      "(def m1unused <(Pi [y :1 <Nat>] (Pi [s <Nat>] Nat))> "
      "(fn [y :1 <Nat>] (fn [s <Nat>] (match s (zero -> zero) (suc _ -> zero)))))")))
  (check-true (multiplicity-error? result)
              (format "unused linear var must violate; got: ~v" result)))

(test-case "qtt-reduce/linear-used-TWICE-IN-ONE-arm-is-error"
  ;; Within an arm the uses still ADD — the join is branch-vs-branch only.
  ;; THE pin for the original defect: this exact shape (a linear param
  ;; duplicated inside a match arm) was ACCEPTED with 0 errors before P2.
  ;; `(natrec motive y step y)` uses y twice (base AND target) — the same
  ;; double-use idiom `qtt-pipeline/linear-used-twice-is-error` above uses.
  (define dbl
    (string-append "(natrec (fn [_ <Nat>] Nat) y "
                   "(fn [_ <Nat>] (fn [r <Nat>] r)) y)"))
  (define result
    (run-first
     (string-append
      "(def m1dup <(Pi [y :1 <Nat>] (Pi [s <Nat>] Nat))> "
      "(fn [y :1 <Nat>] (fn [s <Nat>] "
      "(match s (zero -> " dbl ") (suc _ -> " dbl ")))))")))
  (check-true (multiplicity-error? result)
              (format "two uses in ONE arm must violate; got: ~v" result)))

(test-case "qtt-reduce/scrutinee-ADDs-to-the-arm-join"
  ;; The scrutinee always runs, so a linear var matched on AND used in an arm is
  ;; used twice. Pins add(scrutinee, join(arms)) rather than a flat join.
  (define result
    (run-first
     (string-append
      "(def m1scrut <(Pi [y :1 <Nat>] Nat)> "
      "(fn [y :1 <Nat>] (match y (zero -> y) (suc _ -> y))))")))
  (check-true (multiplicity-error? result)
              (format "scrutinee must ADD to the arm join; got: ~v" result)))

(test-case "qtt-reduce/linear-consumed-in-ONE-arm-only-is-error"
  ;; P3, linear-per-path: the arms must agree about each linear resource. `y` is
  ;; consumed on the zero arm and DROPPED on the suc arm — a leak, and accepted
  ;; before the agreement guard.
  (define result
    (run-first
     (string-append
      "(def m1leak <(Pi [y :1 <Nat>] (Pi [s <Nat>] Nat))> "
      "(fn [y :1 <Nat>] (fn [s <Nat>] (match s (zero -> y) (suc _ -> zero)))))")))
  (check-true (multiplicity-error? result)
              (format "dropping a linear var on one arm must violate; got: ~v" result)))

(test-case "qtt-reduce/the-same-shape-UNRESTRICTED-is-still-fine"
  ;; The guard must fire only at linear positions (drift risk 2).
  (check-false
   (multiplicity-error?
    (run-first
     (string-append
      "(def mwok <(Pi [y <Nat>] (Pi [s <Nat>] Nat))> "
      "(fn [y <Nat>] (fn [s <Nat>] (match s (zero -> y) (suc _ -> zero)))))")))))

(test-case "qtt-reduce/unrestricted-match-still-fine"
  ;; The overwhelmingly common case: no multiplicity annotations anywhere.
  ;; Turning checking ON must not disturb it.
  (check-equal?
   (run-first
    (string-append
     "(def classify <(-> Nat Nat)> "
     "(fn [x <Nat>] (match x (zero -> zero) (suc _ -> (suc zero)))))"))
   "classify : Nat -> Nat defined."))

(test-case "qtt-reduce/let-bound-match-does-not-spuriously-fail"
  ;; A `let` desugars to (app (lam ...) arg). checkQ had no beta-redex arm, so
  ;; before P2 added one this fell through to inferQ, which has no reduce arm,
  ;; and reported a bogus "Multiplicity violation".
  (define result
    (run-first
     (string-append
      "(def letmatch <Nat> "
      "(let a : Nat := (suc zero) (match a (zero -> zero) (suc _ -> a))))")))
  (check-false (multiplicity-error? result)
               (format "let-bound match must not violate; got: ~v" result)))

;; ========================================
;; The multiplicity message says what actually went wrong (QTT P4, 2026-07-30)
;; ========================================
;; `multiplicity-error`'s Variable / Declared / Actual fields always existed and
;; always rendered — they were filled with the string LITERALS "declared" and
;; "actual", and Variable got the entire pretty-printed body. P4 computes real
;; values via `explain-qtt-failure` (qtt.rkt, beside the rules it reproduces).
;;
;; The detail is asserted on the MESSAGE, deliberately: tools/run-file.rkt and
;; the `;;N=>` acceptance harness print `prologos-error-message` ALONE, so detail
;; living only in the struct fields is invisible to users. The first draft did
;; exactly that and these assertions are what pin it.

(define (qtt-msg s) (prologos-error-message (run-first s)))

(test-case "qtt-msg/linear-used-twice names the parameter and both multiplicities"
  (define m (qtt-msg "(def dup <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] (natrec (fn [_ <Nat>] Nat) x (fn [_ <Nat>] (fn [r <Nat>] (suc r))) x)))"))
  (check-true (regexp-match? #rx"Multiplicity violation" m) m)   ;; LSP trigger
  (check-true (regexp-match? #rx"declared" m) m)
  (check-true (regexp-match? #rx"linear" m) m)
  (check-true (regexp-match? #rx"used more than once" m) m)
  ;; the placeholder literals are gone
  (check-false (regexp-match? #rx"Actual usage: actual" m) m))

(test-case "qtt-msg/linear-unused says it must be consumed"
  (define m (qtt-msg "(def drop <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))"))
  (check-true (regexp-match? #rx"is not used" m) m)
  (check-true (regexp-match? #rx"must be consumed" m) m))

(test-case "qtt-msg/erased-used explains erasure rather than repeating the code"
  (define m (qtt-msg "(def ue <(Pi [x :0 <Nat>] Nat)> (fn [x :0 <Nat>] x))"))
  (check-true (regexp-match? #rx"erased" m) m)
  (check-true (regexp-match? #rx"cannot be used at runtime" m) m))

(test-case "qtt-msg/branch disagreement names the EVERY-path rule"
  ;; The class P3 introduced, which had no diagnostic at all before P4.
  (define m (qtt-msg (string-append
                      "(def leak <(Pi [y :1 <Nat>] (Pi [c <Bool>] Nat))> "
                      "(fn [y :1 <Nat>] (fn [c <Bool>] "
                      "(boolrec (fn [_ <Bool>] Nat) y zero c))))")))
  (check-true (regexp-match? #rx"Multiplicity violation" m) m)
  (check-true (regexp-match? #rx"EVERY path" m) m)
  (check-true (regexp-match? #rx"branches disagree" m) m)
  ;; names what each side did, not just that something is wrong
  (check-true (regexp-match? #rx"used once" m) m)
  (check-true (regexp-match? #rx"not used" m) m))

(test-case "qtt-msg/still maps to LSP code E1003"
  ;; lsp/diagnostics.rkt derives the code by regexp over the message, testing
  ;; `type.?mismatch` FIRST. A reworded multiplicity message that gained that
  ;; substring — or lost "multiplicity" — would silently retag the whole class.
  (for ([src (in-list
              (list "(def drop <(Pi [x :1 <Nat>] Nat)> (fn [x :1 <Nat>] zero))"
                    (string-append
                     "(def leak <(Pi [y :1 <Nat>] (Pi [c <Bool>] Nat))> "
                     "(fn [y :1 <Nat>] (fn [c <Bool>] "
                     "(boolrec (fn [_ <Bool>] Nat) y zero c))))")))])
    (define r (run-first src))
    (check-true (multiplicity-error? r) src)
    (check-equal? (hash-ref (error->diagnostic r) 'code) "E1003" src)))

;; ========================================
;; The QTT guard is GONE: Vec / Fin / foreign defs are checked (QTT P5)
;; ========================================
;; `contains-unsupported-qtt?` used to make the driver SKIP checkQ-top for any
;; def whose body contained a Vec/Fin constructor or eliminator, or a foreign-fn
;; value. It is deleted; these pin that such defs now go THROUGH the gate rather
;; than around it. Before P5 there was no driver-path Vec/Fin test at all — the
;; existing ones drive typing-core directly and never touch the gate.

(test-case "qtt-guard/Vec defs pass the gate rather than skipping it"
  (check-equal? (run-first "(def v <(Vec Nat zero)> (vnil Nat))")
                "v : [Vec Nat 0N] defined.")
  (check-equal?
   (run-first "(def v1 <(Vec Nat (suc zero))> (vcons Nat zero zero (vnil Nat)))")
   "v1 : [Vec Nat 1N] defined."))

(test-case "qtt-guard/Fin defs pass the gate"
  (check-equal? (run-first "(def i0 <(Fin (suc zero))> (fzero zero))")
                "i0 : [Fin 1N] defined.")
  (check-equal?
   (run-first "(def i1 <(Fin (suc (suc zero)))> (fsuc (suc zero) (fzero zero)))")
   "i1 : [Fin 2N] defined."))

(test-case "qtt-guard/a linear value consed TWICE into a Vec is now an error"
  ;; THE point of the retirement: this def used to skip QTT entirely and be
  ;; accepted. `y` is linear and stored in both the head and the tail.
  (define result
    (run-first
     (string-append
      "(def dupvec <(Pi [y :1 <Nat>] (Vec Nat (suc (suc zero))))> "
      "(fn [y :1 <Nat>] (vcons Nat (suc zero) y (vcons Nat zero y (vnil Nat)))))")))
  (check-true (multiplicity-error? result)
              (format "consing a linear value twice must violate; got: ~v" result)))

(test-case "qtt-guard/consing a linear value ONCE is fine"
  ;; The positive control for the negative above — the arm must not simply
  ;; reject everything Vec-shaped.
  (check-false
   (multiplicity-error?
    (run-first
     (string-append
      "(def okvec <(Pi [y :1 <Nat>] (Vec Nat (suc zero)))> "
      "(fn [y :1 <Nat>] (vcons Nat zero y (vnil Nat))))")))))

(test-case "qtt-guard/vindex counts its INDEX as well as the vector"
  ;; A linear Fin index used once is fine; the vector is unrestricted here.
  (check-false
   (multiplicity-error?
    (run-first
     (string-append
      "(def idx1 <(Pi [i :1 <(Fin (suc zero))>] Nat)> "
      "(fn [i :1 <(Fin (suc zero))>] "
      "(vindex Nat (suc zero) i (vcons Nat zero zero (vnil Nat)))))")))))

(test-case "qtt-guard/a capture-bearing racket block is checked, and passes"
  ;; Capture-bearing blocks desugar to (app (foreign-fn ...) cap ...) and are
  ;; the only in-tree defs that actually carried an expr-foreign-fn past the
  ;; old guard. Top-level captures contribute no usage, so they stay green.
  (check-true
   (string-contains?
    (format "~a"
            (run-ns-last
             (string-append
              "(def n : Nat (suc (suc zero)))\n"
              "(def r : Nat racket{(add1 n)} (n : Nat) -> (r : Nat))\n(eval r)")))
    "3N")))

(test-case "qtt-guard/capturing a LINEAR variable in a racket block errors"
  ;; The capture desugar builds each capture binder at 'mw (foreign code may use
  ;; a capture any number of times), so a linear local captured into a block is
  ;; correctly rejected. Newly reachable now that foreign-fn defs pass the gate —
  ;; nothing covered this before.
  (define result
    (run-ns-last
     (string-append
      "(def f <(Pi [y :1 <Nat>] Nat)> "
      "(fn [y :1 <Nat>] racket{(add1 y)} (y : Nat) -> (r : Nat)))")))
  (check-true (prologos-error? result)
              (format "capturing a linear var must error; got: ~v" result)))

;; ========================================
;; Regression guards: existing functionality still works
;; ========================================

(test-case "qtt-pipeline/stdlib-nat-loads"
  ;; The nat stdlib loads and add works
  (check-equal?
   (run-ns-last "(ns qtt-r1)\n(imports [prologos::data::nat :refer [add]])\n(eval (add (suc (suc zero)) (suc (suc (suc zero)))))")
   "5N : Nat"))

(test-case "qtt-pipeline/stdlib-bool-loads"
  ;; The bool stdlib loads
  (check-equal?
   (run-ns-last "(ns qtt-r2)\n(imports [prologos::data::bool :refer [not]])\n(eval (not true))")
   "false : Bool"))

(test-case "qtt-pipeline/mult-inference-still-works"
  ;; Omitted multiplicities still default to mw and work
  (check-equal?
   (run-last "(def id <(-> Nat Nat)> (fn [x <Nat>] x))\n(eval (id (suc zero)))")
   "1N : Nat"))

(test-case "qtt-pipeline/posit8-basic"
  ;; Posit8 operations pass QTT
  (check-equal?
   (run-first "(def one <Posit8> (p8-from-nat (suc zero)))")
   "one : Posit8 defined."))

(test-case "qtt-pipeline/eval-command-not-qtt-checked"
  ;; eval commands don't go through QTT — they're ephemeral
  ;; This verifies that eval path is unaffected
  (check-equal?
   (run-first "(eval (suc (suc zero)))")
   "2N : Nat"))
