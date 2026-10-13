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
         targeted-unit-problem
         gate-verdict
         gate-incomplete?
         gate-all-pass?
         prior-test-counts   ;; DEFERRED 81
         count-drops
         EXIT-PASS
         EXIT-FAILURES
         EXIT-INCOMPLETE
         EXIT-GUARD-REFUSED
         EXIT-USAGE
         FAILURE-RUNS-KEPT
         make-run-id
         runs-to-prune
         file-log-names
         unit-label
         work-unit-label
         result-label
         unit-log-name
         attribute-stderr
         diagnose-worker-stderr
         metric-line?
         worker-sequences
         WORKER-MODULE
         WORKER-DYNAMIC-MODULES
         worker-precompile-paths)

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
;;   - one of its units reported PASS having run 0 tests, and the file is not
;;     declared test-free or a non-test module: before 2999a74b the gate took
;;     that as a pass (DEFERRED 161 — 2 such records in main's file, both
;;     `all_pass` true). A result without a 'tests key makes no claim.
;; A record without file_count makes no claim to check.
(define (record-invalid-reason rec)
  (cond
    [(not (hash? rec)) #f]
    [(hash-ref rec 'invalid #f) => (lambda (why) (if (string? why) why (format "~a" why)))]
    [else
     (define fc (hash-ref rec 'file_count #f))
     (define rs (hash-ref rec 'results '()))
     (define n (if (list? rs) (length rs) 0))
     (define (empty-pass? r)
       (and (hash? r) (passed? r) (eqv? (hash-ref r 'tests #f) 0)
            (let ([f (base-name (hash-ref r 'file ""))])
              (not (or (member f NON-TEST-MODULES) (member f TEST-FREE-FILES))))))
     (cond
       [(and (exact-integer? fc) (< n fc))
        (format "results ~a < file_count ~a (DEFERRED 164)" n fc)]
       [(and (list? rs) (findf empty-pass? rs))
        => (lambda (r) (format "unit ~a reported PASS with 0 tests (DEFERRED 161)"
                               (base-name (hash-ref r 'file ""))))]
       [else #f])]))

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

;; targeted-unit-problem : path-string -> (or/c #f string?)
;; Why a path named with --tests is NOT a test unit, or #f (SW-21). Such a
;; path used to be dispatched anyway, report PASS with 0 tests and turn the run
;; INCOMPLETE (EMPTY): true, but it reads as a broken suite when the command
;; simply named the wrong file. The runner refuses it with EXIT-USAGE instead.
;; Outside a tests/ directory nothing is judged: the runner's behaviour there
;; is unchanged.
(define (targeted-unit-problem p)
  (define s (if (path? p) (path->string p) p))
  (define name (base-name s))
  (cond
    [(member name NON-TEST-MODULES)
     (format "~a is the batch worker's own fixture (suite-plan.rkt NON-TEST-MODULES): every worker loads it at startup, so it can only report 0 tests" name)]
    [(and (regexp-match? #rx"(^|/)tests/[^/]+$" s)
          (not (regexp-match? #rx"^test-.*[.]rkt$" name)))
     (format "~a is a test library or fixture, not a test unit (units are tests/test-*.rkt); its checks run through the test files that use it" name)]
    [else #f]))

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
;; DEFERRED 81: a passing file that ran FEWER tests than its last recorded pass
;; ============================================================
;; The suite total can move for a reason no failure shows: on 2026-07 two runs of
;; the same code recorded `test-properties.rkt` as 13 and 8 tests, both all-pass
;; (161's mechanism: a test file required another test file, so the count depended
;; on whether the worker had instantiated it already). Any such mechanism looks
;; like a deleted test, so the runner names every drop and lets a reader decide.
;;
;; prior-test-counts : (listof string) (listof string) #:max-records N
;;                     -> (hash/c string? (list/c exact-nonnegative-integer? string?))
;; For each WANTED file (base name, as recorded), its `tests` in the NEWEST valid
;; timings.jsonl record where it PASSED, with that record's commit. Targeted runs
;; count (a count does not depend on contention). Reads the newest N records only
;; and stops early once every wanted file is found: main's file is ~200 MB, and a
;; scan of all of it for a file never recorded (a new test on a branch) cost ~5 s
;; per run (measured 2026-10-13); one record parses in under 5 ms. A file absent
;; from the newest N records has no baseline. equal?-keyed.
(define (prior-test-counts lines wanted #:max-records [max-records 30])
  (let loop ([ls (reverse lines)] [missing (remove-duplicates wanted)] [seen 0] [acc (hash)])
    (cond
      [(or (null? ls) (null? missing) (>= seen max-records)) acc]
      [else
       (define rec (with-handlers ([exn:fail? (lambda (e) #f)])
                     (with-input-from-string (car ls) read-json)))
       (define rs (and (hash? rec) (not (record-invalid-reason rec)) (hash-ref rec 'results '())))
       (define acc*
         (for/fold ([a acc]) ([r (in-list (if (list? rs) rs '()))])
           (define f (hash-ref r 'file #f))
           (define n (hash-ref r 'tests #f))
           (if (and (member f missing) (not (hash-has-key? a f)) (passed? r)
                    (exact-nonnegative-integer? n))
               (hash-set a f (list n (format "~a" (hash-ref rec 'commit "?"))))
               a)))
       (loop (cdr ls) (filter (lambda (w) (not (hash-has-key? acc* w))) missing) (add1 seen) acc*)])))

;; count-drops : (listof result) prior -> (listof (list file now before commit))
;; Results that PASSED with fewer tests than `prior` records for their file.
(define (count-drops file-results prior)
  (for*/list ([r (in-list file-results)]
              #:when (passed? r)
              [p (in-value (hash-ref prior (hash-ref r 'file "") #f))]
              #:when (and p (exact-nonnegative-integer? (hash-ref r 'tests #f))
                          (< (hash-ref r 'tests) (first p))))
    (list (hash-ref r 'file) (hash-ref r 'tests) (first p) (second p))))

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
(define EXIT-USAGE 64)         ; the command named nothing runnable (EX_USAGE): a
                               ; missing file, or not a test unit (SW-21); nothing was run

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

;; ============================================================
;; WORKER STDERR (DEFERRED 164 open 4)
;; ============================================================
;; batch-worker.rkt captures current-error-port around each FILE, so test
;; output never reaches its real stderr; what does is everything outside that
;; window — a worker that cannot even load (a stale .zo: item (h) of the
;; runner-queue-gate batch), a crash between files, runtime messages. The
;; runner used to open that pipe and never read it: such output was lost, and
;; past the ~64 KB pipe buffer the worker would block. It is now drained on its
;; own thread, timestamped, and attributed here to the unit the worker was
;; running when each line arrived (lines before its first dispatch belong to
;; the worker, key #f). Attribution is by arrival time across two pipes, so a
;; line written at the very end of one unit may land on the next.

;; "test-x.rkt" or "test-x.rkt [shard I/K]" — the name a unit is reported by.
(define (unit-label file shard-label-or-#f)
  (if shard-label-or-#f (format "~a [shard ~a]" file shard-label-or-#f) file))
(define (work-unit-label u)
  (unit-label (last (string-split (work-unit-path u) "/"))
              (and (work-unit-shard u) (shard-label (work-unit-shard u) (work-unit-k u)))))
(define (result-label r)
  (unit-label (hash-ref r 'file "?") (hash-ref r 'shard #f)))

;; batch-worker.rkt's failure-log name for a unit.
(define (unit-log-name file shard-label-or-#f)
  (cond
    [(and shard-label-or-#f (regexp-match #rx"^([0-9]+)/([0-9]+)$" shard-label-or-#f))
     => (lambda (m) (format "~a.shard-~a-of-~a.log" file (cadr m) (caddr m)))]
    [else (string-append file ".log")]))

;; attribute-stderr : (listof (ms . work-unit)) (listof (ms . line)) -> hash
;; Both lists chronological. Key: work-unit-label, or #f before any dispatch.
;; Values: that unit's lines, chronological.
(define (attribute-stderr dispatches lines)
  (define ds (sort dispatches < #:key car))
  (define acc
    (for/fold ([h (hash)]) ([l (in-list (sort lines < #:key car))])
      (define current
        (for/fold ([cur #f]) ([d (in-list ds)] #:break (> (car d) (car l)))
          (work-unit-label (cdr d))))
      (hash-update h current (lambda (v) (cons (cdr l) v)) '())))
  (for/hash ([(k v) (in-hash acc)]) (values k (reverse v))))

;; diagnose-worker-stderr : (listof string) -> (or/c (list 'stale-module path) #f)
;; A worker that died with a linklet mismatch names the module whose .zo is
;; stale: the IMPORTING instance (compiled against an older exporter).
(define (diagnose-worker-stderr lines)
  (and (for/or ([l (in-list lines)]) (regexp-match? #rx"instantiate-linklet: mismatch" l))
       (for/or ([l (in-list lines)])
         (define m (regexp-match #rx"importing instance: \"([^\"]+)\"" l))
         (and m (list 'stale-module (cadr m))))))

;; Machine-readable metric lines every worker writes to its REAL stderr while
;; it loads the prelude (measured 2026-10-13: 5 such lines per worker, every
;; run — PERF-COUNTERS, PHASE-TIMINGS, PROVENANCE-STATS, MEMORY-STATS,
;; CELL-METRICS; batch-worker.rkt strips the same prefixes from a file's
;; captured stderr). They are not evidence: they neither keep a run's log
;; directory nor clutter a unit's log; worker-N.stderr.log keeps them.
(define METRIC-LINE-PREFIXES
  '("PERF-COUNTERS:" "PHASE-TIMINGS:" "PROVENANCE-STATS:" "MEMORY-STATS:" "CELL-METRICS:"))
(define (metric-line? l)
  (for/or ([p (in-list METRIC-LINE-PREFIXES)]) (string-prefix? l p)))

;; ============================================================
;; WORKER -> UNIT SEQUENCE (DEFERRED 160 support ii)
;; ============================================================
;; 160's suite-only failures are conjectured to be state leaking between
;; files that share a worker. To replay one, you need what that worker ran
;; and in which order. Recorded per run: in the timings record ('workers) and
;; in the run's failure directory (run.json). Each unit is the work line as
;; the worker read it, relative to the project root, so a worker's history
;; replays in ONE process from racket/prologos/:
;;   jq -r '.workers[N].units[]' run.json \
;;     | racket tools/batch-worker.rkt --stdin --file-timeout 300
;; worker-sequences : root (listof (list index pid (listof work-unit))) -> jsexpr
(define (worker-sequences root workers)
  (define prefix (let ([r (if (path? root) (path->string root) root)])
                   (if (string-suffix? r "/") r (string-append r "/"))))
  (define (rel p) (if (string-prefix? p prefix) (substring p (string-length prefix)) p))
  (for/list ([w (in-list workers)])
    (hasheq 'worker (car w)
            'pid (cadr w)
            'units (for/list ([u (in-list (caddr w))])
                     (work-unit->line (struct-copy work-unit u [path (rel (work-unit-path u))]))))))

;; ============================================================
;; THE WORKER'S OWN MODULES (item h of the runner-queue-gate batch)
;; ============================================================
;; ⚠ batch-worker.rkt loads tests/test-support.rkt by DYNAMIC-require (on
;; purpose: it must run before the worker snapshots post-prelude state; see
;; batch-worker.rkt § Phase 1). `raco make` follows only static requires, so
;; it never rebuilt test-support.rkt for the worker, and the default load
;; handler trusts a stale .zo. Reproduced 2026-10-13: after a driver.rkt
;; rebuild, `--tests tests/test-substitution.rkt` (a test that does not
;; require test-support.rkt) left tests/compiled/test-support_rkt.zo stale and
;; every worker died at load — "instantiate-linklet: mismatch … name:
;; process-file31.1 … importing instance: tests/test-support.rkt" — printed
;; as DEAD WORKERS, 0 tests, ABORTED. Even `raco make tools/batch-worker.rkt`
;; does not reach it. So the edge is DECLARED here, ONCE: batch-worker.rkt
;; dynamic-requires exactly WORKER-DYNAMIC-MODULES, and every precompile
;; builds worker-precompile-paths in its production stage, after driver.rkt.
;; tests/test-suite-plan.rkt pins both halves (a static read of the worker).
(define WORKER-MODULE "tools/batch-worker.rkt")
(define WORKER-DYNAMIC-MODULES '("tests/test-support.rkt"))   ; relative to racket/prologos/

;; worker-precompile-paths : root -> (listof path-string)  ; absolute
(define (worker-precompile-paths root)
  (define r (let ([s (if (path? root) (path->string root) root)])
              (if (string-suffix? s "/") s (string-append s "/"))))
  (for/list ([m (in-list (cons WORKER-MODULE WORKER-DYNAMIC-MODULES))])
    (string-append r m)))
