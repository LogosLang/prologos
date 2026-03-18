#lang racket/base

;;;
;;; Shared test support: pre-loaded prelude for fast test execution.
;;;
;;; Instead of each test case reloading ~84 prelude modules from .prologos
;;; source (~3s per call), this module loads the prelude ONCE at require
;;; time and exports cached registries. Test cases reuse the module cache
;;; while maintaining full isolation via fresh global-env/ns-context/meta-store.
;;;
;;; Usage in test files:
;;;   (require "test-support.rkt")
;;;   ;; Then use run-ns-last, run-ns-all, or the prelude-* values directly.
;;;

(require racket/list
         racket/path
         racket/port
         racket/string
         rackunit
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
         "../namespace.rkt")

(provide ;; Pre-loaded prelude registries
         prelude-module-registry
         prelude-trait-registry
         prelude-impl-registry
         prelude-param-impl-registry
         prelude-preparse-registry
         prelude-capability-registry
         prelude-lib-dir
         ;; Convenience helpers
         run-ns-last
         run-ns-all
         ;; WS-mode helpers (primary design target)
         run-ns-ws-last
         run-ns-ws-all
         ;; GDE-4: Structured error testing helpers
         check-error-has-provenance
         check-error-diagnosis-count
         extract-provenance-json
         run-simple-capture-stderr
         ;; Rich failure diagnostics: custom check with provenance
         check-prologos
         error-provenance-summary)

