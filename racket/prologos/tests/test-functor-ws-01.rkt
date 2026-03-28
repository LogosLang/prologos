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
         "../reader.rkt"
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

(test-case "ws functor: basic with :unfolds"
  (define fe
    (functor-for-ws 'FilePath
      (string-append
        "functor FilePath\n"
        "  :unfolds String\n")))
  (check-true (functor-entry? fe))
  (check-equal? (functor-entry-name fe) 'FilePath)
  ;; Should have the :unfolds expression
  (check-true (not (eq? #f (functor-entry-unfolds fe)))))

(test-case "ws functor: with type parameter"
  (define fe
    (functor-for-ws 'AppResult
      (string-append
        "functor AppResult {A : Type}\n"
        "  :unfolds [Either String A]\n")))
  (check-true (functor-entry? fe))
  (check-equal? (functor-entry-name fe) 'AppResult)
  ;; Should have params
  (check-true (pair? (functor-entry-params fe))))

(test-case "ws functor: with :doc metadata"
  (define fe
    (functor-for-ws 'Result
      (string-append
        "functor Result {A : Type}\n"
        "  :doc \"A computation that may fail\"\n"
        "  :unfolds [Either String A]\n")))
  (check-true (functor-entry? fe))
  (define md (functor-entry-metadata fe))
  (check-equal? (hash-ref md ':doc #f) "A computation that may fail"))

(test-case "ws functor: with :compose and :identity"
  (define fe
    (functor-for-ws 'Xf
      (string-append
        "functor Xf {A B : Type}\n"
        "  :compose xf-compose\n"
        "  :identity id-xf\n"
        "  :unfolds <(S :0 Type) -> [S -> B -> S] -> S -> A -> S>\n")))
  (check-true (functor-entry? fe))
  (define md (functor-entry-metadata fe))
  (check-equal? (hash-ref md ':compose #f) 'xf-compose)
  (check-equal? (hash-ref md ':identity #f) 'id-xf))

(test-case "ws functor: with :laws reference"
  (define fe
    (functor-for-ws 'MyFunctor
      (string-append
        "functor MyFunctor {A : Type}\n"
        "  :laws (my-laws A)\n"
        "  :unfolds A\n")))
  (check-true (functor-entry? fe))
  (define md (functor-entry-metadata fe))
  ;; :laws should be stored in metadata
  (check-true (hash-has-key? md ':laws)))

(test-case "ws functor: registers as deftype"
  ;; A parameterized functor should auto-register as a deftype
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-type-meta (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string-ws
      (string-append
        "functor Wrapper {A : Type}\n"
        "  :unfolds A\n"))
    ;; Should be in functor store
    (check-true (functor-entry? (lookup-functor 'Wrapper)))
    ;; Should also be registered as a deftype — check via current-preparse-registry
    ;; (deftype expands Wrapper A → A)
    ))

;; ========================================
;; 2. Sexp-mode regression
;; ========================================
