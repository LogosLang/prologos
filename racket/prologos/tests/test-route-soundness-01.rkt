#lang racket/base

;;;
;;; Route-soundness gate (CIU T6 F1b.2 / D26)
;;;
;;; The on-network annotation-adoption gap: top-level expressions type
;;; on-network first; the expr-ann rule ADOPTS the annotation (and the app
;;; rule adopts the Pi domain) unconditionally at ⊥ positions, contradicting
;;; only at top — which a never-typed position cannot reach. Subtrees under
;;; rule-fn-#f / unregistered node kinds carry no :type evidence, so
;;; `(the Int {:a 1})` typed as Int and `[cons {:a 9} wide-row-list]` typed
;;; at the wide row (typecheck-then-runtime-miss, probed).
;;;
;;; The F1b.2 fix: a 5th refusal check in infer-on-network/err — the
;;; post-quiescence untyped-interior scan — re-routes such commands to the
;;; imperative checker. These tests pin: (1) the gap class REJECTS, at top
;;; level AND on the def routes (where the unsound type previously persisted
;;; into the global env when the QTT backstop was skipped, e.g. match
;;; bodies); (2) sound forms still pass (the re-route is behavior-preserving
;;; for correct code).
;;;

(require rackunit
         racket/list
         racket/path
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../relations.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt"
         "../macros.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Level-3: run a :no-prelude .prologos string through the full pipeline.
(define (run-file-string content)
  (define tmp (make-temporary-file "route-soundness-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)]
                   [current-defn-param-names (hasheq)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (last-result results) (last results))

;; ========================================
;; 1. The adoption gap class REJECTS (top-level expression route)
;; ========================================

(test-case "route-soundness: (the Int {:a 1}) rejects at top level"
  (define r (last-result (run-file-string "ns t :no-prelude\n(the Int {:a 1})\n")))
  (check-true (prologos-error? r)
              "a map literal annotated at Int must be a type error"))

(test-case "route-soundness: (the Int @[1 2]) rejects (pvec-literal instance)"
  (define r (last-result (run-file-string "ns t :no-prelude\n(the Int @[1 2])\n")))
  (check-true (prologos-error? r)
              "a pvec literal annotated at Int must be a type error"))

(test-case "route-soundness: heterogeneous values vs (Map Keyword Int) reject inline"
  ;; The original P1 soundness gap: the inline literal PASSED pre-fix.
  (define r (last-result
             (run-file-string
              "ns t :no-prelude\n(the (Map Keyword Int) {:a 2 :b \"x\"})\n")))
  (check-true (prologos-error? r)
              "a hetero-valued literal vs (Map Keyword Int) must be a type error"))

;; ========================================
;; 2. The def routes no longer PERSIST unsound types
;; ========================================

(test-case "route-soundness: def x := (the Int {:a 1}) rejects (no persistence)"
  (define results (run-file-string
                   "ns t :no-prelude\ndef x := (the Int {:a 1})\nx\n"))
  (check-true (prologos-error? (list-ref results (- (length results) 2)))
              "the def must reject")
  (check-true (prologos-error? (last-result results))
              "x must be unbound afterward (nothing persisted)"))

(test-case "route-soundness: match-body shape rejects (the QTT-backstop skip-hole)"
  ;; Pre-fix: contains-unsupported-qtt? skipped checkQ for match bodies, so
  ;; this shape DEFINED silently with the unsound type stored (probed).
  (define results
    (run-file-string
     "ns t :no-prelude\ndef y := (the Int (match true | true -> {:a 1} | false -> {:a 2}))\ny\n"))
  (check-true (prologos-error? (list-ref results (- (length results) 2)))
              "the match-body annotated def must reject")
  (check-true (prologos-error? (last-result results))
              "y must be unbound afterward"))

;; ========================================
;; 3. The app-rule instance (cons, no ann node) rejects
;; ========================================

(test-case "route-soundness: inline narrow head into wide-row list rejects"
  ;; The P2 cons case: pre-fix typed (List {:a Int :b Int}) with a narrow
  ;; head value — projection typechecked and runtime-missed. Needs prelude
  ;; (cons/List), so this one case runs Level-3 WITH prelude (single small
  ;; file — the 48s contention trap applies to many-command prelude files).
  ;; NOTE: the run-ns-ws-last (forked-network) fixture crashes on this shape
  ;; (net-cell-reset: unknown cell) when the re-routed imperative path
  ;; speculates — a fixture×speculation interaction, watch item, not chased
  ;; in F1b.2.
  (define results
    (run-file-string
     "ns test\ndef wa := '[{:a 1 :b 2} {:a 3 :b 4}]\n[cons {:a 9} wa]\n"))
  (check-true (prologos-error? (last-result results))
              "the unsound cons acceptance must reject"))

;; ========================================
;; 4. Sound forms still pass (the re-route is behavior-preserving)
;; ========================================

(test-case "route-soundness: sound scalar annotation still passes on-network"
  (define r (last-result (run-file-string "ns t :no-prelude\n(the Int 5)\n")))
  (check-true (string? r) "sound annotation on a typed term passes")
  (check-true (regexp-match? #rx"Int" r)))

(test-case "route-soundness: homogeneous map literal vs (Map Keyword Int) passes"
  ;; Re-routed to the imperative checker, whose per-entry arms accept.
  (define r (last-result
             (run-file-string
              "ns t :no-prelude\n(the (Map Keyword Int) {:a 2 :b 3})\n")))
  (check-true (string? r) "sound map annotation passes via the imperative route")
  (check-true (regexp-match? #rx"Map Keyword Int" r)))

(test-case "route-soundness: annotated def route unchanged (imperative already)"
  (define results (run-file-string
                   "ns t :no-prelude\ndef am : (Map Keyword Int) := {:a 1}\nam.a\n"))
  (check-true (string? (last-result results))
              "the F1a annotated-def flow is untouched")
  (check-true (regexp-match? #rx"Int" (last-result results))))

(test-case "route-soundness: record literals + projection unchanged"
  (define results (run-file-string
                   "ns t :no-prelude\ndef r := {:a 1 :b \"s\"}\nr.a\n"))
  (check-true (string? (last-result results)))
  (check-true (regexp-match? #rx"1 : Int" (last-result results))
              "the F1a goal flow is untouched"))

;; ========================================
;; 5. D23 groundwork: stored-type hygiene (deep scrub — the raw-meta leak)
;; ========================================

(test-case "stored-type scrub: open-row projection meta stores as HOLE, not raw meta"
  ;; PROBES §P7: pre-fix, `def x := [map-get m :c]` on an open row stored
  ;; `x : ?meta1610` verbatim — a dangling meta after per-command
  ;; reset-meta-store! (the B3 crash class). Post-F1b.2: deep scrub at the
  ;; store boundary → `x : _ defined.`; the escape-boundary ERROR posture is
  ;; F1b.6 (D23) — this pin is updated then.
  (define results
    (run-file-string
     (string-append
      "ns t :no-prelude\n"
      "def m := [map-assoc [map-assoc {} :a 1] :b \"s\"]\n"
      "def x := [map-get m :c]\n"
      "x\n")))
  (define def-line (list-ref results (- (length results) 2)))
  (check-true (string? def-line) "the def must succeed (interim posture)")
  (check-true (regexp-match? #rx"x : _ defined" def-line)
              "the stored type must be a hole, not a raw ?meta")
  (check-false (regexp-match? #rx"\\?meta" def-line)
               "no raw meta may appear in the stored-type display")
  (check-true (string? (last-result results))
              "the later reference must not crash (no dangling meta)"))

;; ========================================
;; 6. F1b.4-pre: the scan is UNIVERSAL (process-string contexts included)
;; ========================================

;; The F1b.4 mini-audit headline: the 5th refusal check was armed only in
;; process-file (init-attribute-map-cell! has one caller), so wrong-typed
;; sealed literals passed SILENTLY in process-string contexts — the
;; two-context soundness divergence (pipeline.md Two-Context Audit seam).
;; F1b.4-pre: infer-on-network/full returns the post-quiescence scan net +
;; attribute-cell id, and the check runs unconditionally in every context.

(define (run-string-ctx content)
  (parameterize ([current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-relation-store (make-relation-store)]
                 [current-defn-param-names (hasheq)]
                 [current-schema-registry (hasheq)]
                 [current-selection-registry (hasheq)])
    (install-module-loader!)
    (process-string content)))

(test-case "process-string context: WRONG-typed sealed literal is REJECTED (scan universal)"
  (define results
    (run-string-ctx
     (string-append
      "(ns t)\n"
      "(schema Person :name String :age Int)\n"
      "(the Person ($brace-params :name 42 :age \"x\"))\n")))
  (check-true (prologos-error? (last results))
              "wrong-typed seal must error in process-string too (was silently accepted pre-4-pre)"))

(test-case "process-string context: SOUND sealed literal still passes (re-route is behavior-preserving)"
  (define results
    (run-string-ctx
     (string-append
      "(ns t)\n"
      "(schema Person :name String :age Int)\n"
      "(the Person ($brace-params :name \"bob\" :age 4))\n")))
  (check-false (prologos-error? (last results))
               "sound seal must pass through the imperative re-route"))
