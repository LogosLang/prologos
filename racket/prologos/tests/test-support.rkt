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
         run-ns-all)

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
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-capability-registry (current-capability-registry)])
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
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (last (process-string s))))

;; Process a string and return ALL results (list).
(define (run-ns-all s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string s)))
