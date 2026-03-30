#lang racket/base

;;;
;;; Tests for functor keyword:
;;;   - WS-mode integration (reader -> preparse -> process-functor)
;;;   - Standard library type-functors.prologos
;;;   - Sexp-mode regression
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         "../macros.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../parse-reader.rkt"
         "../source-location.rkt"
         "../namespace.rkt"
         "test-support.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Process WS-mode string through the full pipeline
(define (process-string-ws s)
  (define port (open-input-string s))
  (port-count-lines! port)
  (define raw-stxs (prologos-read-syntax-all "<ws-test>" port))
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; Process WS-mode and return functor from store
(define (functor-for-ws name s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string-ws s)
    (lookup-functor name)))

;; ========================================
;; 1. WS-mode functor declarations
;; ========================================


(test-case "sexp functor: basic with metadata"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string
      "(functor FilePath :unfolds String ($brace-params :doc \"A file path\"))")
    (define fe (lookup-functor 'FilePath))
    (check-true (functor-entry? fe))
    (check-equal? (functor-entry-name fe) 'FilePath)
    (check-equal? (hash-ref (functor-entry-metadata fe) ':doc #f) "A file path")))

(test-case "sexp functor: parameterized registers as deftype"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string
      "(functor MyResult ($brace-params A : (Type 0)) :unfolds (Either String A))")
    (define fe (lookup-functor 'MyResult))
    (check-true (functor-entry? fe))
    (check-equal? (functor-entry-name fe) 'MyResult)))

;; ========================================
;; 3. Standard library: type-functors.prologos
;; ========================================

(test-case "type-functors: file parses and registers functors"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "collection-traits.prologos")))
    (process-file file-path)
    ;; Both functors should be registered
    (check-true (functor-entry? (lookup-functor 'Xf)))
    (check-true (functor-entry? (lookup-functor 'AppResult)))))

(test-case "type-functors: Xf has correct params and unfolds"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "collection-traits.prologos")))
    (process-file file-path)
    (define fe (lookup-functor 'Xf))
    (check-true (functor-entry? fe))
    ;; Should have 2 params (A and B)
    (check-equal? (length (functor-entry-params fe)) 2)
    ;; Should have :unfolds
    (check-true (not (eq? #f (functor-entry-unfolds fe))))))

(test-case "type-functors: AppResult has :doc metadata"
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (define here (path->string (path-only (syntax-source #'here))))
    (define file-path (simplify-path (build-path here ".." "lib" "prologos" "core" "collection-traits.prologos")))
    (process-file file-path)
    (define fe (lookup-functor 'AppResult))
    (check-true (functor-entry? fe))
    (define md (functor-entry-metadata fe))
    (check-equal? (hash-ref md ':doc #f)
                  "A computation that may fail with a string error")))
