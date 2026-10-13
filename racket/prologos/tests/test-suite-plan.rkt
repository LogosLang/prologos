#lang racket/base

;;; test-suite-plan.rkt — the test runner's scheduling decisions (tools/suite-plan.rkt).
;;;
;;; Pure functions, no prelude: these pin DECISIONS the runner makes, which are
;;; otherwise visible only as suite wall time — the reason the LPT sort could be
;;; inert for months (string keys in a `hasheq`; see suite-plan.rkt's header).

(require rackunit
         json
         racket/string
         "../tools/suite-plan.rkt")

(define (run-record file-count results)
  (jsexpr->string
   (hasheq 'file_count file-count
           'results (for/list ([r (in-list results)])
                      (hasheq 'file (car r) 'wall_ms (cdr r))))))

;; ========================================
;; historical-medians — the LPT key source
;; ========================================

(test-case "suite-plan/medians: a FRESHLY BUILT key finds its median (the inert-LPT regression)"
  ;; THE pin. The runner looks a file up by a string it builds from a path;
  ;; that string is never `eq?` to the one read from JSON. Under the old
  ;; `for/hasheq` this lookup returned the +inf.0 default for every file.
  (define lines (list (run-record 200 '(("test-whale.rkt" . 96000) ("test-small.rkt" . 500)))))
  (define med (historical-medians lines))
  (define fresh-key (string-append "test-" "whale.rkt"))
  (check-equal? (hash-ref med fresh-key #f) 96000)
  (check-equal? (hash-ref med (string-copy "test-small.rkt") #f) 500))

(test-case "suite-plan/medians: median over the N most recent FULL runs only"
  (define lines
    (list (run-record 200 '(("a.rkt" . 1000)))      ; oldest — outside the window of 3
          (run-record 200 '(("a.rkt" . 10)))
          (run-record 3   '(("a.rkt" . 999999)))    ; targeted run — excluded
          (run-record 200 '(("a.rkt" . 30)))
          (run-record 200 '(("a.rkt" . 20)))))
  (check-equal? (hash-ref (historical-medians lines #:runs 3) "a.rkt") 20))

(test-case "suite-plan/medians: malformed lines and an empty history are tolerated"
  (check-equal? (hash-count (historical-medians '())) 0)
  (check-equal? (hash-ref (historical-medians (list "{not json" (run-record 200 '(("a.rkt" . 7)))))
                          "a.rkt")
                7))
