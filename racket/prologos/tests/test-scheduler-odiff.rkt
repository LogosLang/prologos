#lang racket/base
;;;
;;; test-scheduler-odiff.rkt
;;; Scheduler O(network-diff) optimization, sub-phase S-b — the D-S.3
;;; debug-gated invariant in fire-and-collect-writes.
;;;
;;; (The champ-diff primitive itself is covered by test-champ-diff.rkt; the
;;;  rewire's behavior-equivalence by the targeted scheduler suite + the
;;;  acceptance/probe files. This file validates only the new invariant guard:
;;;  it FIRES on a real violation (non-vacuous), does NOT false-positive on an
;;;  ordinary mid-fire cell, and is SILENT when off (zero production cost).)
;;;
;;; docs/tracking/2026-06-03_SCHEDULER_ODIFF_OPTIMIZATION.md §7.1/§7.3.

(require rackunit
         (only-in "../propagator.rkt"
                  make-prop-network net-new-cell net-add-propagator net-cell-write
                  fire-and-collect-writes current-check-fire-invariants?))

(define (rep old new) new)

;; Build a network whose single propagator, when fired, creates ONE cell
;; mid-fire. domain=#f → ordinary cell; a symbol → an explicit-domain cell
;; (net-new-cell #:domain writes a cell-domains entry — exactly the metadata
;; bulk-merge-writes' new-cell path would DROP, which D-S.3 guards against).
(define (net-with-cell-creating-prop domain)
  (define net0 (make-prop-network))
  (define-values (net1 trig) (net-new-cell net0 #f rep))
  (define-values (net2 pid)
    (net-add-propagator net1 (list trig) '()
      (lambda (n)
        (define-values (n* _c)
          (if domain
              (net-new-cell n 'v rep #:domain domain)
              (net-new-cell n 'v rep)))
        n*)))
  (values (net-cell-write net2 trig 1) pid))

(test-case "D-S.3 assert FIRES on a domain-carrying cell created mid-fire (check on)"
  (define-values (net pid) (net-with-cell-creating-prop 'TestDomain))
  (parameterize ([current-check-fire-invariants? #t])
    (check-exn #rx"D-S.3 invariant"
               (lambda () (fire-and-collect-writes net pid)))))

(test-case "no false positive: ordinary cell created mid-fire (check on) does not fire"
  (define-values (net pid) (net-with-cell-creating-prop #f))
  (parameterize ([current-check-fire-invariants? #t])
    (check-not-exn (lambda () (fire-and-collect-writes net pid)))))

(test-case "check off (default): domain cell mid-fire is silent (zero production cost)"
  (define-values (net pid) (net-with-cell-creating-prop 'TestDomain))
  (check-not-exn (lambda () (fire-and-collect-writes net pid))))
