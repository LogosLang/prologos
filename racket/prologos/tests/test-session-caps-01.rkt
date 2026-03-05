#lang racket/base

;;;
;;; Tests for session type + capability integration (Phase S5a)
;;; Validates that defproc/proc headers parse and elaborate capability binders,
;;; and that capabilities enter the typing context for type-proc.
;;;

(require rackunit
         racket/list
         racket/string
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../macros.rkt"
         "../warnings.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Minimal run: no prelude, fresh state per call.
;; Matches the pattern from test-session-elaborate-01.rkt.
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-capability-registry (hasheq)]
                 [current-capability-warnings '()]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string s))
    (if (and (list? results) (not (null? results)))
        (last results)
        results)))

;; Run with capability declarations pre-loaded, preserving state.
(define (run-with-caps s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-capability-registry (hasheq)]
                 [current-capability-warnings '()]
                 [current-mult-meta-store (make-hasheq)])
    (define results (process-string
                     (string-append
                      "(capability NetCap)\n"
                      "(capability FsCap)\n"
                      "(capability DbCap)\n"
                      s)))
    (if (and (list? results) (not (null? results)))
        (last results)
        results)))

;; Run and return all results (for multi-command strings)
(define (run-all-with-caps s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-capability-registry (hasheq)]
                 [current-capability-warnings '()]
                 [current-mult-meta-store (make-hasheq)])
    (process-string
     (string-append
      "(capability NetCap)\n"
      "(capability FsCap)\n"
      "(capability DbCap)\n"
      s))))

;; ========================================
;; Parsing: defproc with capability binders
;; ========================================

(test-case "parse: defproc with session type and single cap binder"
  (define result (parse-datum '(defproc handler : Greeting ($brace-params net :0 NetCap) (proc-stop))))
  (check-true (surf-defproc? result))
  (check-equal? (surf-defproc-name result) 'handler)
  ;; Session type should be parsed
  (check-true (not (eq? #f (surf-defproc-session-type result))))
  ;; Caps should be a non-empty list of binder-info
  (define caps (surf-defproc-caps result))
  (check-true (pair? caps))
  (check-equal? (length caps) 1)
  (check-equal? (binder-info-name (car caps)) 'net)
  (check-equal? (binder-info-mult (car caps)) 'm0))

(test-case "parse: defproc with caps but no session type"
  (define result (parse-datum '(defproc handler ($brace-params fs :0 FsCap) (proc-stop))))
  (check-true (surf-defproc? result))
  ;; No session type
  (check-equal? (surf-defproc-session-type result) #f)
  ;; But has caps
  (check-true (pair? (surf-defproc-caps result)))
  (check-equal? (binder-info-name (car (surf-defproc-caps result))) 'fs))

(test-case "parse: defproc without caps has empty caps list"
  (define result (parse-datum '(defproc handler : Greeting (proc-stop))))
  (check-true (surf-defproc? result))
  (check-equal? (surf-defproc-caps result) '()))

(test-case "parse: proc with session type and cap binder"
  (define result (parse-datum '(proc : Greeting ($brace-params net :0 NetCap) (proc-stop))))
  (check-true (surf-proc? result))
  (define caps (surf-proc-caps result))
  (check-true (pair? caps))
  (check-equal? (binder-info-name (car caps)) 'net))

(test-case "parse: proc with caps only (no session type)"
  (define result (parse-datum '(proc ($brace-params fs :0 FsCap) (proc-stop))))
  (check-true (surf-proc? result))
  (check-equal? (surf-proc-session-type result) #f)
  (check-true (pair? (surf-proc-caps result))))

(test-case "parse: proc without caps has empty caps list"
  (define result (parse-datum '(proc : Greeting (proc-stop))))
  (check-true (surf-proc? result))
  (check-equal? (surf-proc-caps result) '()))

;; ========================================
;; E2E: defproc with caps through full pipeline
;; ========================================

(test-case "e2e: defproc with cap + session type type-checks"
  ;; sexp mode: (proc-send self "hello" (proc-stop))
  (define result
    (run-with-caps
     "(session Greeting (Send String End))\n(defproc handler : Greeting ($brace-params net :0 NetCap) (proc-send self \"hello\" (proc-stop)))"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

(test-case "e2e: defproc with cap but no session type registers"
  (define result
    (run-with-caps
     "(defproc handler ($brace-params fs :0 FsCap) (proc-stop))"))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

(test-case "e2e: defproc without cap still type-checks"
  (define result
    (run "(session Greeting (Send String End))\n(defproc handler : Greeting (proc-send self \"hello\" (proc-stop)))"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

(test-case "e2e: defproc with wrong process body fails"
  ;; recv against Send session should fail
  (define result
    (run "(session Greeting (Send String End))\n(defproc handler : Greeting (proc-recv self x (proc-stop)))"))
  (check-true (prologos-error? result)))

(test-case "e2e: anonymous proc with cap and session type type-checks"
  (define result
    (run-with-caps
     "(session Greeting (Send String End))\n(proc : Greeting ($brace-params net :0 NetCap) (proc-send self \"hello\" (proc-stop)))"))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked")))

(test-case "e2e: multiple commands with session + cap + defproc"
  (define results
    (run-all-with-caps
     "(session Greeting (Send String End))\n(defproc handler : Greeting ($brace-params net :0 NetCap) (proc-send self \"hello\" (proc-stop)))"))
  (check-true (list? results))
  ;; Should have: 3 cap defs + 1 session + 1 defproc = 5 results
  (check-equal? (length results) 5)
  ;; Last result is the defproc type-check
  (check-true (string-contains? (last results) "type-checked")))
