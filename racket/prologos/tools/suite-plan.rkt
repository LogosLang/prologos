#lang racket/base

;;; suite-plan.rkt — the test runner's SCHEDULING decisions, as pure functions.
;;;
;;; run-affected-tests.rkt owns processes, ports and progress output; this
;;; module owns the decisions those mechanics carry out, so each decision can
;;; be pinned by a unit test (tests/test-suite-plan.rkt) instead of being
;;; observable only as suite wall time.
;;;
;;; ⚠ WHY THIS MODULE EXISTS (2026-10-13). The runner's LPT ("longest first")
;;; ordering was inert for its whole life: the per-file medians were stored in
;;; a `for/hasheq` keyed by file-name STRINGS and looked up with a freshly built
;;; string, so `eq?` never matched — 0 of 489 lookups hit — every file sorted as
;;; +inf.0 and dispatch was alphabetical. The slowest file (test-path-selection,
;;; ~100 s) therefore started only after the a–o files had cycled through the
;;; workers. The comment that recorded "measured impact was NIL" was measuring a
;;; sort that never sorted. A decision that cannot be unit-tested can be
;;; silently inert; here it is tested.

(require json
         racket/list
         racket/math
         racket/port
         racket/string)

(provide historical-medians
         record-invalid-reason
         (struct-out work-unit)
         shard-count
         plan-units
         work-unit->line
         parse-work-line
         pick-eligible
         make-shard-around
         shard-label
         merge-shard-results
         NON-TEST-MODULES
         TEST-FREE-FILES
         drop-non-test-modules
         gate-verdict
         gate-incomplete?
         gate-all-pass?
         EXIT-PASS
         EXIT-FAILURES
         EXIT-INCOMPLETE
         EXIT-GUARD-REFUSED
         FAILURE-RUNS-KEPT
         make-run-id
         runs-to-prune
         file-log-names)

