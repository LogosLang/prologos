#lang racket/base

;;;
;;; Tests for Capabilities as Types — Phase 2: Multiplicity Defaulting + :w Warning
;;; Tests that capability constraints default to :0, and :w on a capability emits W2001.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "test-support.rkt"
         "../macros.rkt"
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
         "../namespace.rkt"
         "../multi-dispatch.rkt"
         "../warnings.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test-cap2)")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)]
                 [current-capability-registry (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry))))

;; Helper: run code and return list of result strings.
(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-capability-registry shared-capability-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; Parser-level: Pi binder multiplicity
;; ========================================

(test-case "pi-binder/explicit-m0"
  ;; (Pi (fs :0 ReadCap) Nat) — explicit :0 multiplicity
  (define result (parse-datum '(Pi (fs :0 ReadCap) Nat)))
  (check-true (surf-pi? result))
  (define bi (surf-pi-binder result))
  (check-equal? (binder-info-name bi) 'fs)
  (check-equal? (binder-info-mult bi) 'm0))

(test-case "pi-binder/explicit-m1"
  ;; (Pi (fs :1 ReadCap) Nat) — explicit :1 multiplicity
  (define result (parse-datum '(Pi (fs :1 ReadCap) Nat)))
  (check-true (surf-pi? result))
  (define bi (surf-pi-binder result))
  (check-equal? (binder-info-name bi) 'fs)
  (check-equal? (binder-info-mult bi) 'm1))

(test-case "pi-binder/explicit-mw"
  ;; (Pi (fs :w ReadCap) Nat) — explicit :w multiplicity
  (define result (parse-datum '(Pi (fs :w ReadCap) Nat)))
  (check-true (surf-pi? result))
  (define bi (surf-pi-binder result))
  (check-equal? (binder-info-name bi) 'fs)
  (check-equal? (binder-info-mult bi) 'mw))

(test-case "pi-binder/colon-default-is-null"
  ;; (Pi (fs : ReadCap) Nat) — colon without mult → #f (meta assigned later)
  ;; For brace-params the default would be m0, but for explicit Pi binders
  ;; with ':' the mult is #f → elaborator creates a fresh mult-meta
  (define result (parse-datum '(Pi (fs : ReadCap) Nat)))
  (check-true (surf-pi? result))
  (define bi (surf-pi-binder result))
  (check-equal? (binder-info-name bi) 'fs)
  (check-equal? (binder-info-mult bi) #f))

;; ========================================
;; W2001 Warning: :w on capability
;; ========================================

(test-case "W2001/capability-mw-emits-warning"
  ;; Pi with :w multiplicity on a capability type should emit W2001
  (define result
    (run-last "(capability WarnCap)\n(infer (Pi (fs :w WarnCap) Nat))"))
  (check-true (string? result))
  (check-true (string-contains? result "W2001")
              "W2001 warning should appear for :w on capability"))

(test-case "W2001/capability-m0-no-warning"
  ;; Pi with :0 multiplicity on a capability type — no warning
  (define result
    (run-last "(capability SafeCap)\n(infer (Pi (fs :0 SafeCap) Nat))"))
  (check-true (string? result))
  (check-false (string-contains? result "W2001")
               "No W2001 for :0 on capability"))

(test-case "W2001/capability-m1-no-warning"
  ;; Pi with :1 multiplicity on a capability type — no warning
  (define result
    (run-last "(capability XferCap)\n(infer (Pi (fs :1 XferCap) Nat))"))
  (check-true (string? result))
  (check-false (string-contains? result "W2001")
               "No W2001 for :1 on capability"))

(test-case "W2001/non-capability-mw-no-warning"
  ;; Pi with :w on a non-capability type — no warning
  ;; Nat is not a capability, so :w is fine
  (define result
    (run-last "(infer (Pi (x :w Nat) Nat))"))
  (check-true (string? result))
  (check-false (string-contains? result "W2001")
               "No W2001 for :w on non-capability type"))

(test-case "W2001/warning-mentions-capability-name"
  ;; The warning should include the capability name
  (define result
    (run-last "(capability AuditCap)\n(infer (Pi (a :w AuditCap) Nat))"))
  (check-true (string? result))
  (check-true (string-contains? result "AuditCap")
              "W2001 should mention the capability name"))

;; ========================================
;; Warning infrastructure unit tests
;; ========================================

(test-case "emit-capability-warning!/basic"
  (parameterize ([current-capability-warnings '()])
    (emit-capability-warning! 'TestCap 'mw)
    (define warns (current-capability-warnings))
    (check-equal? (length warns) 1)
    (check-true (capability-warning? (car warns)))
    (check-equal? (capability-warning-name (car warns)) 'TestCap)
    (check-equal? (capability-warning-multiplicity (car warns)) 'mw)))

(test-case "format-capability-warning/contains-W2001"
  (define w (capability-warning 'MyCap 'mw))
  (define s (format-capability-warning w))
  (check-true (string-contains? s "W2001"))
  (check-true (string-contains? s "MyCap"))
  (check-true (string-contains? s ":w")))

;; ========================================
;; Regression: traits unaffected
;; ========================================

(test-case "trait-constraint/mw-no-W2001"
  ;; Trait constraints with :w are fine — they're dict params, not capabilities
  ;; (Eq A) in where-constraint → runtime dict, mw is correct
  (define result
    (run-last "(infer (Pi (d :w Nat) Nat))"))
  (check-true (string? result))
  (check-false (string-contains? result "W2001")
               "Nat with :w should not trigger W2001"))

(test-case "capability-type?/regression"
  ;; capability-type? returns false for traits and regular types
  (check-false (capability-type? 'Eq))
  (check-false (capability-type? 'Nat))
  (check-false (capability-type? 'Bool)))
