#lang racket/base

;;;
;;; Tests for sexp-mode process parsing (Phase S2b)
;;;

(require rackunit
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../errors.rkt")

;; Helper: parse from string
(define (p s) (parse-string s))

;; ========================================
;; defproc: basic send/recv/stop
;; ========================================

(test-case "process parse: defproc with send/stop"
  (define r (p "(defproc greeter : Greeting (proc-send self \"hello\" (proc-stop)))"))
  (check-true (surf-defproc? r))
  (check-equal? (surf-defproc-name r) 'greeter)
  ;; Session type annotation
  (check-true (surf-var? (surf-defproc-session-type r)))
  (check-equal? (surf-var-name (surf-defproc-session-type r)) 'Greeting)
  ;; Body
  (define body (surf-defproc-body r))
  (check-true (surf-proc-send? body))
  (check-equal? (surf-proc-send-chan body) 'self)
  (check-true (surf-proc-stop? (surf-proc-send-cont body))))

(test-case "process parse: defproc with recv/stop"
  (define r (p "(defproc listener : Listen (proc-recv ch x (proc-stop)))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-recv? body))
  (check-equal? (surf-proc-recv-chan body) 'ch)
  (check-equal? (surf-proc-recv-var body) 'x)
  (check-true (surf-proc-stop? (surf-proc-recv-cont body))))

(test-case "process parse: defproc send then recv"
  (define r (p "(defproc echo : Echo (proc-send self \"hi\" (proc-recv self msg (proc-stop))))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-send? body))
  (define cont (surf-proc-send-cont body))
  (check-true (surf-proc-recv? cont))
  (check-true (surf-proc-stop? (surf-proc-recv-cont cont))))

;; ========================================
;; defproc without session type annotation
;; ========================================

(test-case "process parse: defproc without type annotation"
  (define r (p "(defproc worker (proc-stop))"))
  (check-true (surf-defproc? r))
  (check-equal? (surf-defproc-name r) 'worker)
  (check-false (surf-defproc-session-type r))
  (check-true (surf-proc-stop? (surf-defproc-body r))))

;; ========================================
;; Selection and case (offer)
;; ========================================

(test-case "process parse: proc-sel"
  (define r (p "(defproc chooser : Counter (proc-sel self inc (proc-stop)))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-select? body))
  (check-equal? (surf-proc-select-chan body) 'self)
  (check-equal? (surf-proc-select-label body) 'inc)
  (check-true (surf-proc-stop? (surf-proc-select-cont body))))

(test-case "process parse: proc-case with branches"
  (define r (p "(defproc handler : Counter (proc-case self ((inc (proc-send self 1 (proc-stop))) (done (proc-stop)))))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-offer? body))
  (check-equal? (surf-proc-offer-chan body) 'self)
  (define branches (surf-proc-offer-branches body))
  (check-equal? (length branches) 2)
  (check-true (surf-proc-offer-branch? (car branches)))
  (check-equal? (surf-proc-offer-branch-label (car branches)) 'inc)
  (check-true (surf-proc-send? (surf-proc-offer-branch-body (car branches))))
  (check-equal? (surf-proc-offer-branch-label (cadr branches)) 'done)
  (check-true (surf-proc-stop? (surf-proc-offer-branch-body (cadr branches)))))

;; ========================================
;; Composition: new, par, link
;; ========================================

(test-case "process parse: proc-new with proc-par"
  (define r (p "(defproc composed : S (proc-new Greeting (proc-par (proc-send c \"hi\" (proc-stop)) (proc-recv c x (proc-stop)))))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-new? body))
  ;; Session type for new channel
  (check-true (surf-var? (surf-proc-new-session-type body)))
  (check-equal? (surf-var-name (surf-proc-new-session-type body)) 'Greeting)
  ;; Body is par
  (define par-body (surf-proc-new-body body))
  (check-true (surf-proc-par? par-body))
  (check-true (surf-proc-send? (surf-proc-par-left par-body)))
  (check-true (surf-proc-recv? (surf-proc-par-right par-body))))

(test-case "process parse: proc-link"
  (define r (p "(defproc fwd : S (proc-link c1 c2))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-link? body))
  (check-equal? (surf-proc-link-chan1 body) 'c1)
  (check-equal? (surf-proc-link-chan2 body) 'c2))

(test-case "process parse: proc-par standalone"
  (define r (p "(defproc both : S (proc-par (proc-stop) (proc-stop)))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-par? body))
  (check-true (surf-proc-stop? (surf-proc-par-left body)))
  (check-true (surf-proc-stop? (surf-proc-par-right body))))

;; ========================================
;; Anonymous proc
;; ========================================

(test-case "process parse: anonymous proc with type"
  (define r (p "(proc : Greeting (proc-send self \"hi\" (proc-stop)))"))
  (check-true (surf-proc? r))
  (check-true (surf-var? (surf-proc-session-type r)))
  (check-equal? (surf-var-name (surf-proc-session-type r)) 'Greeting)
  (define body (surf-proc-body r))
  (check-true (surf-proc-send? body)))

(test-case "process parse: anonymous proc without type"
  (define r (p "(proc (proc-stop))"))
  (check-true (surf-proc? r))
  (check-false (surf-proc-session-type r))
  (check-true (surf-proc-stop? (surf-proc-body r))))

;; ========================================
;; Dual
;; ========================================

(test-case "process parse: dual"
  (define r (p "(dual Greeting)"))
  (check-true (surf-dual? r))
  (check-true (surf-var? (surf-dual-session-ref r)))
  (check-equal? (surf-var-name (surf-dual-session-ref r)) 'Greeting))

;; ========================================
;; Recursion
;; ========================================

(test-case "process parse: proc-rec"
  (define r (p "(defproc looper : S (proc-send self 1 (proc-rec Loop)))"))
  (check-true (surf-defproc? r))
  (define body (surf-defproc-body r))
  (check-true (surf-proc-send? body))
  (define cont (surf-proc-send-cont body))
  (check-true (surf-proc-rec? cont))
  (check-equal? (surf-proc-rec-label cont) 'Loop))

;; ========================================
;; Error cases
;; ========================================

(test-case "process parse: defproc missing name"
  (define r (p "(defproc)"))
  (check-true (parse-error? r)))

(test-case "process parse: dual wrong arity"
  (define r (p "(dual A B)"))
  (check-true (parse-error? r)))

(test-case "process parse: unknown proc body form"
  (define r (p "(defproc f : S (bad-form x))"))
  (check-true (parse-error? r)))

(test-case "process parse: proc-stop bare symbol"
  (define r (p "(defproc f : S proc-stop)"))
  (check-true (surf-defproc? r))
  (check-true (surf-proc-stop? (surf-defproc-body r))))
