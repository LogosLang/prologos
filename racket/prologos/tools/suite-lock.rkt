#lang racket/base

;;; suite-lock.rkt — a MACHINE-WIDE queue for runs that saturate the machine.
;;;
;;; WHY (2026-10-13). run-affected-tests.rkt starts one batch worker per core
;;; (processor-count, 18 on the owner's machine). Two suites from different
;;; sessions, worktrees or clones at once each get about half the machine while
;;; budgeting for all of it, and files near their per-file timeout time out.
;;; Killing the other run is not an answer — DEFERRED 163 is what the old
;;; machine-wide `pkill` did. Waiting is: a second run QUEUES until the first
;;; is done.
;;;
;;; THE PROTOCOL — a writer-preferring readers–writer lock over OS file locks.
;;;   <lock>          the lock proper. 'exclusive: a full suite, or a timing run
;;;                   (bench-ab.rkt, benchmark-tests.rkt). 'shared: a targeted
;;;                   run, which uses a few cores and may overlap other
;;;                   targeted runs.
;;;   <lock>.intent   a TURNSTILE. Every taker holds it (exclusively) on its way
;;;                   to <lock> and lets go once it holds <lock>. A waiting
;;;                   exclusive taker therefore holds the turnstile for as long
;;;                   as it waits, and no new shared taker can slip past it.
;;;                   Without it, a stream of overlapping targeted runs (shared
;;;                   admits shared) could keep a full suite waiting forever.
;;;   <lock>.d/<id>.json  one INFO file per taker, waiting or holding: pid,
;;;                   mode, state, checkout, command, start time. A taker keeps
;;;                   its own info file LOCKED for its lifetime, so a reader
;;;                   tells a live entry from a dead taker's leftover by trying
;;;                   to lock it; leftovers are deleted on sight.
;;;
;;; The default <lock> is per USER, not per checkout: ~/Library/Caches/prologos/
;;; suite.lock on macOS (XDG cache dir elsewhere), so every worktree and clone
;;; queues on the same file. PROLOGOS_SUITE_LOCK overrides it — tests use a
;;; private path so they never wait on, or block, a real run.
;;;
;;; OS facts this relies on, each measured on macOS with Racket 9.3:
;;;   - `port-try-file-lock?` is an OS (flock) lock: another process sees it
;;;     held. Two ports in ONE process on one file conflict too, which is what
;;;     lets tests/test-suite-lock.rkt drive the protocol with threads.
;;;   - The OS drops a process's locks when it exits for ANY reason (exit,
;;;     uncaught exception, SIGKILL), so no exit path can leak the lock itself;
;;;     at most an info file is left behind, and readers clear it.
;;;   - 'shared needs an INPUT port, 'exclusive an OUTPUT port.
;;;
;;; ⚠ Only runners that contain this code take part. A checkout whose runner
;;; predates it neither waits nor is waited for.
;;;
;;; ⚠ MEASURED LIMITATION (DEFERRED 166): a runner's batch workers do NOT hold
;;; the lock. If the runner is SIGKILLed, the OS frees the lock at once while
;;; its orphaned workers finish their current unit (they exit at stdin EOF), so
;;; the next run can start against them: a bounded window, and only after a
;;; crash. Probe: racket-performance-probing skill, scripts/lock-probe.sh.

(require json
         racket/file
         racket/list
         racket/os
         racket/path
         racket/string)

(provide suite-lock-path
         default-suite-lock-path
         suite-lock-override-warning
         suite-lock-banner
         suite-lock-mode
         SUITE-SIZED-FILE-COUNT
         SUITE-LOCK-BUSY-EXIT
         (rename-out [suite-lock-handle? suite-lock?])
         suite-lock-handle-mode
         acquire-suite-lock!
         release-suite-lock!
         call-with-suite-lock
         suite-lock-holders
         format-holder
         make-wait-reporter)

;; Exit status of a run that found the lock busy under --no-wait: EX_TEMPFAIL
;; (sysexits.h) — "try again later". Distinct from every runner verdict
;; (0 pass, 1 failures, 2 incomplete, 3 re-run guard).
(define SUITE-LOCK-BUSY-EXIT 75)

