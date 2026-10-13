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
         "../tools/suite-plan.rkt"
         (only-in "../tools/suite-lock.rkt" SUITE-LOCK-BUSY-EXIT))

;; A run record of `file-count` files. Unless #:complete? #f, the given results
;; are padded with filler files so that len(results) = file_count, as a run that
;; reported every file has (an INCOMPLETE record is the #:complete? #f case).
(define (run-record file-count results #:complete? [complete? #t] #:extra [extra (hasheq)])
  (define rs (for/list ([r (in-list results)]) (hasheq 'file (car r) 'wall_ms (cdr r))))
  (define padded
    (if complete?
        (append rs (for/list ([i (in-range (max 0 (- file-count (length rs))))])
                     (hasheq 'file (format "pad-~a.rkt" i) 'wall_ms 1)))
        rs))
  (jsexpr->string
   (for/fold ([h (hasheq 'file_count file-count 'results padded)]) ([(k v) (in-hash extra)])
     (hash-set h k v))))

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

(test-case "suite-plan/medians: a record with FEWER RESULTS than file_count is skipped (DEFERRED 164)"
  ;; 13 such records sit in main's timings.jsonl: runs that lost workers and
  ;; were recorded as full suites before the INCOMPLETE gate (fd2986cc).
  (define lines
    (list (run-record 200 '(("a.rkt" . 10)))
          (run-record 200 '(("a.rkt" . 999999)) #:complete? #f)))   ; newest, 1 of 200
  (check-equal? (hash-ref (historical-medians lines) "a.rkt") 10))

(test-case "suite-plan/medians: an ANNOTATED record (\"invalid\") is skipped; skips do not use up the window"
  (define lines
    (list (run-record 200 '(("a.rkt" . 10)))
          (run-record 200 '(("a.rkt" . 20)))
          (run-record 200 '(("a.rkt" . 777777)) #:extra (hasheq 'invalid "annotated by hand"))
          (run-record 200 '(("a.rkt" . 888888)) #:complete? #f)))
  ;; window of 2 VALID runs: 10 and 20 -> median index 1 of sorted = 20
  (check-equal? (hash-ref (historical-medians lines #:runs 2) "a.rkt") 20)
  (check-equal? (record-invalid-reason (hasheq 'file_count 3 'results '())) "results 0 < file_count 3 (DEFERRED 164)")
  (check-equal? (record-invalid-reason (hasheq 'invalid "x" 'file_count 3 'results '())) "x")
  (check-false (record-invalid-reason (hasheq 'file_count 1 'results (list (hasheq)))))
  (check-false (record-invalid-reason (hasheq 'results '())) "no file_count: no claim to check"))

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

;; ========================================
;; The gate — what counts as a result (DEFERRED 161, 164)
;; ========================================

(define (res file status tests #:shard [shard #f])
  (define h (hasheq 'file file 'status status 'tests tests 'wall_ms 1))
  (if shard (hash-set h 'shard shard) h))

(test-case "suite-plan/gate: a unit that reports PASS with 0 tests is NO RESULT (DEFERRED 161)"
  ;; test-generators.rkt reported pass/0 tests/0 ms on a cold build and the
  ;; run was recorded as "10257 tests ... all pass".
  (define-values (missing empty failed stale)
    (gate-verdict 2 (list (res "test-generators.rkt" "pass" 0) (res "test-a.rkt" "pass" 5))))
  (check-equal? missing 0)
  (check-equal? (map (lambda (r) (hash-ref r 'file)) empty) '("test-generators.rkt"))
  (check-equal? failed '())
  (check-false (gate-all-pass? 2 (list (res "test-generators.rkt" "pass" 0) (res "test-a.rkt" "pass" 5))))
  (check-true (gate-incomplete? 2 (list (res "test-generators.rkt" "pass" 0) (res "test-a.rkt" "pass" 5))))
  (check-true (gate-all-pass? 2 (list (res "test-generators.rkt" "pass" 5) (res "test-a.rkt" "pass" 5)))))

(test-case "suite-plan/gate: an EMPTY SHARD is no result either; a result with no 'tests key is 0"
  (define-values (m e f s)
    (gate-verdict 2 (list (res "w.rkt" "pass" 9 #:shard "0/2") (res "w.rkt" "pass" 0 #:shard "1/2"))))
  (check-equal? (map (lambda (r) (hash-ref r 'shard)) e) '("1/2"))
  (define-values (m2 e2 f2 s2) (gate-verdict 1 (list (hasheq 'file "x.rkt" 'status "pass"))))
  (check-equal? (length e2) 1))

(test-case "suite-plan/gate: a DECLARED test-free file may run 0 tests; a stale declaration is reported"
  (define tf (car TEST-FREE-FILES))
  (define-values (m e f stale) (gate-verdict 1 (list (res tf "pass" 0))))
  (check-equal? e '())
  (check-true (gate-all-pass? 1 (list (res tf "pass" 0))))
  (define-values (m2 e2 f2 stale2) (gate-verdict 1 (list (res tf "pass" 3))))
  (check-equal? (map (lambda (r) (hash-ref r 'file)) stale2) (list tf) "it ran tests: drop it from the list"))

(test-case "suite-plan/gate: missing units are incomplete; a failure with 0 tests is a FAILURE, not empty"
  (define rs (list (res "test-a.rkt" "fail" 0) (res "test-b.rkt" "timeout" 0)))
  (define-values (missing empty failed stale) (gate-verdict 3 rs))
  (check-equal? missing 1)
  (check-equal? empty '())
  (check-equal? (length failed) 2)
  (check-true (gate-incomplete? 3 rs))
  (check-false (gate-incomplete? 2 rs))
  (check-false (gate-all-pass? 2 rs)))

(test-case "suite-plan/discovery: test-support.rkt is the WORKER's fixture, not a test unit"
  ;; Every batch worker loads it at startup (batch-worker.rkt), so dispatching
  ;; it is a cached no-op that always reports 0 tests.
  (check-equal? (drop-non-test-modules '(test-a.rkt test-support.rkt test-b.rkt))
                '(test-a.rkt test-b.rkt))
  (check-equal? (drop-non-test-modules (list "/x/tests/test-support.rkt" "/x/tests/test-a.rkt"))
                (list "/x/tests/test-a.rkt")))

;; ========================================
;; Exit status
;; ========================================

(test-case "suite-plan/exit codes: ran-nothing outcomes are NONZERO and every outcome is distinct"
  ;; DEFERRED 164 open(2): the re-run GUARD exited 0 having run nothing.
  (define codes (list EXIT-PASS EXIT-FAILURES EXIT-INCOMPLETE EXIT-GUARD-REFUSED SUITE-LOCK-BUSY-EXIT))
  (check-equal? EXIT-PASS 0)
  (check-false (zero? EXIT-GUARD-REFUSED) "a refused run must not read as green")
  (check-false (zero? SUITE-LOCK-BUSY-EXIT))
  (check-equal? (length (remove-duplicates codes)) (length codes)))

;; ========================================
;; Failure-log archive (DEFERRED 160 support)
;; ========================================

(test-case "suite-plan/failure archive: run ids sort chronologically and are unique per process"
  (define a (make-run-id 1791891501 42))
  (define b (make-run-id 1791891502 7))
  (check-regexp-match #px"^[0-9]{8}T[0-9]{6}-42$" a)
  (check-true (string<? a b))
  (check-not-equal? (make-run-id 1791891501 42) (make-run-id 1791891501 43)))

(test-case "suite-plan/failure archive: retention keeps the newest N runs, never the excess"
  (define names (for/list ([i 25]) (make-run-id (+ 1791891501 (* 60 i)) 1)))
  (define doomed (runs-to-prune (reverse names) #:keep 20))
  (check-equal? (length doomed) 5)
  (check-equal? (sort doomed string<?) (take names 5) "the OLDEST five go")
  (check-equal? (runs-to-prune (take names 3) #:keep 20) '())
  (check-equal? FAILURE-RUNS-KEPT 20))

(test-case "suite-plan/failure archive: a file's logs are its whole-file log and its shard logs, nothing else"
  (define names '("test-a.rkt.log" "test-a.rkt.shard-1-of-4.log" "test-ab.rkt.log"
                  "test-a.rkt.log.bak" "runs" "latest" "test-b.rkt.shard-0-of-2.log"))
  (check-equal? (sort (file-log-names "test-a.rkt" names) string<?)
                '("test-a.rkt.log" "test-a.rkt.shard-1-of-4.log"))
  (check-equal? (file-log-names "test-c.rkt" names) '()))

;; ========================================
;; Worker stderr (DEFERRED 164 open 4) and dead-worker diagnosis
;; ========================================

(test-case "suite-plan/stderr: each line goes to the unit the worker was running when it arrived"
  (define a (work-unit "/p/tests/test-a.rkt" #f 1 1.0))
  (define w (work-unit "/p/tests/test-w.rkt" 1 4 1.0))
  (define by (attribute-stderr (list (cons 100 a) (cons 200 w))
                               (list (cons 50 "startup noise") (cons 150 "during a")
                                     (cons 200 "at w's dispatch") (cons 900 "late in w"))))
  (check-equal? (hash-ref by #f) '("startup noise") "before any dispatch: the worker itself")
  (check-equal? (hash-ref by (work-unit-label a)) '("during a"))
  (check-equal? (hash-ref by (work-unit-label w)) '("at w's dispatch" "late in w"))
  (check-equal? (work-unit-label w) "test-w.rkt [shard 1/4]")
  (check-equal? (result-label (hasheq 'file "test-w.rkt" 'shard "1/4")) (work-unit-label w))
  (check-equal? (result-label (hasheq 'file "test-a.rkt")) (work-unit-label a))
  (check-equal? (hash-count (attribute-stderr '() '())) 0))

(test-case "suite-plan/stderr: a unit's log name matches batch-worker.rkt's"
  (check-equal? (unit-log-name "test-a.rkt" #f) "test-a.rkt.log")
  (check-equal? (unit-log-name "test-w.rkt" "1/4") "test-w.rkt.shard-1-of-4.log")
  (check-equal? (file-log-names "test-w.rkt" (list (unit-log-name "test-w.rkt" "1/4"))) (list "test-w.rkt.shard-1-of-4.log")))

;; Verbatim worker stderr from the item-(h) repro (2026-10-13): driver.rkt
;; rebuilt, tests/compiled/test-support_rkt.zo left stale.
(define stale-support-stderr
  (list "instantiate-linklet: mismatch;"
        " reference to a variable that is not exported"
        "  name: process-file31.1"
        "  exporting instance: \"/w/racket/prologos/driver.rkt\""
        "  importing instance: \"/w/racket/prologos/tests/test-support.rkt\""
        "  possible reason: modules need to be recompiled because dependencies changed"))

(test-case "suite-plan/dead workers: a linklet mismatch NAMES the stale module (not 'raco make driver.rkt')"
  (check-equal? (diagnose-worker-stderr stale-support-stderr)
                (list 'stale-module "/w/racket/prologos/tests/test-support.rkt"))
  (check-false (diagnose-worker-stderr '("some other crash" "context...:")))
  (check-false (diagnose-worker-stderr '())))

(test-case "suite-plan/stderr: the prelude's metric lines are not evidence"
  (check-true (metric-line? "PERF-COUNTERS:{\"cell_allocs\":0}"))
  (check-true (metric-line? "CELL-METRICS:{\"cells\":37}"))
  (check-false (metric-line? "instantiate-linklet: mismatch;"))
  (check-false (metric-line? "  PERF-COUNTERS: indented is not the prefix")))

;; ========================================
;; Worker -> unit sequence (DEFERRED 160 support ii)
;; ========================================

(test-case "suite-plan/worker sequence: per worker, the exact work lines in dispatch order, replayable"
  (define root "/p/racket/prologos/")
  (define seqs
    (worker-sequences root
                      (list (list 0 101 (list (work-unit "/p/racket/prologos/tests/test-b.rkt" #f 1 1.0)
                                              (work-unit "/p/racket/prologos/tests/test-w.rkt" 2 4 1.0)))
                            (list 1 102 (list (work-unit "/elsewhere/test-x.rkt" #f 1 1.0))))))
  (check-equal? (map (lambda (h) (hash-ref h 'worker)) seqs) '(0 1))
  (check-equal? (hash-ref (car seqs) 'pid) 101)
  (check-equal? (hash-ref (car seqs) 'units) '("tests/test-b.rkt" "tests/test-w.rkt\t2/4")
                "relative to the project root, shard suffix kept: what batch-worker --stdin reads")
  (check-equal? (hash-ref (cadr seqs) 'units) '("/elsewhere/test-x.rkt") "outside the root: absolute")
  ;; each line round-trips through the worker's parser
  (define-values (p sh k) (parse-work-line (cadr (hash-ref (car seqs) 'units))))
  (check-equal? (list p sh k) '("tests/test-w.rkt" 2 4)))
