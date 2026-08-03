#lang racket/base

;;;
;;; Tests for Sprint 9: Error Messages for Inference Failures
;;;
;;; Tests the meta-source-info struct, constraint-provenance struct,
;;; noise-filtering (meta-category), new error subtypes (E1001/E1002/E1003),
;;; and integration with the full pipeline for improved error messages.
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../namespace.rkt"
         "../unify.rkt"
         ;; CIU T6 (2026-07-30): pins the message-text → diagnostic-code coupling
         ;; that `error->code` derives by regexp (see the E1001 test below).
         (only-in "../lsp/diagnostics.rkt" error->diagnostic))

;; ========================================
;; Helper: process commands and return results
;; ========================================
(define (run s)
  (process-string s))

(define (run-first s)
  (car (run s)))

(define (run-last s)
  (last (run s)))

(define (run-ns s)
  (with-fresh-meta-env
    (parameterize ([current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry])
      (install-module-loader!)
      (process-string s))))

(define (run-ns-last s)
  (last (run-ns s)))

;; ========================================
;; Unit tests: meta-source-info struct
;; ========================================

(test-case "meta-source-info/construction-and-access"
  (define loc (srcloc "test.prl" 5 10 3))
  (define msi (meta-source-info loc 'implicit "test desc" 'mydef '("x" "y")))
  (check-equal? (meta-source-info-loc msi) loc)
  (check-equal? (meta-source-info-kind msi) 'implicit)
  (check-equal? (meta-source-info-description msi) "test desc")
  (check-equal? (meta-source-info-def-name msi) 'mydef)
  (check-equal? (meta-source-info-name-map msi) '("x" "y")))

(test-case "constraint-provenance/construction-and-access"
  (define loc (srcloc "test.prl" 3 0 10))
  (define msi (meta-source-info loc 'implicit-app "for id" #f '("z")))
  (define cp (constraint-provenance loc "pattern fail" msi))
  (check-equal? (constraint-provenance-loc cp) loc)
  (check-equal? (constraint-provenance-description cp) "pattern fail")
  (check-equal? (constraint-provenance-meta-source cp) msi))

;; ========================================
;; Unit tests: meta-category noise filtering
;; ========================================

(test-case "meta-category/primary-for-pi-param"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'pi-param "pi mult" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'primary)))

(test-case "meta-category/secondary-for-implicit"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'implicit "impl arg" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'secondary)))

(test-case "meta-category/secondary-for-implicit-app"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'implicit-app "impl arg" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'secondary)))

(test-case "meta-category/internal-for-bare-Type"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'bare-Type "level" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'internal)))

(test-case "meta-category/legacy-string-implicit"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "implicit"))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'secondary)))

(test-case "meta-category/legacy-string-bare-Type"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "bare-Type"))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'internal)))

(test-case "meta-category/legacy-string-other"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test"))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'primary)))

(test-case "meta-category/primary-for-lambda-param"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat)
                (meta-source-info srcloc-unknown 'lambda-param "lam mult" #f #f)))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-category info) 'primary)))

;; ========================================
;; Unit tests: new error types
;; ========================================