;; A run of at least this many files is a suite whatever flag started it (the
;; same threshold historical-medians uses to tell a suite record from a
;; targeted one): it starts a worker per core, so it takes the lock exclusively.
(define SUITE-SIZED-FILE-COUNT 100)

(define (suite-lock-mode #:all? all? #:file-count n)
  (if (or all? (>= n SUITE-SIZED-FILE-COUNT)) 'exclusive 'shared))

;; ------------------------------------------------------------
;; Paths
;; ------------------------------------------------------------

(define (default-suite-lock-path)
  (define home (find-system-path 'home-dir))
  (define cache-root
    (case (system-type 'os)
      [(macosx) (build-path home "Library" "Caches")]
      [else (let ([x (getenv "XDG_CACHE_HOME")])
              (if (and x (not (string=? x "")))
                  (string->path x)
                  (build-path home ".cache")))]))
  (simplify-path (build-path cache-root "prologos" "suite.lock")))

(define (suite-lock-path)
  (define env (getenv "PROLOGOS_SUITE_LOCK"))
  (if (and env (not (string=? env "")))
      (simplify-path (path->complete-path (string->path env)))
      (default-suite-lock-path)))

;; DEFERRED 166 (SW-20). The override is legitimate (the tests use it) but it
;; takes a run OUT of the machine-wide queue, and an inherited value did that
;; silently once (a subagent's export reached the coordinator's shell). So every
;; caller prints suite-lock-banner when it takes the lock: the file it queues
;; on, and a ⚠ line whenever the env var moved it off the default.
;; suite-lock-override-warning : -> (or/c #f string?)
(define (suite-lock-override-warning)
  (define used (suite-lock-path))
  (define dflt (default-suite-lock-path))
  (and (not (equal? used dflt))
       (format "⚠ PROLOGOS_SUITE_LOCK=~a takes this run OUT of the machine-wide suite queue (~a): it waits only for runs that use the same file, and runs in the real queue do not wait for it. Unset it unless that is what you meant (the tests set it on purpose)."
               (getenv "PROLOGOS_SUITE_LOCK") (path->string dflt))))

;; suite-lock-banner : mode path -> (listof string)
(define (suite-lock-banner mode path)
  (define w (suite-lock-override-warning))
  (cons (format "Suite lock: ~a on ~a" mode (path->string path))
        (if w (list w) '())))

(define (sibling p suffix) (string->path (string-append (path->string p) suffix)))
(define (intent-path p) (sibling p ".intent"))
(define (info-dir p) (sibling p ".d"))

(define (ensure-file! p)
  (make-directory* (path-only p))
  (close-output-port (open-output-file p #:exists 'append)))

;; ------------------------------------------------------------
;; OS lock primitives
;; ------------------------------------------------------------

(define (close-any! port)
  (with-handlers ([exn:fail? void])
    (if (input-port? port) (close-input-port port) (close-output-port port))))

;; The locked port, or #f (nothing left open).
(define (try-lock p mode)
  (define port (if (eq? mode 'shared)
                   (open-input-file p)
                   (open-output-file p #:exists 'append)))
  (cond
    [(port-try-file-lock? port mode) port]
    [else (close-any! port) #f]))

(define (unlock! port)
  (when port
    (with-handlers ([exn:fail? void]) (port-file-unlock port))
    (close-any! port)))

;; ------------------------------------------------------------
;; Info files
;; ------------------------------------------------------------

(define info-counter 0)  ; several takers in one process (the tests) need distinct files

(define (write-info! port h)
  (file-truncate port 0)
  (file-position port 0)
  (write-json h port)
  (newline port)
  (flush-output port))

;; Created under a temporary name, locked, written, THEN renamed into view: a
;; reader can never see an info file that is not yet locked and mistake it for
;; a dead taker's leftover. (The lock belongs to the open file, so it survives
;; the rename.)
(define (create-info! lock-path h)
  (define dir (info-dir lock-path))
  (make-directory* dir)
  (set! info-counter (add1 info-counter))
  (define id (format "~a-~a" (getpid) info-counter))
  (define tmp (build-path dir (string-append id ".tmp")))
  (define final (build-path dir (string-append id ".json")))
  (define port (open-output-file tmp #:exists 'truncate))
  (unless (port-try-file-lock? port 'exclusive)
    (close-any! port)
    (error 'suite-lock "cannot lock a fresh info file: ~a" tmp))
  (define h* (hash-set h 'id id))
  (write-info! port h*)
  (rename-file-or-directory tmp final #t)
  (values port final h*))

(define (state-rank h)
  (if (equal? (hash-ref h 'state #f) "holding") 0 1))

;; suite-lock-holders : [path] -> (listof hash)
;; Live takers, holders first, then waiters, each oldest first. A file whose
;; lock is free belongs to a taker that is gone; it is deleted, not listed.
(define (suite-lock-holders [lock-path (suite-lock-path)])
  (define dir (info-dir lock-path))
  (define entries
    (if (directory-exists? dir)
        (for*/list ([name (in-list (directory-list dir))]
                    #:when (regexp-match? #rx"[.]json$" (path->string name))
                    [h (in-value (read-live-info (build-path dir name)))]
                    #:when h)
          h)
        '()))
  (sort (sort entries < #:key (lambda (h) (let ([s (hash-ref h 'started 0)]) (if (real? s) s 0))))
        < #:key state-rank))

(define (read-live-info f)
  (define in (with-handlers ([exn:fail? (lambda (e) #f)]) (open-input-file f)))
  (cond
    [(not in) #f]
    [(port-try-file-lock? in 'shared)
     ;; nobody holds it: the taker exited, crashed or was killed
     (unlock! in)
     (with-handlers ([exn:fail? void]) (delete-file f))
     #f]
    [else
     (define h (with-handlers ([exn:fail? (lambda (e) #f)]) (read-json in)))
     (close-any! in)
     (if (hash? h)
         h
         ;; being rewritten this instant; the name still says whose it is
         (hasheq 'id (path->string (path-replace-extension (file-name-from-path f) #""))
                 'state "unknown"))]))

;; ------------------------------------------------------------
;; Acquire / release
;; ------------------------------------------------------------

(struct suite-lock-handle (path mode [main #:mutable] [info-port #:mutable] [info-path #:mutable]))

;; acquire-suite-lock! : mode -> (or/c suite-lock? #f)
;; #:wait? #f tries once and returns #f when busy (leaving nothing behind).
;; Otherwise polls every #:poll-secs, calling (on-wait holders waited-secs)
;; on each poll with the OTHER live takers.
(define (acquire-suite-lock! mode
                             #:path [lock-path (suite-lock-path)]
                             #:wait? [wait? #t]
                             #:poll-secs [poll 1.0]
                             #:checkout [checkout (path->string (current-directory))]
                             #:command [command ""]
                             #:on-wait [on-wait void])
  (unless (memq mode '(shared exclusive))
    (raise-argument-error 'acquire-suite-lock! "(or/c 'shared 'exclusive)" mode))
  (ensure-file! lock-path)
  (ensure-file! (intent-path lock-path))
  (void (suite-lock-holders lock-path))  ; sweeps dead takers' leftover info files
  (define base
    (hasheq 'pid (getpid) 'mode (symbol->string mode) 'state "waiting"
            'checkout checkout 'command command 'started (current-seconds)))
  (define-values (iport ipath info) (create-info! lock-path base))
  (define t0 (current-inexact-milliseconds))
  (define (others)
    (filter (lambda (h) (not (equal? (hash-ref h 'id #f) (hash-ref info 'id))))
            (suite-lock-holders lock-path)))
  (define (pause!)
    (on-wait (others) (/ (- (current-inexact-milliseconds) t0) 1000.0))
    (sleep poll))
  (define (give-up!)
    (with-handlers ([exn:fail? void]) (delete-file ipath))
    (unlock! iport)
    #f)
  (let through-turnstile ()
    (define turnstile (try-lock (intent-path lock-path) 'exclusive))
    (cond
      [turnstile
       ;; Holding the turnstile while we wait for the lock is the writer
       ;; preference: new takers queue behind us, not beside us.
       (let wait-for-lock ()
         (define main (try-lock lock-path mode))
         (cond
           [main
            (unlock! turnstile)
            (write-info! iport (hash-set* info 'state "holding" 'acquired (current-seconds)))
            (suite-lock-handle lock-path mode main iport ipath)]
           [(not wait?) (unlock! turnstile) (give-up!)]
           [else (pause!) (wait-for-lock)]))]
      [(not wait?) (give-up!)]
      [else (pause!) (through-turnstile)])))

;; Idempotent. The OS would release the lock at exit anyway; this also
;; removes the info file so waiters stop listing us.
(define (release-suite-lock! h)
  (when (suite-lock-handle-main h)
    (unlock! (suite-lock-handle-main h))
    (set-suite-lock-handle-main! h #f))
  (when (suite-lock-handle-info-port h)
    (with-handlers ([exn:fail? void]) (delete-file (suite-lock-handle-info-path h)))
    (unlock! (suite-lock-handle-info-port h))
    (set-suite-lock-handle-info-port! h #f)))

;; call-with-suite-lock : mode thunk -> any
;; Runs thunk holding the lock and releases it on EVERY way out: normal return,
;; exception, and `(exit n)` from inside the thunk (the runner exits from deep
;; inside run-tests). When busy under #:wait? #f, calls (on-busy holders)
;; instead; the default prints nothing and exits SUITE-LOCK-BUSY-EXIT.
(define (call-with-suite-lock mode thunk
                              #:path [lock-path (suite-lock-path)]
                              #:wait? [wait? #t]
                              #:poll-secs [poll 1.0]
                              #:checkout [checkout (path->string (current-directory))]
                              #:command [command ""]
                              #:on-wait [on-wait void]
                              #:on-busy [on-busy (lambda (holders) (exit SUITE-LOCK-BUSY-EXIT))])
  (define h (acquire-suite-lock! mode #:path lock-path #:wait? wait? #:poll-secs poll
                                 #:checkout checkout #:command command #:on-wait on-wait))
  (cond
    [(not h) (on-busy (suite-lock-holders lock-path))]
    [else
     (define outer-exit (exit-handler))
     (dynamic-wind
      void
      (lambda ()
        (parameterize ([exit-handler (lambda (code)
                                       (release-suite-lock! h)
                                       (outer-exit code))])
          (thunk)))
      (lambda () (release-suite-lock! h)))]))

;; ------------------------------------------------------------
;; Reporting
;; ------------------------------------------------------------

(define (hms secs)
  (define s (max 0 (inexact->exact (round secs))))
  (cond [(>= s 3600) (format "~ah~am" (quotient s 3600) (quotient (remainder s 3600) 60))]
        [(>= s 60) (format "~am~as" (quotient s 60) (remainder s 60))]
        [else (format "~as" s)]))

(define (clock-time secs)
  (define d (seconds->date secs #t))
  (define (2d n) (if (< n 10) (format "0~a" n) (number->string n)))
  (format "~a:~a:~a" (2d (date-hour d)) (2d (date-minute d)) (2d (date-second d))))

;; One line per taker: pid, mode, state, since when, checkout, command.
(define (format-holder h)
  (define started (hash-ref h 'started #f))
  (define since (if (exact-integer? started)
                    (format "since ~a (~a)" (clock-time started) (hms (- (current-seconds) started)))
                    "since ?"))
  (format "pid ~a  ~a  ~a  ~a  ~a  ~a"
          (hash-ref h 'pid "?") (hash-ref h 'mode "?") (hash-ref h 'state "?") since
          (hash-ref h 'checkout "?") (hash-ref h 'command "")))

;; An on-wait callback that prints when the set of takers changes, and at
;; least every `every` seconds otherwise.
(define (make-wait-reporter mode lock-path #:out [out (current-output-port)] #:every [every 60])
  (define last-key 'none)
  (define last-print -inf.0)
  (lambda (holders waited)
    (define key (for/list ([h (in-list holders)]) (list (hash-ref h 'id #f) (hash-ref h 'state #f))))
    (when (or (not (equal? key last-key)) (>= (- waited last-print) every))
      (set! last-key key)
      (set! last-print waited)
      (fprintf out "⏳ suite lock busy — waiting ~a for ~a access (~a)\n"
               (hms waited) mode (path->string lock-path))
      (if (null? holders)
          (fprintf out "     (no info file: the holder predates suite-lock.rkt or is starting up)\n")
          (for ([h (in-list holders)])
            (fprintf out "     ~a\n" (format-holder h))))
      (flush-output out))))
