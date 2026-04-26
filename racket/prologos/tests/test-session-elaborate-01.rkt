#lang racket/base

;;;
;;; Tests for session/process elaboration (Phase S3a-d)
;;; Full pipeline: parse → preparse → elaborate → driver
;;;

(require rackunit
         racket/list
         racket/string
         "../driver.rkt"
         "../errors.rkt"
         "../sessions.rkt"
         "../processes.rkt"
         "../macros.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../pretty-print.rkt")

;; Helper: process a string through the full pipeline, return last result
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 )
    (define results (process-string s))
    (if (list? results)
        (car (reverse results))
        results)))

;; Helper: run all commands in sequence, preserving state between them
(define (run-all s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-session-registry (hasheq)]
                 [current-module-registry (hasheq)]
                 )
    (process-string s)))

;; ========================================
;; Session declaration: basic types
;; ========================================

(test-case "session elab: Send/End"
  (check-equal? (run "(session Greeting (Send String End))")
                "session Greeting defined."))

(test-case "session elab: Recv/End"
  (check-equal? (run "(session Listen (Recv Nat End))")
                "session Listen defined."))

(test-case "session elab: multi-step Send/Recv/End"
  (check-equal? (run "(session Echo (Send String (Recv String End)))")
                "session Echo defined."))

;; ========================================
;; Session declaration: dependent types
;; ========================================

(test-case "session elab: DSend"
  (check-equal? (run "(session DepSend (DSend (n : Nat) End))")
                "session DepSend defined."))

(test-case "session elab: DRecv"
  (check-equal? (run "(session DepRecv (DRecv (x : Bool) End))")
                "session DepRecv defined."))

;; ========================================
;; Session declaration: choice and offer
;; ========================================

(test-case "session elab: Choice with branches"
  (check-equal? (run "(session Counter (Choice ((inc (Send Nat End)) (done End))))")
                "session Counter defined."))

(test-case "session elab: Offer with branches"
  (check-equal? (run "(session Server (Offer ((get (Send String End)) (put (Recv String End)))))")
                "session Server defined."))

;; ========================================
;; Session declaration: recursion
;; ========================================

(test-case "session elab: Mu anonymous with session-name label"
  (check-equal? (run "(session Loop (Mu (Send Nat (SVar Loop))))")
                "session Loop defined."))

(test-case "session elab: Mu with explicit label"
  (check-equal? (run "(session Counter (Mu Again (Choice ((inc (Send Nat (SVar Again))) (done End)))))")
                "session Counter defined."))

;; ========================================
;; Process definition: basic
;; ========================================

(test-case "defproc elab: send/stop with type-check"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Greeting (Send String End))\n(defproc greeter : Greeting (proc-send self \"hello\" (proc-stop)))")))
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-equal? (first result) "session Greeting defined.")
  ;; Process should type-check against its session type
  (check-true (string-contains? (second result) "type-checked")))

(test-case "defproc elab: without type annotation"
  (check-equal? (run "(defproc worker (proc-stop))")
                "defproc worker defined."))

;; ========================================
;; Dual computation
;; ========================================

(test-case "dual: Send becomes Recv"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Echo (Send String (Recv String End)))\n(dual Echo)")))
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-equal? (first result) "session Echo defined.")
  ;; dual(Send String . Recv String . End) = Recv String . Send String . End
  (check-equal? (second result) "dual Echo = [?String . [!String . end]]"))

(test-case "dual: Choice becomes Offer"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Counter (Choice ((inc (Send Nat End)) (done End))))\n(dual Counter)")))
  (check-true (list? result))
  ;; dual(Choice {inc: Send Nat End, done: End}) = Offer {inc: Recv Nat End, done: End}
  (check-true (string-contains? (second result) "&{")))

;; ========================================
;; Session registry: cross-reference
;; ========================================

(test-case "session reference: use previously defined session in process"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Greeting (Send String End))\n(defproc g : Greeting (proc-send self \"hi\" (proc-stop)))")))
  (check-true (list? result))
  (check-true (string-contains? (second result) "type-checked")))

;; ========================================
;; Error cases
;; ========================================

(test-case "session elab: unbound recursion variable"
  (define result (run "(session Bad (Mu (Send Nat (SVar Unknown))))"))
  (check-true (prologos-error? result))
  (check-true (string-contains? (prologos-error-message result)
                                "Unbound session recursion variable")))

(test-case "dual: unknown session"
  (define result (run "(dual NonexistentSession)"))
  (check-true (prologos-error? result)))

;; ========================================
;; Process elaboration: offer branches
;; ========================================

(test-case "defproc elab: proc-case with branches"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Counter (Offer ((inc (Recv Nat End)) (done End))))\n(defproc handler : Counter (proc-case self ((inc (proc-recv self x (proc-stop))) (done (proc-stop)))))")))
  (check-true (list? result))
  (check-equal? (first result) "session Counter defined.")
  (check-true (string-contains? (second result) "type-checked")))

;; ========================================
;; Process elaboration: select
;; ========================================

(test-case "defproc elab: proc-sel"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Counter (Choice ((inc (Send Nat End)) (done End))))\n(defproc chooser : Counter (proc-sel self inc (proc-send self 42N (proc-stop))))")))
  (check-true (list? result))
  (check-true (string-contains? (second result) "type-checked")))

;; ========================================
;; Process: new + par + link
;; ========================================

(test-case "defproc elab: proc-new with par"
  (define result
    (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                   [current-ns-context #f]
                   [current-session-registry (hasheq)]
                   [current-module-registry (hasheq)]
                   )
      (process-string
       "(session Greeting (Send String End))\n(defproc composed (proc-new Greeting (proc-par (proc-send c \"hi\" (proc-stop)) (proc-recv c x (proc-stop)))))")))
  ;; Should elaborate (not fail) — no session type annotation on defproc, no type-check
  ;; process-string returns a list of results, one per top-level form
  (check-true (list? result))
  (check-equal? (length result) 2)
  (check-equal? (first result) "session Greeting defined.")
  (check-true (string-contains? (second result) "defined")))