;; ========================================
;; Compute lib-dir from this file's location
;; ========================================
(define here (path->string (path-only (syntax-source #'here))))
(define prelude-lib-dir (simplify-path (build-path here ".." "lib")))

;; ========================================
;; Load prelude once and capture registries
;; ========================================
;; This runs at module load time (once per test subprocess).
;; Captures the module registry (parsed/elaborated module ASTs),
;; trait/impl registries, and preparse registry.

(define-values (prelude-module-registry
                prelude-trait-registry
                prelude-impl-registry
                prelude-param-impl-registry
                prelude-preparse-registry
                prelude-capability-registry)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]  ;; Track 6 Phase 7d
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 [current-cross-module-deps '()]  ;; Track 5 Phase 4
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-capability-registry (current-capability-registry)]
                 ;; Track 6 Phase 7a: network isolation (fresh network per call)
                 [current-prop-net-box              #f]
                 [current-prelude-env-prop-net-box   #f]
                 [current-ns-prop-net-box           #f]
                 [current-definition-cell-ids       (hasheq)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 [current-defn-param-names-cell-id  #f])
    (install-module-loader!)
    (process-string "(ns prelude-cache)\n")
    (values (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry)
            (current-capability-registry))))

;; ========================================
;; Fast test helpers using cached prelude
;; ========================================

;; Process a string in a fresh namespace using cached prelude modules.
;; Returns the LAST result (like the common run-ns-last pattern).
;; Each call gets a fresh global-env, ns-context, and meta-store for isolation.
(define (run-ns-last s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]  ;; Track 6 Phase 7d
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 [current-cross-module-deps '()]  ;; Track 5 Phase 4
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 6 Phase 7a: network isolation
                 [current-prop-net-box              #f]
                 [current-prelude-env-prop-net-box   #f]
                 [current-ns-prop-net-box           #f]
                 [current-definition-cell-ids       (hasheq)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 [current-defn-param-names-cell-id  #f])
    (install-module-loader!)
    (last (process-string s))))

;; Process a string and return ALL results (list).
(define (run-ns-all s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]  ;; Track 6 Phase 7d
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 [current-cross-module-deps '()]  ;; Track 5 Phase 4
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 6 Phase 7a: network isolation
                 [current-prop-net-box              #f]
                 [current-prelude-env-prop-net-box   #f]
                 [current-ns-prop-net-box           #f]
                 [current-definition-cell-ids       (hasheq)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 [current-defn-param-names-cell-id  #f])
    (install-module-loader!)
    (process-string s)))

;; ========================================
;; WS-mode helpers (primary design target)
;; ========================================
;; Like run-ns-last/run-ns-all but using the WS reader (indentation-sensitive).
;; This is the path that .prologos files use.

(define (run-ns-ws-last s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]  ;; Track 6 Phase 7d
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 [current-cross-module-deps '()]  ;; Track 5 Phase 4
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 6 Phase 7a: network isolation
                 [current-prop-net-box              #f]
                 [current-prelude-env-prop-net-box   #f]
                 [current-ns-prop-net-box           #f]
                 [current-definition-cell-ids       (hasheq)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 [current-defn-param-names-cell-id  #f])
    (install-module-loader!)
    (last (process-string-ws s))))

(define (run-ns-ws-all s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]  ;; Track 6 Phase 7d
                 [current-definition-cells-content (hasheq)]  ;; Phase 3a
                 [current-definition-dependencies (hasheq)]  ;; Phase 3b
                 [current-cross-module-deps '()]  ;; Track 5 Phase 4
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 ;; Track 6 Phase 7a: network isolation
                 [current-prop-net-box              #f]
                 [current-prelude-env-prop-net-box   #f]
                 [current-ns-prop-net-box           #f]
                 [current-definition-cell-ids       (hasheq)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 [current-defn-param-names-cell-id  #f])
    (install-module-loader!)
    (process-string-ws s)))

;; ========================================
;; GDE-4: Structured error testing helpers
;; ========================================

;; Run without prelude, capture stderr. Returns (cons results stderr-string).
(define (run-simple-capture-stderr s)
  (define stderr-out (open-output-string))
  (define results
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]  ;; Track 6 Phase 7d
                   [current-definition-cells-content (hasheq)]  ;; Phase 3a
                   [current-definition-dependencies (hasheq)]  ;; Phase 3b
                   [current-cross-module-deps '()]  ;; Track 5 Phase 4
                   [current-error-port stderr-out]
                   ;; Track 6 Phase 7a: network isolation
                   [current-prop-net-box              #f]
                   [current-prelude-env-prop-net-box   #f]
                   [current-ns-prop-net-box           #f]
                   [current-definition-cell-ids       (hasheq)]
                   [current-module-registry-cell-id   #f]
                   [current-ns-context-cell-id        #f]
                   [current-defn-param-names-cell-id  #f])
      (process-string s)))
  (cons results (get-output-string stderr-out)))

;; Assert that an error has a non-empty provenance field.
;; Works for type-mismatch-error (provenance field) and union-exhaustion-error (derivation-chain).
;; Returns #t if provenance is non-empty, #f otherwise.
(define (check-error-has-provenance err)
  (cond
    [(type-mismatch-error? err)
     (define prov (type-mismatch-error-provenance err))
     (and (list? prov) (pair? prov))]
    [(union-exhaustion-error? err)
     (define chain (union-exhaustion-error-derivation-chain err))
     (and (list? chain) (ormap pair? chain))]
    [else #f]))

;; Count the number of diagnosis entries in an error's provenance.
;; Diagnosis lines start with "[diagnosis]".
(define (check-error-diagnosis-count err)
  (define provenance
    (cond
      [(type-mismatch-error? err) (type-mismatch-error-provenance err)]
      [(union-exhaustion-error? err)
       (apply append (union-exhaustion-error-derivation-chain err))]
      [else '()]))
  (length (filter (lambda (s) (and (string? s) (string-prefix? s "[diagnosis]")))
                  provenance)))

;; Extract PROVENANCE-STATS JSON from stderr string.
;; Returns a hash of key→value (string keys, number values) or #f if not found.
;; When multiple PROVENANCE-STATS lines exist (one per command), returns the LAST one.
(define (extract-provenance-json stderr)
  ;; Find all PROVENANCE-STATS lines and use the last one
  (define all-matches
    (regexp-match* #rx"PROVENANCE-STATS:\\{([^}]+)\\}" stderr #:match-select cadr))
  (cond
    [(null? all-matches) #f]
    [else
     (define json-body (last all-matches))
     ;; Extract "key":number pairs
     (define pair-matches
       (regexp-match* #rx"\"([^\"]+)\":([0-9]+)" json-body #:match-select cdr))
     (for/hash ([pair (in-list pair-matches)])
       (values (car pair) (string->number (cadr pair))))]))

;; ========================================
;; Rich failure diagnostics: custom check
;; ========================================

;; Summarize provenance information from a prologos-error.
;; Returns a human-readable string with derivation chain details.
(define (error-provenance-summary err)
  (cond
    [(type-mismatch-error? err)
     (define prov (type-mismatch-error-provenance err))
     (if (and (list? prov) (pair? prov))
         (string-join prov "\n")
         "(no provenance)")]
    [(union-exhaustion-error? err)
     (define chain (union-exhaustion-error-derivation-chain err))
     (if (and (list? chain) (ormap pair? chain))
         (string-join
          (for/list ([branch-chain (in-list chain)]
                     [i (in-naturals 1)])
            (if (pair? branch-chain)
                (format "branch ~a:\n  ~a" i (string-join branch-chain "\n  "))
                (format "branch ~a: (no chain)" i)))
          "\n")
         "(no derivation chain)")]
    [else "(no provenance for this error type)"]))

;; Custom check: drop-in replacement for check-equal? that enriches
;; failure output with formatted prologos errors and provenance chains.
;;
;; When actual is a prologos-error and expected is a string (common pattern),
;; the failure message shows the formatted error with "because:" chains
;; instead of just the opaque struct representation.
;;
;; Usage: (check-prologos (run-last "(def x : Nat 0N)") "x : Nat defined.")
(define-check (check-prologos actual expected)
  (unless (equal? actual expected)
    (with-check-info*
      (append
        (list (make-check-info 'expected expected)
              (make-check-info 'actual actual))
        (if (prologos-error? actual)
            (list (make-check-info 'formatted-error (format-error actual))
                  (make-check-info 'provenance (error-provenance-summary actual)))
            '())
        (if (prologos-error? expected)
            (list (make-check-info 'expected-formatted (format-error expected)))
            '()))
      (lambda () (fail-check "prologos result mismatch")))))
