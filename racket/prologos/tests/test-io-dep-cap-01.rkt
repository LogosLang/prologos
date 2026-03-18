#lang racket/base

;;;
;;; test-io-dep-cap-01.rkt — Dependent Capabilities Unit Tests (IO-I)
;;;
;;; Tests for cap-entry struct, cap-set with applied entries,
;;; extract-capability-requirements for applied caps, and
;;; α/γ bridge with applied capabilities.
;;;
;;; Pattern: Shared fixture with process-string + prelude.
;;;

(require rackunit
         racket/list
         racket/set
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
         "../capability-inference.rkt"
         "../cap-type-bridge.rkt"
         "../type-lattice.rkt")

;; ========================================
;; Shared Fixture (prelude + capabilities loaded once)
;; ========================================

(define shared-preamble
  (string-append
   "(ns test-dep-cap)\n"
   "(capability FileCap (p : String))\n"
   "(subtype FileCap FsCap)"))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-capability-reg
                shared-subtype-reg)
  (parameterize ([current-prelude-env (hasheq)]
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
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-capability-registry)
            (current-subtype-registry))))

;; ========================================
;; Group 1: cap-entry struct basics
;; ========================================

(test-case "dep-cap/bare-cap-entry"
  ;; bare-cap creates a cap-entry with #f index
  (define e (bare-cap 'ReadCap))
  (check-true (cap-entry? e))
  (check-equal? (cap-entry-name e) 'ReadCap)
  (check-false (cap-entry-index-expr e)))

(test-case "dep-cap/applied-cap-entry"
  ;; cap-entry with index expression
  (define e (cap-entry 'FileCap (expr-string "/data")))
  (check-true (cap-entry? e))
  (check-equal? (cap-entry-name e) 'FileCap)
  (check-equal? (cap-entry-index-expr e) (expr-string "/data")))

(test-case "dep-cap/cap-entry-equality"
  ;; Structural equality: two identical applied caps are equal?
  (define a (cap-entry 'FileCap (expr-string "/data")))
  (define b (cap-entry 'FileCap (expr-string "/data")))
  (check-equal? a b)
  ;; Different index → not equal
  (define c (cap-entry 'FileCap (expr-string "/logs")))
  (check-not-equal? a c)
  ;; bare vs applied → not equal
  (define d (bare-cap 'FileCap))
  (check-not-equal? a d))

(test-case "dep-cap/cap-entry->string-bare"
  ;; Display: bare cap → symbol name
  (check-equal? (cap-entry->string (bare-cap 'ReadCap)) "ReadCap"))

(test-case "dep-cap/cap-entry->string-applied"
  ;; Display: applied cap → "(Name index)"
  (define e (cap-entry 'FileCap (expr-string "/data")))
  (define s (cap-entry->string e))
  (check-true (string-contains? s "FileCap"))
  (check-true (string-contains? s "/data")))

;; ========================================
;; Group 2: cap-set with cap-entry
;; ========================================

(test-case "dep-cap/cap-set-join-entries"
  ;; Join merges distinct entries (different index = different cap)
  (define a (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (define b (cap-set (set (cap-entry 'FileCap (expr-string "/logs")))))
  (define j (cap-set-join a b))
  (check-equal? (set-count (cap-set-members j)) 2))

(test-case "dep-cap/cap-set-join-dedup"
  ;; Join deduplicates identical entries (structural equality)
  (define a (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (define b (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (define j (cap-set-join a b))
  (check-equal? (set-count (cap-set-members j)) 1))

(test-case "dep-cap/cap-set-join-mixed"
  ;; Join mixes bare and applied caps
  (define a (cap-set (set (bare-cap 'ReadCap))))
  (define b (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (define j (cap-set-join a b))
  (check-equal? (set-count (cap-set-members j)) 2)
  (check-true (closure-has-cap-name? (cap-set-members j) 'ReadCap))
  (check-true (closure-has-cap-name? (cap-set-members j) 'FileCap)))

(test-case "dep-cap/cap-set-subsumes-exact-applied"
  ;; Exact applied cap subsumes itself
  (define avail (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (define req (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (check-true (cap-set-subsumes? avail req)))

(test-case "dep-cap/cap-set-not-subsumes-different-index"
  ;; Different index → does not subsume
  (define avail (cap-set (set (cap-entry 'FileCap (expr-string "/data")))))
  (define req (cap-set (set (cap-entry 'FileCap (expr-string "/logs")))))
  (check-false (cap-set-subsumes? avail req)))

(test-case "dep-cap/cap-set-names-helper"
  ;; cap-set-names extracts just the symbol names
  (define cs (cap-set (set (bare-cap 'ReadCap)
                           (cap-entry 'FileCap (expr-string "/data")))))
  (define names (cap-set-names cs))
  (check-true (set-member? names 'ReadCap))
  (check-true (set-member? names 'FileCap))
  (check-equal? (set-count names) 2))

;; ========================================
;; Group 3: cap-entry-covers? subsumption
;; ========================================

(test-case "dep-cap/covers-bare-exact"
  ;; Bare cap covers same bare cap
  (check-true (cap-entry-covers? (bare-cap 'ReadCap) (bare-cap 'ReadCap))))

(test-case "dep-cap/covers-applied-exact"
  ;; Applied cap covers same applied cap
  (check-true (cap-entry-covers?
               (cap-entry 'FileCap (expr-string "/data"))
               (cap-entry 'FileCap (expr-string "/data")))))

(test-case "dep-cap/covers-subtype-bare"
  ;; FsCap covers ReadCap (ReadCap <: FsCap)
  (parameterize ([current-subtype-registry shared-subtype-reg])
    (check-true (cap-entry-covers? (bare-cap 'FsCap) (bare-cap 'ReadCap)))))

(test-case "dep-cap/not-covers-different-index"
  ;; Different index → does not cover
  (check-false (cap-entry-covers?
                (cap-entry 'FileCap (expr-string "/data"))
                (cap-entry 'FileCap (expr-string "/logs")))))

(test-case "dep-cap/not-covers-different-name"
  ;; Different names, no subtype relationship → does not cover
  (parameterize ([current-subtype-registry shared-subtype-reg])
    (check-false (cap-entry-covers? (bare-cap 'ReadCap) (bare-cap 'HttpCap)))))

;; ========================================
;; Group 4: extract-capability-requirements for applied caps
;; ========================================

(test-case "dep-cap/extract-bare-fvar"
  ;; Bare cap in Pi → bare cap-entry
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-fvar 'ReadCap)
                 (expr-Pi 'mw (expr-fvar 'Nat)
                   (expr-fvar 'Nat))))
    (define caps (extract-capability-requirements ty))
    (check-equal? (set-count caps) 1)
    (check-true (set-member? caps (bare-cap 'ReadCap)))))

(test-case "dep-cap/extract-applied-cap"
  ;; Applied cap in Pi → cap-entry with index
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
                 (expr-Pi 'mw (expr-fvar 'Nat)
                   (expr-fvar 'Nat))))
    (define caps (extract-capability-requirements ty))
    (check-equal? (set-count caps) 1)
    (check-true (set-member? caps (cap-entry 'FileCap (expr-string "/data"))))))

(test-case "dep-cap/extract-mixed-bare-and-applied"
  ;; Pi with both bare and applied caps
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-fvar 'ReadCap)
                 (expr-Pi 'm0 (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
                   (expr-Pi 'mw (expr-fvar 'Nat)
                     (expr-fvar 'Nat)))))
    (define caps (extract-capability-requirements ty))
    (check-equal? (set-count caps) 2)
    (check-true (set-member? caps (bare-cap 'ReadCap)))
    (check-true (set-member? caps (cap-entry 'FileCap (expr-string "/data"))))))

(test-case "dep-cap/extract-non-capability-app-ignored"
  ;; Applied non-capability (e.g., List Nat) is not extracted
  (parameterize ([current-capability-registry shared-capability-reg])
    (define ty (expr-Pi 'm0 (expr-app (expr-fvar 'List) (expr-fvar 'Nat))
                 (expr-fvar 'Nat)))
    (define caps (extract-capability-requirements ty))
    (check-true (set-empty? caps))))

;; ========================================
;; Group 5: α/γ bridge for applied caps
;; ========================================

(test-case "dep-cap/alpha-applied-cap"
  ;; type-to-cap-set on (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result
      (type-to-cap-set (expr-app (expr-fvar 'FileCap) (expr-string "/data"))))
    (check-equal? (set-count (cap-set-members result)) 1)
    (check-true (set-member? (cap-set-members result)
                             (cap-entry 'FileCap (expr-string "/data"))))))

(test-case "dep-cap/alpha-pi-applied-domain"
  ;; type-to-cap-set on (Pi :0 (FileCap "/data") Nat) → {FileCap "/data"}
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result
      (type-to-cap-set
       (expr-Pi 'm0 (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
         (expr-fvar 'Nat))))
    (check-equal? (set-count (cap-set-members result)) 1)
    (check-true (set-member? (cap-set-members result)
                             (cap-entry 'FileCap (expr-string "/data"))))))

(test-case "dep-cap/alpha-non-capability-app"
  ;; type-to-cap-set on (expr-app (expr-fvar 'List) (expr-fvar 'Nat)) → empty
  (parameterize ([current-capability-registry shared-capability-reg])
    (define result
      (type-to-cap-set (expr-app (expr-fvar 'List) (expr-fvar 'Nat))))
    (check-true (set-empty? (cap-set-members result)))))

(test-case "dep-cap/gamma-applied-cap"
  ;; cap-set-to-type on {FileCap "/data"} → (expr-app (expr-fvar 'FileCap) "/data")
  (define result
    (cap-set-to-type (cap-set (set (cap-entry 'FileCap (expr-string "/data"))))))
  (check-true (expr-app? result))
  (check-true (expr-fvar? (expr-app-func result)))
  (check-equal? (expr-fvar-name (expr-app-func result)) 'FileCap)
  (check-equal? (expr-app-arg result) (expr-string "/data")))

(test-case "dep-cap/gamma-mixed-bare-applied"
  ;; cap-set-to-type on {ReadCap, FileCap "/data"} → union
  (define result
    (cap-set-to-type (cap-set (set (bare-cap 'ReadCap)
                                   (cap-entry 'FileCap (expr-string "/data"))))))
  (check-true (expr-union? result)))

(test-case "dep-cap/alpha-gamma-roundtrip-applied"
  ;; Applied cap survives α then γ roundtrip
  (parameterize ([current-capability-registry shared-capability-reg])
    (define t (expr-app (expr-fvar 'FileCap) (expr-string "/data")))
    (define alpha-t (type-to-cap-set t))
    (define gamma-alpha-t (cap-set-to-type alpha-t))
    (define alpha-gamma-alpha-t (type-to-cap-set gamma-alpha-t))
    (check-equal? (cap-set-members alpha-t) (cap-set-members alpha-gamma-alpha-t))))

;; ========================================
;; Group 6: Cross-domain bridge overdeclared with applied caps
;; ========================================

(test-case "dep-cap/bridge-overdeclared-applied"
  ;; f declares both ReadCap and FileCap "/data", only calls g which needs ReadCap.
  ;; FileCap "/data" should be overdeclared.
  (parameterize ([current-capability-registry shared-capability-reg]
                 [current-subtype-registry shared-subtype-reg])
    (define f-type
      (expr-Pi 'm0 (expr-fvar 'ReadCap)
        (expr-Pi 'm0 (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
          (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat)))))
    (define g-type
      (expr-Pi 'm0 (expr-fvar 'ReadCap)
        (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Nat))))
    (define g-body (expr-lam 'mw (expr-fvar 'Nat) (expr-bvar 0)))
    (define f-body
      (expr-lam 'm0 (expr-fvar 'ReadCap)
        (expr-lam 'm0 (expr-app (expr-fvar 'FileCap) (expr-string "/data"))
          (expr-lam 'mw (expr-fvar 'Nat)
            (expr-app (expr-fvar 'g-dep) (expr-bvar 0))))))
    (define env
      (hasheq 'f-dep (cons f-type f-body)
              'g-dep (cons g-type g-body)))
    (define bridge-result (build-cross-domain-network env))
    (define overdeclared (cap-audit-overdeclared bridge-result 'f-dep))
    ;; FileCap "/data" should be overdeclared
    (check-true (closure-has-cap-name? overdeclared 'FileCap)
                "FileCap should be overdeclared")))
