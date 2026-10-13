#lang racket/base

;;; test-suite-plan.rkt — the test runner's scheduling decisions (tools/suite-plan.rkt).
;;;
;;; Pure functions, no prelude: these pin DECISIONS the runner makes, which are
;;; otherwise visible only as suite wall time — the reason the LPT sort could be
;;; inert for months (string keys in a `hasheq`; see suite-plan.rkt's header).

(require rackunit
         json
         racket/list
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

;; ========================================
;; Sharding — shard-count / plan-units
;; ========================================

(test-case "suite-plan/shard-count: ceil(median/target), capped at workers; off cases are 1"
  (check-equal? (shard-count 111600 30000 18) 4)   ; test-path-selection's median
  (check-equal? (shard-count 28400 30000 18) 1)    ; under target: whole file
  (check-equal? (shard-count 111600 30000 3) 3)    ; capped: K shards need K workers
  (check-equal? (shard-count 111600 30000 1) 1)    ; one worker: cannot shard
  (check-equal? (shard-count +inf.0 30000 18) 1)   ; unknown history: never shard
  (check-equal? (shard-count #f 30000 18) 1)
  (check-equal? (shard-count 111600 0 18) 1))      ; target 0 = disabled

(test-case "suite-plan/plan-units: a whale becomes K units, all heaviest-first, unknown first"
  (define est (hash "w.rkt" 90000 "a.rkt" 20000 "b.rkt" 1000))
  (define us (plan-units '("b.rkt" "w.rkt" "new.rkt" "a.rkt")
                         (lambda (p) (hash-ref est p #f))
                         #:target-ms 30000 #:max-k 18))
  (check-equal? (map work-unit-path us) '("new.rkt" "w.rkt" "w.rkt" "w.rkt" "a.rkt" "b.rkt"))
  (check-equal? (for/list ([u us] #:when (equal? (work-unit-path u) "w.rkt")) (work-unit-shard u))
                '(0 1 2))
  (check-equal? (work-unit-est (cadr us)) 30000)
  (check-false (work-unit-shard (car us))))

(test-case "suite-plan/line protocol round-trips; a bare path is a whole file"
  (for ([u (list (work-unit "tests/test-x.rkt" 2 4 1.0) (work-unit "tests/test-y.rkt" #f 1 1.0))])
    (define-values (p s k) (parse-work-line (work-unit->line u)))
    (check-equal? (list p s k) (list (work-unit-path u) (work-unit-shard u) (work-unit-k u)))))

;; ========================================
;; Dispatch — pick-eligible + a liveness simulation of the runner's loop
;; ========================================

(test-case "suite-plan/pick-eligible skips files this worker already ran, keeps order"
  (define us (list (work-unit "w" 1 2 5) (work-unit "a" #f 1 4) (work-unit "w" 2 3 3)))
  (define-values (u rest) (pick-eligible us (lambda (p) (equal? p "w"))))
  (check-equal? (work-unit-path u) "a")
  (check-equal? rest (list (work-unit "w" 1 2 5) (work-unit "w" 2 3 3)))
  (define-values (none rest2) (pick-eligible (list (work-unit "w" 1 2 5)) (lambda (p) #t)))
  (check-false none)
  (check-equal? (length rest2) 1))

;; Simulate the runner: W workers, each takes eligible units until none is
;; eligible, then RETIRES (stdin closed) — exactly run-affected-tests' rule.
(define (simulate units W seed)
  (random-seed seed)
  (define ran (make-vector W '()))          ; worker -> paths run
  (define alive (make-vector W #t))
  (define clock (make-vector W 0))
  (define pending units)
  (define dispatched '())
  (define (dispatch! w)
    (define-values (u rest) (pick-eligible pending (lambda (p) (member p (vector-ref ran w)))))
    (cond
      [u (set! pending rest)
         (vector-set! ran w (cons (work-unit-path u) (vector-ref ran w)))
         (vector-set! clock w (+ (vector-ref clock w) 1 (random 100)))
         (set! dispatched (cons (cons w u) dispatched))]
      [else (vector-set! alive w #f)]))
  (for ([w (in-range W)]) (dispatch! w))
  (let loop ()
    (define live (for/list ([w (in-range W)] #:when (vector-ref alive w)) w))
    (unless (null? live)
      ;; the live worker that finishes next asks for more
      (dispatch! (argmin (lambda (w) (vector-ref clock w)) live))
      (loop)))
  (values pending dispatched ran))

(test-case "suite-plan/dispatch is LIVE and never gives one worker two shards of a file"
  ;; ⚠ The shards must still be PENDING after the first dispatch round, or the
  ;; constraint is never exercised (with K <= W the first round hands K shards
  ;; to K distinct workers by construction — the first draft of this test passed
  ;; with the constraint deleted). W never-seen files (+inf.0, dispatched first)
  ;; fill the first round; two whales' shards then compete for returning workers.
  (for* ([W (in-list '(2 3 4 18))]
         [seed (in-range 25)])
    (define paths (append (for/list ([i W]) (format "new~a.rkt" i))
                          '("whale1.rkt" "whale2.rkt")
                          (for/list ([i 20]) (format "f~a.rkt" i))))
    (define units
      (plan-units paths
                  (lambda (p) (cond [(regexp-match? #rx"^new" p) #f]
                                    [(regexp-match? #rx"^whale" p) 120000]
                                    [else (* 1000 (add1 (string-length p)))]))
                  #:target-ms 30000 #:max-k W))
    (check-true (> (length units) (+ W (* 2 (min W 4)) -1)) "whales must be sharded")
    (define-values (left dispatched ran) (simulate units W seed))
    (check-equal? left '() (format "W=~a seed=~a stranded ~a" W seed left))
    (check-equal? (length dispatched) (length units))
    (for ([w (in-range W)])
      (define ps (vector-ref ran w))
      (check-equal? (length ps) (length (remove-duplicates ps))
                    (format "W=~a seed=~a worker ~a ran a file twice: ~a" W seed w ps)))))

;; ========================================
;; The shard filter
;; ========================================

;; Run N top-level "test-cases" through an around; test #3 contains a NESTED
;; test-case. Returns the labels that actually executed.
(define (run-with-around around n)
  (define ran '())
  (for ([i (in-range n)])
    (around
     (lambda ()
       (set! ran (cons i ran))
       (when (= i 3)
         (around (lambda () (set! ran (cons 'nested-in-3 ran))))))))
  (reverse ran))

(test-case "suite-plan/make-shard-around: shards partition the top-level tests; nested runs with parent"
  (define orig (lambda (thunk) (thunk)))
  (define per-shard
    (for/list ([i (in-range 3)]) (run-with-around (make-shard-around orig i 3) 8)))
  (check-equal? (car per-shard) '(0 3 nested-in-3 6))
  (check-equal? (cadr per-shard) '(1 4 7))
  (check-equal? (caddr per-shard) '(2 5))
  ;; union is everything, exactly once
  (check-equal? (sort (filter number? (apply append per-shard)) <) '(0 1 2 3 4 5 6 7)))

;; ========================================
;; Recording — one timings record per FILE
;; ========================================

(test-case "suite-plan/merge-shard-results: one record per file, sums, worst status, shards kept"
  (define rs
    (list (hasheq 'file "w.rkt" 'shard "0/2" 'wall_ms 30 'tests 10 'status "pass"
                  'phases (hasheq 'reduce_ms 5))
          (hasheq 'file "a.rkt" 'wall_ms 7 'tests 3 'status "pass")
          (hasheq 'file "w.rkt" 'shard "1/2" 'wall_ms 40 'tests 11 'status "fail"
                  'phases (hasheq 'reduce_ms 6) 'error_output "boom")))
  (define m (merge-shard-results rs))
  (check-equal? (map (lambda (r) (hash-ref r 'file)) m) '("w.rkt" "a.rkt"))
  (define w (car m))
  (check-equal? (hash-ref w 'wall_ms) 70)
  (check-equal? (hash-ref w 'tests) 21)
  (check-equal? (hash-ref w 'status) "fail")
  (check-equal? (hash-ref (hash-ref w 'phases) 'reduce_ms) 11)
  (check-equal? (hash-ref w 'error_output) "boom")
  (check-equal? (map (lambda (s) (hash-ref s 'shard)) (hash-ref w 'shards)) '("0/2" "1/2"))
  (check-equal? (cadr m) (cadr rs)))