;; historical-medians : (listof string) #:runs N #:min-file-count M
;;                      -> (hash/c string? exact-nonnegative-integer?)  ; equal?-keyed
;;
;; `lines` are timings.jsonl records in FILE order (oldest first). Uses the N
;; most recent VALID FULL-suite records (file_count >= M — targeted runs time a
;; file without contention and read low; record-invalid-reason excludes
;; partial and annotated records) and returns each file's median wall_ms.
;; Keys are the `file` strings exactly as recorded (base names).
;; The hash is `equal?`-keyed: callers look up with strings they build
;; themselves, which are never `eq?` to the ones read from JSON.
(define (historical-medians lines #:runs [n-runs 5] #:min-file-count [min-files 100])
  (define full-runs
    (let loop ([ls (reverse lines)] [got '()])
      (cond
        [(or (null? ls) (>= (length got) n-runs)) got]
        [else
         (define rec
           (with-handlers ([exn:fail? (lambda (e) #f)])
             (with-input-from-string (car ls) read-json)))
         (loop (cdr ls)
               (if (and (hash? rec)
                        (>= (hash-ref rec 'file_count 0) min-files)
                        (not (record-invalid-reason rec)))  ; DEFERRED 164 open(3)
                   (cons rec got)
                   got))])))
  (define observed
    (for*/fold ([h (hash)])
               ([run (in-list full-runs)]
                [r (in-list (hash-ref run 'results '()))])
      (hash-update h (hash-ref r 'file "") (lambda (v) (cons (hash-ref r 'wall_ms 0) v)) '())))
  (for/hash ([(f ms-list) (in-hash observed)])
    (define sorted (sort ms-list <))
    (values f (list-ref sorted (quotient (length sorted) 2)))))

;; record-invalid-reason : jsexpr -> (or/c string? #f)
;; Why a timings.jsonl record must not be read as a run of its files, or #f.
;;   - it carries an "invalid" annotation (tools/annotate-invalid-timings.rkt);
;;   - it holds FEWER results than its file_count: a fail-open recorded a
;;     partial run as a full one (DEFERRED 164 — 13 such records in main's
;;     file, the newest 2026-07-31). Since fd2986cc the runner no longer
;;     writes them; this keeps any FUTURE fail-open of that shape away from
;;     the scheduler too.
;; A record without file_count makes no claim to check.
(define (record-invalid-reason rec)
  (cond
    [(not (hash? rec)) #f]
    [(hash-ref rec 'invalid #f) => (lambda (why) (if (string? why) why (format "~a" why)))]
    [else
     (define fc (hash-ref rec 'file_count #f))
     (define rs (hash-ref rec 'results '()))
     (define n (if (list? rs) (length rs) 0))
     (and (exact-integer? fc) (< n fc)
          (format "results ~a < file_count ~a (DEFERRED 164)" n fc))]))

;; ============================================================
;; WHALE SHARDING
;; ============================================================
;;
;; A file whose historical median exceeds the target is run as K shards: shard
;; I instantiates the WHOLE module (fixtures and mid-file helpers all exist) but
;; executes only the top-level test-cases whose run-order sequence s ≡ I (mod K).
;; Round-robin rather than contiguous ranges: test cost clusters by section (the
;; CIU T6 tail of test-path-selection holds 42 s in its last 129 tests), and
;; interleaving balances without per-test timings. Measured feasible
;; 2026-10-13: test-path-selection under K=2 and K=3, every shard, 0 failures.
;;
;; Soundness assumption, stated: a test does not depend on state left by the
;; test exactly a multiple of K positions earlier (K=2 and K=3 both passing
;; rules out every distance not divisible by 6). A file that violates it FAILS
;; when sharded — it does not pass silently.
;;
;; Isolation: a batch worker runs many files in ONE namespace, so a second
;; `dynamic-require` of a module it already ran is a cached no-op (0 tests,
;; "pass"). Shards therefore never share a worker — `pick-eligible` — instead of
;; re-instantiating in fresh namespaces, so a shard runs in exactly the
;; environment the unsharded file would.

;; shard I of K of `path`; I = #f means the whole file (K = 1).
;; `est` is the expected wall ms used for LPT ordering (+inf.0 when unknown,
;; so never-seen files go first — conservative).
(struct work-unit (path shard k est) #:transparent)

;; K for a file with median `ms`: ⌈ms / target⌉ when ms > target, capped at
;; max-k (the worker count — K shards need K distinct workers). 1 = unsharded.
;; target <= 0 or #f disables sharding; unknown/infinite ms is never sharded.
(define (shard-count ms target-ms max-k)
  (if (and target-ms (> target-ms 0) (real? ms) (rational? ms) (> ms target-ms) (>= max-k 2))
      (min max-k (exact-ceiling (/ ms target-ms)))
      1))

;; plan-units : (listof path-string) (path-string -> (or/c real? #f)) -> (listof work-unit)
;; Heaviest first (LPT). `sort` is stable, so equal estimates keep input order.
(define (plan-units paths est-of #:target-ms target-ms #:max-k max-k)
  (define units
    (for*/list ([p (in-list paths)]
                [u (in-list
                    (let* ([ms (est-of p)]
                           [k (shard-count ms target-ms max-k)])
                      (if (= k 1)
                          (list (work-unit p #f 1 (if (and (real? ms) (rational? ms)) ms +inf.0)))
                          (for/list ([i (in-range k)])
                            (work-unit p i k (/ ms k))))))])
      u))
  (sort units > #:key work-unit-est))

;; The worker's stdin protocol: one unit per line. A whole file is its bare
;; path (unchanged from before sharding); a shard is "path<TAB>I/K".
(define (work-unit->line u)
  (if (work-unit-shard u)
      (format "~a\t~a/~a" (work-unit-path u) (work-unit-shard u) (work-unit-k u))
      (work-unit-path u)))

;; -> (values path shard-or-#f k)
(define (parse-work-line line)
  (define m (regexp-match #rx"^(.*)\t([0-9]+)/([0-9]+)$" line))
  (if m
      (values (cadr m) (string->number (caddr m)) (string->number (cadddr m)))
      (values line #f 1)))

;; "I/K" — the label a shard's result carries and the progress line shows.
(define (shard-label shard k) (format "~a/~a" shard k))

;; pick-eligible : (listof work-unit) (path -> boolean) -> (values (or/c work-unit #f) (listof work-unit))
;; The first pending unit whose FILE this worker has not run. Liveness (no
;; pending unit is ever stranded), given every unit is queued up front and
;; K <= workers: a worker retires only when nothing pending is eligible for it,
;; so a worker that has not run file F cannot have retired while a shard of F
;; was pending; at most K-1 workers have run F while one of its shards is
;; pending; so some live worker can take it.
(define (pick-eligible pending ran?)
  (let loop ([ps pending] [skipped '()])
    (cond
      [(null? ps) (values #f pending)]
      [(ran? (work-unit-path (car ps))) (loop (cdr ps) (cons (car ps) skipped))]
      [else (values (car ps) (append (reverse skipped) (cdr ps)))])))

;; make-shard-around : around I K -> around
;; Wraps rackunit's `current-test-case-around`. Counts only TOP-LEVEL
;; test-cases; a test-case nested in a running one always runs with its parent.
(define (make-shard-around orig shard k)
  (define seq -1)
  (define depth 0)
  (lambda (thunk)
    (cond
      [(> depth 0) (orig thunk)]
      [else
       (set! seq (add1 seq))
       (when (= (modulo seq k) shard)
         (dynamic-wind
          (lambda () (set! depth (add1 depth)))
          (lambda () (orig thunk))
          (lambda () (set! depth (sub1 depth)))))])))

;; merge-shard-results : (listof result-hash) -> (listof result-hash)
;; One record per FILE for timings.jsonl: shard results (those carrying 'shard)
;; are folded into a single result at the first shard's position — wall_ms and
;; tests SUM (so the file's median stays comparable across sharded and
;; unsharded history, preamble repeats included), status is the worst, and a
;; 'shards list keeps each shard's own numbers. Unsharded results pass through.
(define (merge-shard-results results)
  (define groups (make-hash))      ; file -> shard results, in arrival order
  (for ([r (in-list results)] #:when (hash-ref r 'shard #f))
    (hash-update! groups (hash-ref r 'file) (lambda (v) (append v (list r))) '()))
  (define (worst statuses)
    (cond [(andmap (lambda (s) (equal? s "pass")) statuses) "pass"]
          [(member "timeout" statuses) "timeout"]
          [else "fail"]))
  (define (sum-hashes hs)
    (for*/fold ([acc (hasheq)]) ([h (in-list hs)] #:when (hash? h) [(k v) (in-hash h)])
      (if (number? v) (hash-set acc k (+ (hash-ref acc k 0) v)) acc)))
  (define (merged file)
    (define rs (hash-ref groups file))
    (define base
      (hasheq 'file file
              'wall_ms (apply + (map (lambda (r) (hash-ref r 'wall_ms 0)) rs))
              'tests (apply + (map (lambda (r) (hash-ref r 'tests 0)) rs))
              'status (worst (map (lambda (r) (hash-ref r 'status "fail")) rs))
              'shards (for/list ([r (in-list rs)])
                        (hasheq 'shard (hash-ref r 'shard)
                                'wall_ms (hash-ref r 'wall_ms 0)
                                'tests (hash-ref r 'tests 0)
                                'status (hash-ref r 'status "fail")))))
    (define phases (filter hash? (map (lambda (r) (hash-ref r 'phases #f)) rs)))
    (define beats (filter hash? (map (lambda (r) (hash-ref r 'heartbeats #f)) rs)))
    (define errs (filter string? (map (lambda (r) (hash-ref r 'error_output #f)) rs)))
    (let* ([h base]
           [h (if (pair? phases) (hash-set h 'phases (sum-hashes phases)) h)]
           [h (if (pair? beats) (hash-set h 'heartbeats (sum-hashes beats)) h)]
           [h (if (pair? errs) (hash-set h 'error_output (string-join errs "\n\n")) h)])
      h))
  (let loop ([rs results] [seen (hash)] [acc '()])
    (cond
      [(null? rs) (reverse acc)]
      [(not (hash-ref (car rs) 'shard #f)) (loop (cdr rs) seen (cons (car rs) acc))]
      [else
       (define f (hash-ref (car rs) 'file))
       (if (hash-ref seen f #f)
           (loop (cdr rs) seen acc)
           (loop (cdr rs) (hash-set seen f #t) (cons (merged f) acc)))])))

;; ============================================================
;; THE GATE — what counts as a result (DEFERRED 161 + 164)
;; ============================================================
;;
;; "All pass" must mean: every dispatched unit REPORTED (164, fd2986cc), and
;; every unit that reported pass RAN AT LEAST ONE TEST (161). A unit reporting
;; pass with 0 tests is a NO-RESULT, like a missing one — test-generators.rkt
;; did exactly that on a cold build and the run was recorded as "10257 tests
;; ... all pass". It applies per UNIT, so an empty shard is caught too (a
;; second dynamic-require of a module in one worker is a cached no-op that
;; looks just like this). A unit that FAILED or timed out with 0 tests is a
;; reported failure, not a missing result: it already makes the run red, and
;; its error is the useful output.
;;
;; WHY AN EXPLICIT LIST, here, rather than a marker comment in each file: an
;; exemption from a gate should be auditable in ONE place and pinned by a test
;; (this module's purpose); a marker travels with copy-paste into a new file
;; and exempts it silently, and the runner would have to read every test
;; file's text to find it. A declared file that DOES run tests is reported as
;; a stale declaration, so the list cannot rot into a blanket exemption.

;; Files under tests/ named like tests that are NOT test units. test-support.rkt
;; is the batch worker's own fixture: every worker loads it at startup
;; (batch-worker.rkt), so dispatching it was a cached no-op that always
;; reported pass with 0 tests — a unit that could only ever measure nothing.
(define NON-TEST-MODULES '("test-support.rkt"))

;; Units that may legitimately run 0 tests: debug scripts that print and
;; exercise code but hold no rackunit checks (the only zero-test units in the
;; last full run besides test-support.rkt). They still RUN (a crash fails them);
;; they are just not required to count tests.
(define TEST-FREE-FILES '("test-multiclause-debug.rkt" "test-p2-debug.rkt"))

(define (base-name x)
  (define s (if (symbol? x) (symbol->string x) (if (path? x) (path->string x) x)))
  (last (string-split s "/")))

;; drop-non-test-modules : (listof (or/c symbol? string? path?)) -> same
(define (drop-non-test-modules xs)
  (filter (lambda (x) (not (member (base-name x) NON-TEST-MODULES))) xs))

(define (passed? r) (equal? (hash-ref r 'status #f) "pass"))

;; gate-verdict : unit-count (listof unit-result) -> (values missing empty failed stale-test-free)
;;   missing          dispatched units with no result
;;   empty            results that say pass with 0 tests, file not declared test-free
;;   failed           results that are not pass
;;   stale-test-free  declared test-free results that ran tests (a NOTE, not a failure)
(define (gate-verdict unit-count unit-results #:test-free [tf TEST-FREE-FILES])
  (define (no-tests? r) (eqv? (hash-ref r 'tests 0) 0))
  (define (declared? r) (member (base-name (hash-ref r 'file "")) tf))
  (values (max 0 (- unit-count (length unit-results)))
          (filter (lambda (r) (and (passed? r) (no-tests? r) (not (declared? r)))) unit-results)
          (filter (lambda (r) (not (passed? r))) unit-results)
          (filter (lambda (r) (and (declared? r) (not (no-tests? r)))) unit-results)))

;; No result for some unit: missing, or empty.
(define (gate-incomplete? unit-count unit-results)
  (define-values (missing empty failed stale) (gate-verdict unit-count unit-results))
  (or (> missing 0) (pair? empty)))

(define (gate-all-pass? unit-count unit-results)
  (define-values (missing empty failed stale) (gate-verdict unit-count unit-results))
  (and (= missing 0) (null? empty) (null? failed)))

;; ============================================================
;; EXIT STATUS — one table, so no two outcomes share a code
;; ============================================================
;; ⚠ A run that RAN NOTHING must not exit 0 (DEFERRED 164 open 2): the re-run
;; GUARD's refusal used to `(exit 0)`, so `run --all && git commit`, or an
;; agent reading only the status, took "ran nothing" as green (observed
;; 2026-10-13). suite-lock.rkt's SUITE-LOCK-BUSY-EXIT (75) is the other
;; ran-nothing outcome; tests/test-suite-plan.rkt pins that all are distinct.
(define EXIT-PASS 0)           ; every unit reported, ran tests, and passed
(define EXIT-FAILURES 1)       ; some unit failed or timed out
(define EXIT-INCOMPLETE 2)     ; some unit gave no result, or the run aborted
(define EXIT-GUARD-REFUSED 3)  ; the re-run GUARD refused: nothing was run

;; ============================================================
;; FAILURE-LOG ARCHIVE (DEFERRED 160 support)
;; ============================================================
;; Failure logs used to live only in data/benchmarks/failures/<file>.log, and
;; the worker DELETED a file's log as soon as a later run of it passed — which
;; is how 160's suite-only failure logs were lost: the alone-runs that passed
;; were those later runs. Now every run writes into its own directory,
;;   data/benchmarks/failures/runs/<run-id>/
;; that nothing ever edits afterwards. The top-level <file>.log files remain
;; as the per-file LATEST view (what --failures and every doc that names
;; failures/test-X.rkt.log read), and failures/latest points at the newest
;; kept run. A run that passed completely keeps no directory, so the retention
;; window counts runs that left evidence.
(define FAILURE-RUNS-KEPT 20)

;; "YYYYMMDDTHHMMSS-<pid>", local clock: sorts chronologically as a string.
(define (make-run-id secs pid)
  (define d (seconds->date secs #t))
  (define (p2 n) (if (< n 10) (format "0~a" n) (number->string n)))
  (format "~a~a~aT~a~a~a-~a" (date-year d) (p2 (date-month d)) (p2 (date-day d))
          (p2 (date-hour d)) (p2 (date-minute d)) (p2 (date-second d)) pid))

;; The run directories to delete so that the newest `keep` remain.
(define (runs-to-prune names #:keep [keep FAILURE-RUNS-KEPT])
  (define newest-first (sort names string>?))
  (if (> (length newest-first) keep) (drop newest-first keep) '()))

;; The entries of `names` that are logs of `file`: "<file>.log" and its shard
;; logs "<file>.shard-I-of-K.log" (batch-worker.rkt's two log names).
(define (file-log-names file names)
  (filter (lambda (n)
            (or (string=? n (string-append file ".log"))
                (and (string-prefix? n (string-append file ".shard-"))
                     (string-suffix? n ".log"))))
          names))
