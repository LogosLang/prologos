#lang racket/base

;;;
;;; Tests for boundary operations (Phase S5b)
;;; Validates parsing, elaboration, propagator compilation, and type-checking
;;; of proc-open, proc-connect, and proc-listen.
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
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../macros.rkt"
         "../warnings.rkt"
         "../pretty-print.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Minimal run: no prelude, fresh state per call.
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-capability-registry (hasheq)]
                 [current-capability-warnings '()]
                 )
    (define results (process-string s))
    (if (and (list? results) (not (null? results)))
        (last results)
        results)))

;; Run with capability declarations pre-loaded
(define (run-with-caps s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 [current-capability-registry (hasheq)]
                 [current-capability-warnings '()]
                 )
    (define results (process-string
                     (string-append
                      "(capability NetCap)\n"
                      "(capability FsCap)\n"
                      s)))
    (if (and (list? results) (not (null? results)))
        (last results)
        results)))

;; Parse a top-level defproc form containing a boundary op in its body,
;; then extract the process body for inspection.
(define (parse-defproc-body datum-form)
  (define result (parse-datum datum-form))
  (and (surf-defproc? result)
       (surf-defproc-body result)))

;; ========================================
;; Parsing: boundary operations (via defproc body)
;; ========================================

(test-case "parse: proc-open with path, session type, cap, and continuation"
  (define body (parse-defproc-body '(defproc reader (proc-open "/data" : DataSession FsCap (proc-stop)))))
  (check-true (surf-proc-open? body))
  (check-equal? (surf-proc-open-cap body) 'FsCap)
  (check-true (surf-proc-stop? (surf-proc-open-cont body))))

(test-case "parse: proc-connect with addr and session type"
  (define body (parse-defproc-body '(defproc connector (proc-connect "localhost:8080" : HttpSession NetCap (proc-stop)))))
  (check-true (surf-proc-connect? body))
  (check-equal? (surf-proc-connect-cap body) 'NetCap)
  (check-true (surf-proc-stop? (surf-proc-connect-cont body))))

(test-case "parse: proc-listen with port and session type"
  (define body (parse-defproc-body '(defproc server (proc-listen 8080 : ServerSession NetCap (proc-stop)))))
  (check-true (surf-proc-listen? body))
  (check-equal? (surf-proc-listen-cap body) 'NetCap)
  (check-true (surf-proc-stop? (surf-proc-listen-cont body))))

(test-case "parse: proc-open without cap (4 args)"
  (define body (parse-defproc-body '(defproc reader (proc-open "/data" : DataSession (proc-stop)))))
  (check-true (surf-proc-open? body))
  (check-equal? (surf-proc-open-cap body) #f)
  (check-true (surf-proc-stop? (surf-proc-open-cont body))))

(test-case "parse: proc-open error on too few args"
  (define result (parse-datum '(defproc reader (proc-open "/data"))))
  ;; Should be a parse error since proc-open needs at least 4 args
  (check-true (prologos-error? result)))

(test-case "parse: proc-open session type is parsed"
  (define body (parse-defproc-body '(defproc reader (proc-open "/data" : (Send String End) NetCap (proc-stop)))))
  (check-true (surf-proc-open? body))
  ;; Session type should be a parsed session-type form (list)
  (check-true (not (eq? #f (surf-proc-open-session-type body)))))

;; ========================================
;; Pretty-print: boundary operations
;; ========================================

(test-case "pp: proc-open with cap renders correctly"
  (define p (proc-open (expr-string "test") (expr-fvar 'S) (expr-fvar 'FsCap) (proc-stop)))
  (define s (pp-process p))
  (check-true (string-contains? s "open"))
  (check-true (string-contains? s "FsCap")))

(test-case "pp: proc-connect without cap renders correctly"
  (define p (proc-connect (expr-string "host") (expr-fvar 'S) #f (proc-stop)))
  (define s (pp-process p))
  (check-true (string-contains? s "connect"))
  (check-false (string-contains? s "{")))

(test-case "pp: proc-listen with cap renders correctly"
  (define p (proc-listen (expr-nat-val 8080) (expr-fvar 'S) (expr-fvar 'NetCap) (proc-stop)))
  (define s (pp-process p))
  (check-true (string-contains? s "listen"))
  (check-true (string-contains? s "NetCap")))

;; ========================================
;; E2E: boundary operations in defproc
;; ========================================

(test-case "e2e: defproc with proc-open inside body elaborates"
  ;; Must define session types first; no session type annotation on defproc = no type-check
  (define result
    (run-with-caps
     (string-append
      "(session DataSession (Recv String End))\n"
      "(defproc reader (proc-open \"/data\" : DataSession FsCap (proc-stop)))")))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

(test-case "e2e: defproc with proc-connect inside body elaborates"
  (define result
    (run-with-caps
     (string-append
      "(session HttpSession (Send String End))\n"
      "(defproc connector (proc-connect \"localhost\" : HttpSession NetCap (proc-stop)))")))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

(test-case "e2e: defproc with proc-listen inside body elaborates"
  (define result
    (run-with-caps
     (string-append
      "(session ServerSession (Recv String End))\n"
      "(defproc server (proc-listen 8080 : ServerSession NetCap (proc-stop)))")))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))

(test-case "e2e: proc-open without cap also elaborates"
  (define result
    (run (string-append
          "(session DataSession (Recv String End))\n"
          "(defproc reader (proc-open \"/data\" : DataSession (proc-stop)))")))
  (check-true (string? result))
  (check-true (string-contains? result "defined")))