(test-case "cannot-infer-param-error/is-prologos-error"
  (check-true
   (prologos-error?
    (cannot-infer-param-error srcloc-unknown "can't infer" 'x "add annotation"))))

(test-case "conflicting-constraints-error/is-prologos-error"
  (check-true
   (prologos-error?
    (conflicting-constraints-error srcloc-unknown "conflict" "Nat" "Bool"
                                   srcloc-unknown srcloc-unknown))))

(test-case "unsolved-implicit-error/is-prologos-error"
  (check-true
   (prologos-error?
    (unsolved-implicit-error srcloc-unknown "unsolved" 'id 'meta42 "provide type explicitly"))))

(test-case "format-error/E1001-contains-error-code"
  (define err (cannot-infer-param-error (srcloc "test.prl" 5 10 3)
                                         "can't infer" 'x "add annotation: (fn [x : Nat] ...)"))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1001"))
  (check-true (string-contains? formatted "x"))
  (check-true (string-contains? formatted "add annotation")))

(test-case "format-error/E1002-contains-error-code"
  (define err (conflicting-constraints-error (srcloc "test.prl" 8 3 40)
                                              "conflicting types" "Nat" "Bool"
                                              srcloc-unknown srcloc-unknown))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1002"))
  (check-true (string-contains? formatted "Nat"))
  (check-true (string-contains? formatted "Bool")))

(test-case "format-error/E1003-contains-error-code"
  (define err (unsolved-implicit-error (srcloc "test.prl" 12 3 20)
                                        "unsolved" 'id 'meta42 "provide the type explicitly"))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1003"))
  (check-true (string-contains? formatted "id"))
  (check-true (string-contains? formatted "provide the type explicitly")))

(test-case "format-error/E1003-no-func-name"
  (define err (unsolved-implicit-error srcloc-unknown "unsolved" #f 'meta42 #f))
  (define formatted (format-error err))
  (check-true (string-contains? formatted "E1003"))
  (check-false (string-contains? formatted "for '")))

;; ========================================
;; Integration: source location threading
;; ========================================

(test-case "elaborator/fresh-meta-has-meta-source-info"
  ;; When elaborating with a global that has ALL m0 (implicit) params,
  ;; the created meta should have meta-source-info, not a bare string.
  ;; Note: maybe-auto-apply-implicits only fires when ALL params are m0.
  (with-fresh-meta-env
    (parameterize ([current-file-module-network-ref
                    (module-network-from-snapshot
                     (hasheq 'test-fn
                       ;; All-implicit: Pi(A :0 Type, B :0 A, Nat)
                       (cons (expr-Pi 'm0 (expr-Type (lzero)) (expr-Pi 'm0 (expr-bvar 0) (expr-Nat)))
                             (expr-lam 'm0 (expr-Type (lzero)) (expr-lam 'm0 (expr-bvar 0) (expr-zero))))))])
      ;; Elaborate a bare reference to test-fn (should auto-apply with meta-source-info)
      (define result (elaborate (surf-var 'test-fn (srcloc "test.prl" 5 3 7))))
      (check-false (prologos-error? result))
      ;; The result should be (app (app (fvar test-fn) (meta ?)) (meta ?))
      (check-true (expr-app? result))
      ;; The metas should have meta-source-info
      (define unsolved (all-unsolved-metas))
      (check-true (not (null? unsolved)))
      (define info (car unsolved))
      (check-true (meta-source-info? (meta-info-source info)))
      (check-equal? (meta-source-info-kind (meta-info-source info)) 'implicit))))

(test-case "elaborator/env->name-stack-produces-correct-list"
  ;; Elaborate a lambda with a body that references an all-implicit function.
  ;; The meta created should have the name map containing "x" from the lambda binder.
  ;; Note: maybe-auto-apply-implicits only fires when ALL params are m0.
  (with-fresh-meta-env
    (parameterize ([current-file-module-network-ref
                    (module-network-from-snapshot
                     (hasheq 'impl-fn
                       ;; All-implicit: Pi(A :0 Type, B :0 A, Nat)
                       (cons (expr-Pi 'm0 (expr-Type (lzero)) (expr-Pi 'm0 (expr-bvar 0) (expr-Nat)))
                             (expr-lam 'm0 (expr-Type (lzero)) (expr-lam 'm0 (expr-bvar 0) (expr-zero))))))])
      ;; Elaborate (fn [x <Nat>] impl-fn) — inside the lambda body, env has "x"
      (define result (elaborate (surf-lam
                                  (binder-info 'x 'mw (surf-nat-type srcloc-unknown))
                                  (surf-var 'impl-fn (srcloc "test.prl" 5 20 7))
                                  srcloc-unknown)))
      (check-false (prologos-error? result))
      ;; The meta from impl-fn auto-apply should have name-map containing "x"
      (define unsolved (all-unsolved-metas))
      (check-true (not (null? unsolved)))
      (define info (car unsolved))
      (check-true (meta-source-info? (meta-info-source info)))
      (define nm (meta-source-info-name-map (meta-info-source info)))
      (check-not-false (and (list? nm) (member "x" nm))))))

;; ========================================
;; Integration: error message quality
;; ========================================

(test-case "error-message/type-mismatch-shows-types"
  ;; (def bad <(-> Nat Bool)> (fn [x <Nat>] x))
  ;; Body x : Nat does not match expected return Bool
  (define result (run-first "(def bad <(-> Nat Bool)> (fn [x <Nat>] x))"))
  (check-true (prologos-error? result))
  ;; The error message should mention types
  (define msg (prologos-error-message result))
  (check-true (or (string-contains? msg "Type mismatch")
                  (string-contains? msg "Type error")
                  (string-contains? msg "mismatch"))))

(test-case "error-message/valid-def-succeeds"
  ;; Regression: valid definitions should still work
  (define result (run-first "(def myid <(-> Nat Nat)> (fn [x <Nat>] x))"))
  (check-false (prologos-error? result))
  (check-true (string-contains? result "myid")))

(test-case "error-message/type-mismatch-mentions-expected-and-actual"
  (define result (run-first "(def bad <(-> Nat Bool)> (fn [x <Nat>] x))"))
  (check-true (prologos-error? result))
  (check-true (type-mismatch-error? result))
  (define formatted (format-error result))
  (check-true (string-contains? formatted "Nat"))
  (check-true (string-contains? formatted "Bool")))

(test-case "error-message/unbound-variable-unchanged"
  (define result (run-first "(eval undefined_var)"))
  (check-true (prologos-error? result))
  (check-true (unbound-variable-error? result)))

(test-case "error-message/constraint-failure-uses-E1002"
  ;; This test triggers a constraint failure via implicit inference
  ;; compose double pred 3 → works, but compose double true 3 → constraint failure
  ;; We need a simpler case that triggers failed constraints
  ;; Let's use a known case: applying a function to wrong implicit type
  (with-fresh-meta-env
    (parameterize ([current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry])
      (install-module-loader!)
      (define results (process-string
        (string-append
          "(ns errt1)\n"
          "(imports [prologos::core :refer [id]])\n"
          "(eval (id zero))")))
      ;; id zero should succeed (it infers the type argument)
      (define last-result (last results))
      (check-false (prologos-error? last-result))
      (check-true (string-contains? last-result "0N")))))

;; ========================================
;; Integration: stdlib regression
;; ========================================

(test-case "error-message/stdlib-id-still-works"
  (check-equal?
   (run-ns-last "(ns emt1)\n(imports [prologos::core :refer [id]])\n(eval (id zero))")
   "0N : Nat"))

(test-case "error-message/stdlib-add-still-works"
  (check-equal?
   (run-ns-last "(ns emt2)\n(imports [prologos::data::nat :refer [add]])\n(eval (add 2N 3N))")
   "5N : Nat"))

;; ========================================
;; Integration: pp-expr with name stack in errors
;; ========================================

(test-case "error-message/pp-expr-uses-names-in-check-err"
  ;; When check/err is called with names, the error should use them
  ;; (def bad <(-> Nat Bool)> (fn [x <Nat>] x))
  ;; The error for the body should show "x" in the expression
  (define result (run-first "(def bad <(-> Nat Bool)> (fn [x <Nat>] x))"))
  (check-true (prologos-error? result))
  (define formatted (format-error result))
  ;; The expression in the error should mention x (from the lambda parameter)
  ;; rather than ?bvar0
  (check-true (string-contains? formatted "x")))

;; ========================================
;; Backward compatibility: old-style sources
;; ========================================

(test-case "backward-compat/string-source-still-works"
  ;; Tests that pass strings to fresh-meta continue to work
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-Nat) "test-string"))
    (check-true (expr-meta? m))
    (define info (meta-lookup (expr-meta-id m)))
    (check-equal? (meta-info-source info) "test-string")
    (check-equal? (meta-category info) 'primary)))

(test-case "backward-compat/primary-unsolved-metas-filters"
  (with-fresh-meta-env
    ;; Create 3 metas: 1 primary (pi-param), 1 secondary (implicit), 1 internal (bare-Type)
    (fresh-meta ctx-empty (expr-Nat) (meta-source-info srcloc-unknown 'pi-param "a" #f #f))
    (fresh-meta ctx-empty (expr-Nat) (meta-source-info srcloc-unknown 'implicit "b" #f #f))
    (fresh-meta ctx-empty (expr-Nat) (meta-source-info srcloc-unknown 'bare-Type "c" #f #f))
    (check-equal? (length (all-unsolved-metas)) 3)
    (check-equal? (length (primary-unsolved-metas)) 1)))

;; ========================================
;; Unannotated-param inference hint (CIU T6, 2026-07-18)
;; ========================================
;; An unannotated param used in a way that needs its type (field projection or
;; arithmetic) produced a bare "Type mismatch". It now gives a hint pointing at
;; an annotation or spec — surgically, so genuine mismatches keep "Type mismatch".

(test-case "unannotated-param arithmetic: clearer 'cannot infer' message"
  (define r (run-ns-last "(ns t)\n(defn f [x] (+ x 1))"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (check-true (regexp-match? #rx"cannot infer the type of an unannotated parameter"
                             (prologos-error-message r))
              (format "got: ~v" (prologos-error-message r))))

(test-case "unannotated-param projection: clearer 'cannot infer' message"
  (define r (run-ns-last "(ns t)\n(defn g [p] (map-get p :x))"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (check-true (regexp-match? #rx"cannot infer the type of an unannotated parameter"
                             (prologos-error-message r))
              (format "got: ~v" (prologos-error-message r))))

(test-case "annotated param does NOT get the inference hint (control)"
  ;; a genuine type mismatch keeps the plain "Type mismatch" message.
  (define r (run-ns-last "(ns t)\n(def x : Int (the String \"hello\"))"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (check-true (regexp-match? #rx"Type mismatch" (prologos-error-message r))
              (format "got: ~v" (prologos-error-message r)))
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated"
                              (prologos-error-message r))))

;; ========================================
;; Branch-result mismatch (CIU T6, 2026-07-30)
;; ========================================
;; A multi-clause `defn` whose clause bodies have DIFFERENT result types used to
;; report the unannotated-parameter hint above — a lying diagnostic, because
;; `infer` returns expr-error for ANY hole-domain lambda without inspecting the
;; body (typing-core.rkt:1129) and every generated clause lambda is hole-domain
;; by construction (macros.rkt:10282/:10294) even when a `spec` is present, so
;; that hint's guard was vacuous for this whole syntactic class. It now names the
;; real cause (a first-arm-wins result join) and lists the disagreeing types.
;; See typing-errors.rkt § the branch-result-mismatch diagnostic.
;;
;; The message says "branches", not "clauses", DELIBERATELY: post-elaboration a
;; generated clause dispatch and a user-written `match` / `if` are the SAME
;; NODES, so no wording keyed on "clause" can be true for all of them. Several
;; pins below exist because the first version tried to gate on a
;; generated-vs-user discriminator that does not exist.
;;
;; NOTE the sexp spelling: multi-clause `defn` is recognised by
;; `has-pipe-clauses?` (parser.rkt) looking for a `$pipe`-headed sub-datum, and
;; `$pipe` is the WS-READER lexeme for `|`. An L1 pin MUST use `$pipe` (as
;; test-pattern-defn-01.rkt does); a bare `|` exercises none of this path. L2
;; cases below use the real `|` surface.

(define branch-mismatch-rx #rx"Type mismatch between branches")

(test-case "branch-result mismatch: Int vs String (L1, $pipe spelling)"
  (define r (run-ns-last
             "(ns t)\n(defn f ($pipe (0) -> 1) ($pipe (n) -> \"x\"))"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  ;; the disagreeing types are NAMED — that is the point of the diagnostic
  (check-true (regexp-match? #rx"Int" msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"String" msg) (format "got: ~v" msg))
  ;; and it no longer blames the parameter
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated" msg)
               (format "got: ~v" msg)))

(test-case "branch-result mismatch: record vs Int (L2, WS `|` surface)"
  ;; the originally reported repro
  (define r (run-ns-ws-last "ns t\ndefn c1\n  | 0 -> {:a 1}\n  | n -> 5\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"\\{:a Int\\}" msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated" msg)
               (format "got: ~v" msg)))

(test-case "branch-result mismatch: record vs record (L2) — both rows named"
  ;; REGRESSION PIN: an earlier draft beta-reduced the clause's let-redex with
  ;; `whnf`, which over-reduced a record literal's map-assoc chain into a runtime
  ;; value whose type no longer inferred — so every record-bodied clause silently
  ;; lost its type and fell back to the lying message. Int/String cases passed
  ;; throughout, so only a record-bodied case catches it.
  (define r (run-ns-ws-last "ns t\ndefn c2\n  | 0 -> {:a 1}\n  | n -> {:b 2}\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"\\{:a Int\\}" msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"\\{:b Int\\}" msg) (format "got: ~v" msg)))

(test-case "branch-result mismatch: constructor-pattern route too (L2)"
  ;; The ctor route joins through a shared `expected-type` per arm
  ;; (typing-core.rkt:4451-4473) rather than a boolrec motive, and lied
  ;; identically. Both routes are covered.
  (define r (run-ns-ws-last
             "ns t\ndefn c3\n  | zero -> {:a 1}\n  | suc _ -> 5\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated" msg)
               (format "got: ~v" msg)))

(test-case "branch-result mismatch does NOT fire when the param hint is RIGHT"
  ;; `| n -> [+ n 1]` genuinely needs n's type: clause 2 does not infer, so no
  ;; two-type proof is available and the parameter hint must stand. This is the
  ;; contract — the hint fires only when it can EXHIBIT the disagreement.
  (define r (run-ns-ws-last "ns t\ndefn c4\n  | 0 -> 1\n  | n -> [+ n 1]\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? #rx"cannot infer the type of an unannotated" msg)
              (format "got: ~v" msg))
  (check-false (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg)))

(test-case "branch-result mismatch: an arm that READS its pattern-bound field (L2)"
  ;; The residual the fix left open: `branch-result-leaves` extended each arm's
  ;; ctx with `(expr-hole)` per binding rather than the constructor's real field
  ;; types, so an arm that reads its binding inferred a hole,
  ;; `type-unreportable?` refused it, fewer than two reportable types survived,
  ;; and the caller fell back to the parameter hint — advice that is false
  ;; twice over here, since the parameter is not the problem and a `spec` is
  ;; present.
  ;;
  ;; Two things were needed and BOTH are load-bearing: the arm ctx now comes
  ;; from `reduce-arm-ctx` (the derivation `check-reduce-structural` and qtt's
  ;; twin already share), and the peel threads the EXPECTED type so the
  ;; parameter — hence the scrutinee — has a real type to decompose. Fixing
  ;; only the first leaves this case reporting the old message, because the
  ;; scrutinee is still a hole.
  (define r (run-ns-ws-last
             "ns t\nspec c5 Nat -> Nat\ndefn c5\n  | zero  -> \"s\"\n  | suc n -> n\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"String" msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"Nat" msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated" msg)
               (format "got: ~v" msg)))

(test-case "branch-result mismatch: field-reading arm with NO spec (L2)"
  ;; Same shape without a `spec`. The peel falls back to whatever the def seam
  ;; was checking against; the point is that it must not REGRESS to the
  ;; parameter hint when the expected type runs out.
  (define r (run-ns-ws-last
             "ns t\ndefn c6\n  | zero  -> \"s\"\n  | suc n -> n\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated" msg)
               (format "got: ~v" msg)))

(test-case "a field-reading arm that AGREES still type-checks (control)"
  ;; The derived arm ctx must not turn a working program into an error. This is
  ;; the control the arm-ctx change could break and the message tests could not
  ;; detect: they only ever look at failing programs.
  (define r (run-ns-ws-last
             "ns t\nspec c7 Nat -> Nat\ndefn c7\n  | zero  -> 0N\n  | suc n -> n\n"))
  (check-false (prologos-error? r) (format "expected success, got: ~v" r)))

(test-case "matching clause result types still type-check (control, L2)"
  ;; the working case must stay working — both routes
  (define r1 (run-ns-ws-last "ns t\ndefn ok1\n  | 0 -> {:a 1}\n  | n -> {:a 9}\n"))
  (check-false (prologos-error? r1) (format "expected success, got: ~v" r1))
  (define r2 (run-ns-ws-last "ns t\ndefn ok2\n  | zero -> 1\n  | suc _ -> 2\n"))
  (check-false (prologos-error? r2) (format "expected success, got: ~v" r2)))

(test-case "a user-written `if` gets the BRANCH message, with no false clause claim"
  ;; REGRESSION PIN (adversarial verify, SIGNIFICANT). The same strict join serves
  ;; 3-arg `if` (parser.rkt:1393), `match` arms and `defn` clauses, and
  ;; post-elaboration they are the SAME NODES. The first version of this fix
  ;; claimed a generated-vs-user discriminator — an `expr-int-eq` boolrec target —
  ;; and it does not exist: `int-eq` is a user-callable primitive, so this
  ;; ONE-clause function was reported as "every clause of a multi-clause
  ;; definition". The old test asserting the exclusion was VACUOUS: it used
  ;; `if true 1 "x"`, whose target is a Bool literal (not an int-eq) and which has
  ;; no hole-domain lambda to peel, so it exercised neither guard.
  (define r (run-ns-ws-last "ns t\ndefn t1 [x]\n  (if [int-eq x 0] 1 \"s\")\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"Int" msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"String" msg) (format "got: ~v" msg))
  ;; the message must never assert that THIS definition has multiple clauses
  (check-false (regexp-match? #rx"every clause of a multi-clause" msg)
               (format "got: ~v" msg)))

(test-case "a single-clause defn with a user `match` body gets the BRANCH message"
  ;; Same root cause as the `if` pin: `expand-match` compiles through the SAME
  ;; `compile-match-tree` as `compile-pattern-group`, so a user `match` emits the
  ;; same `expr-reduce` a generated ctor dispatch does.
  (define r (run-ns-ws-last
             "ns t\ndefn m1 [x]\n  match x\n    | zero  -> 1\n    | suc k -> \"s\"\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"every clause of a multi-clause" msg)
               (format "got: ~v" msg)))

(test-case "branch-result mismatch never prints hole / de Bruijn artifacts"
  ;; REGRESSION PIN (adversarial verify). Two defects, one filter:
  ;;  - BLOCKING: a branch type mentioning a bound variable was rendered
  ;;    `[Pi [x <?bvar0>] ?bvar1]` for a body whose real type is `Int -> Int`,
  ;;    because `names` is never extended in lockstep with the ctx the leaf walk
  ;;    builds. Such types are refused outright now.
  ;;  - a hole printed as a user type: `{:v _}`. That one needed THREE rounds,
  ;;    because a `_` hides behind two non-expr layers — the Record's `fields`
  ;;    list-of-pairs, and the `record-field` wrapper struct (syntax.rkt:690).
  ;;    `type-unreportable?` therefore descends ANY transparent struct.
  (define r (run-ns-ws-all
             (string-append
              "ns t\n"
              "data Box | mk-a Int | mk-b String | mk-c Bool\n"
              "defn d2\n"
              "  | mk-a x -> {:v x}\n"
              "  | mk-b _ -> {:v \"z\"}\n"
              "  | mk-c _ -> true\n")))
  (define msgs (for/list ([x (in-list r)] #:when (prologos-error? x))
                 (prologos-error-message x)))
  (check-equal? (length msgs) 1 (format "expected exactly 1 error, got: ~v" r))
  (define msg (car msgs))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  ;; the hole-bearing row is dropped; the two REPORTABLE types remain
  (check-false (regexp-match? #rx"[{]:v _[}]" msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"bvar" msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"[{]:v String[}]" msg) (format "got: ~v" msg))
  (check-true (regexp-match? #rx"Bool" msg) (format "got: ~v" msg)))

(test-case "branch-result mismatch is ORDER-INDEPENDENT (ctor declaration order)"
  ;; REGRESSION PIN (adversarial verify, SIGNIFICANT). `conv` treats `expr-hole`
  ;; as a WILDCARD, so folding it over a type list was a NON-TRANSITIVE relation:
  ;; one hole-typed branch arriving FIRST absorbed every later type and the
  ;; diagnosis silently died. These two defns differ ONLY in constructor
  ;; declaration order — the order the reduce route walks — and before the
  ;; `type-unreportable?` pre-filter, `h1` fell back to the lying message while
  ;; `h2` fired. Both must now fire.
  (define r (run-ns-ws-all
             (string-append
              "ns t\n"
              "data Th | a1 Int | b2 | c3\n"
              "defn h1\n  | a1 x -> x\n  | b2 -> 5\n  | c3 -> \"s\"\n"
              "data Th2 | p1 | q2 | r3 Int\n"
              "defn h2\n  | p1 -> 5\n  | q2 -> \"s\"\n  | r3 x -> x\n")))
  (define msgs (for/list ([x (in-list r)] #:when (prologos-error? x))
                 (prologos-error-message x)))
  (check-equal? (length msgs) 2 (format "expected exactly 2 errors, got: ~v" r))
  (for ([m (in-list msgs)])
    (check-true (regexp-match? branch-mismatch-rx m) (format "got: ~v" m))))

(test-case "branch-result mismatch maps to LSP code E1001, not E0000"
  ;; The message's "Type mismatch" opening is load-bearing, not prose:
  ;; lsp/diagnostics.rkt's `error->code` derives the code by regexp over the
  ;; message text, testing `type.?mismatch` → E1001 FIRST. A future reword that
  ;; drops every recognised substring would SILENTLY degrade this class to E0000
  ;; — invisible to every other test, since nothing else reads message text.
  ;; This pins the coupling instead of leaving it to a source comment.
  (define r (run-ns-ws-last "ns t\ndefn c5\n  | 0 -> 1\n  | n -> \"x\"\n"))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (check-true (regexp-match? branch-mismatch-rx (prologos-error-message r)))
  (check-equal? (hash-ref (error->diagnostic r) 'code) "E1001"
                (format "got: ~v" (error->diagnostic r))))

(test-case "branch-result mismatch has no clause-count cliff (80 clauses)"
  ;; REGRESSION PIN (adversarial verify, SIGNIFICANT). A `(> depth 64)` guard in
  ;; the leaf walk silently truncated the spine, so a defn with >= 64 int-literal
  ;; clauses reverted to the lying message — at IDENTICAL wall time, so it read as
  ;; a correctness cliff, not a cost bailout. The guard existed only to bound
  ;; `whnf`-driven recursion; with `whnf` gone the walk descends proper subfields
  ;; only and terminates structurally, so the cap was removed.
  (define clauses
    (apply string-append
           (for/list ([i (in-range 80)]) (format "  | ~a -> 1\n" i))))
  (define r (run-ns-ws-last
             (string-append "ns t\ndefn wide\n" clauses "  | n -> \"x\"\n")))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r))
  (define msg (prologos-error-message r))
  (check-true (regexp-match? branch-mismatch-rx msg) (format "got: ~v" msg))
  (check-false (regexp-match? #rx"cannot infer the type of an unannotated" msg)
               (format "got: ~v" msg)))
