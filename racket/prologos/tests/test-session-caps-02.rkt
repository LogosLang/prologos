#lang racket/base

;;;
;;; Tests for capability delegation and warnings (Phase S5c)
;;; Validates W2002 (dead authority) and W2003 (ambient authority) warnings.
;;;

(require rackunit
         racket/list
         racket/string
         "../syntax.rkt"
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
         "../warnings.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run with caps pre-loaded, return LAST result string
;; (warnings are appended to the result string by the driver)
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
                      s)))
    (if (and (list? results) (not (null? results)))
        (last results)
        results)))

;; ========================================
;; W2002: Dead authority
;; ========================================

(test-case "W2002: cap declared but unused in process body"
  ;; defproc with NetCap in header but no boundary ops in body
  (define result
    (run-with-caps
     (string-append
      "(session Greeting (Send String End))\n"
      "(defproc handler : Greeting ($brace-params net :0 NetCap) (proc-send self \"hello\" (proc-stop)))")))
  (check-true (string? result))
  ;; Should type-check AND have W2002 warning appended
  (check-true (string-contains? result "type-checked"))
  (check-true (string-contains? result "W2002")))

(test-case "W2002: no warning when cap is used in boundary op"
  ;; defproc with FsCap in header AND proc-open in body using FsCap
  (define result
    (run-with-caps
     (string-append
      "(session DataSession (Recv String End))\n"
      "(defproc reader ($brace-params fs :0 FsCap) (proc-open \"/data\" : DataSession FsCap (proc-stop)))")))
  (check-true (string? result))
  ;; Should NOT contain W2002
  (check-false (string-contains? result "W2002")))

(test-case "W2002: cap without session type triggers warning"
  ;; defproc with cap but no session type, no boundary ops
  (define result
    (run-with-caps
     "(defproc handler ($brace-params net :0 NetCap) (proc-stop))"))
  (check-true (string? result))
  (check-true (string-contains? result "defined"))
  (check-true (string-contains? result "W2002")))

;; ========================================
;; W2003: Ambient authority
;; ========================================

(test-case "W2003: :w cap in process header triggers warning"
  ;; :w multiplicity on a capability in process header
  (define result
    (run-with-caps
     (string-append
      "(session Greeting (Send String End))\n"
      "(defproc handler : Greeting ($brace-params net :w NetCap) (proc-send self \"hello\" (proc-stop)))")))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked"))
  (check-true (string-contains? result "W2003")))

(test-case "W2003: :0 cap does NOT trigger W2003"
  ;; :0 multiplicity should not trigger ambient authority warning
  (define result
    (run-with-caps
     (string-append
      "(session Greeting (Send String End))\n"
      "(defproc handler : Greeting ($brace-params net :0 NetCap) (proc-send self \"hello\" (proc-stop)))")))
  (check-true (string? result))
  ;; Should NOT contain W2003
  (check-false (string-contains? result "W2003")))

;; ========================================
;; No false positives
;; ========================================

(test-case "no warnings: defproc without any caps"
  ;; No caps at all — no process-cap warnings expected
  (define result
    (run-with-caps
     (string-append
      "(session Greeting (Send String End))\n"
      "(defproc handler : Greeting (proc-send self \"hello\" (proc-stop)))")))
  (check-true (string? result))
  (check-true (string-contains? result "type-checked"))
  ;; No W2002 or W2003
  (check-false (string-contains? result "W2002"))
  (check-false (string-contains? result "W2003")))
