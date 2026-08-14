#lang racket/base
;;; corpus-ab.rkt — the CORPUS A/B runner. Use this instead of hand-rolling one.
;;;
;;;   racket tools/corpus-ab.rkt --base <TREE> [--head <TREE>] [options] FILE ...
;;;
;;; WHY THIS EXISTS (CIU T6 D4.P4c-4c, 2026-08-05). Two hand-rolled A/B harnesses
;;; written by audit agents reached **9.7 GB and 9.0 GB** and ran for 17 minutes
;;; before the owner spotted them. The defect was not in the compiler — measured,
;;; memory across repeated `process-file` calls is FLAT (134 MB over six files
;;; including repeats). The defect was the HARNESS SHAPE: it looped over an entire
;;; corpus inside ONE long-lived process, accumulating every file's result list.
;;;
;;; The fix is structural rather than advisory: fork a SUBPROCESS PER FILE, so the
;;; OS reclaims each file's memory unconditionally, and cap every child in both
;;; dimensions that can run away — wall time and memory. A harness that cannot
;;; hold two files' results at once cannot leak across a corpus.
;;;
;;; IT ALSO ENCODES THE A/B METHOD, which is easy to get wrong and was wrong once
;;; in this very track (D4 `#p4c-4c`, corrected the same day):
;;;
;;;   · the CODE is pinned per leg (two trees) — that is what you are comparing;
;;;   · the INPUTS come from the WORKING TREE by default, NOT from a snapshot.
;;;     Snapshotting the inputs too is the trap: the only broadcast-bearing corpus
;;;     file was owner WIP (114 lines committed vs 946 live), so a snapshot-input
;;;     A/B compared a corpus that did not contain the feature and reported ZERO
;;;     diffs across 304 files — a total false all-clear. Use --snapshot-inputs
;;;     only when you have checked that the inputs you care about are committed.
;;;   · diff FULL OUTPUT, never error counts (a whole-file abort produces no
;;;     results, which a count-based gate reads as "no errors");
;;;   · normalize the AMBIENT lines (timings, memory, generated-name counters) or
;;;     every file "differs";
;;;   · carry a CONTROL file that cannot possibly be affected. Without one you
;;;     cannot tell a real diff from ambient drift — on the run this tool was
;;;     written for, the control is what revealed that all six "diffs" were
;;;     PHASE-TIMINGS noise, and then that the counter normalizer was incomplete.

(require racket/cmdline racket/system racket/port racket/string
         racket/file racket/list racket/path)

;; ⚠ NO ABSOLUTE PATHS. `--head` defaulted to a hardcoded `/Users/…` checkout,
;; which silently pointed at the wrong tree the moment the project moved (it did,
;; 2026-08-13) and was never right on another machine. Anchor from THIS SCRIPT's
;; own module path instead — the canonical house idiom (`run-affected-tests.rkt`
;; § project-root) — because it is CWD-INDEPENDENT, unlike the walk-up-from-CWD
;; variants elsewhere in tools/. This file lives at racket/prologos/tools/, so the
;; repo root is three levels up, and `head-tree` IS the repo root (it is used as
;; `<tree>/racket/prologos/tools/run-file.rkt` at run-one/subprocess).
(define this-repo-root
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (path->string
     (simplify-path (build-path (path-only src) 'up 'up 'up)))))

(define base-tree   (make-parameter #f))
(define head-tree   (make-parameter this-repo-root))
(define out-dir     (make-parameter #f))
(define per-file-timeout (make-parameter 120))     ; seconds
(define per-file-memory  (make-parameter 2048))    ; MB — a single file needs ~150
(define snapshot-inputs? (make-parameter #f))
(define keep-going?      (make-parameter #t))

(define files
  (command-line
   #:program "corpus-ab"
   #:once-each
   [("--base") tree "Baseline tree (its tools/run-file.rkt is used for leg A)"
    (base-tree tree)]
   [("--head") tree "Head tree (default: this script's own repo root)"
    (head-tree tree)]
   [("--out") dir "Directory for per-file outputs (default: a temp dir)"
    (out-dir dir)]
   [("--timeout") s "Per-file wall timeout in seconds (default 120)"
    (per-file-timeout (string->number s))]
   [("--memory") mb "Per-file memory cap in MB (default 2048)"
    (per-file-memory (string->number mb))]
   [("--snapshot-inputs") "Read inputs from the BASE tree too (see the header — usually WRONG)"
    (snapshot-inputs? #t)]
   #:args files files))

(unless (base-tree)
  (eprintf "corpus-ab: --base is required (a tree to compare against)\n") (exit 2))
(when (null? files)
  (eprintf "corpus-ab: no files given\n") (exit 2))

(define OUT (or (out-dir) (path->string (make-temporary-directory))))
(make-directory* OUT)

;; ---------------------------------------------------------------------------
;; THE AMBIENT NORMALIZER. These lines differ run-to-run and are not semantics.
;; Keep this ONE definition — a second copy in a caller's shell pipeline is how
;; the two legs drift (the counter normalizer was incomplete exactly once, and it
;; took a control file to notice).
;; ---------------------------------------------------------------------------
(define ambient-prefixes
  '("PHASE-TIMINGS:" "MEMORY-STATS:" "PERF-COUNTERS:"
    "CELL-METRICS:" "PROVENANCE-STATS:"))

(define (ambient-line? l)
  (for/or ([p (in-list ambient-prefixes)]) (string-prefix? l p)))

;; generated names carry a monotonic counter that depends on startup/tree state,
;; NOT on the change under test: ?meta2472, ?suc0_49386, …
(define (normalize-counters l)
  (regexp-replace* #rx"_[0-9][0-9][0-9]+" (regexp-replace* #rx"\\?meta[0-9]+" l "?metaN") "_N"))

(define (normalize txt)
  (string-join
   (for/list ([l (in-list (string-split txt "\n"))] #:unless (ambient-line? l))
     (normalize-counters l))
   "\n"))

;; ---------------------------------------------------------------------------
;; ONE FILE, ONE LEG, ONE SUBPROCESS — capped in BOTH dimensions.
;; Memory cap: inside the child (custodian). Wall cap: `timeout` from here.
;; Either breach is reported as a first-class OUTCOME, never as a pass and never
;; as a hang — a harness that silently hangs is how 17 minutes went unnoticed.
;; ---------------------------------------------------------------------------
;; ⚠ ONE runner, not two. The first cut of this file also carried a `run-one`
;; that capped memory via an in-process custodian and delegated with
;; `dynamic-require`. It was superseded by the subprocess form below (run-file.rkt
;; reads its OWN command line, so a subprocess is both simpler and the thing that
;; actually inherits argv) — and then deleted rather than kept, because shipping
;; two runners is the belt-and-suspenders shape this repo's rules block, and the
;; per-file SUBPROCESS is the entire point of the tool.

;; ⚠⚠ THE CHILD MUST BE **THIS** RACKET, NOT `find-executable-path "racket"`.
;; Measured on this machine: PATH resolves `racket` to /opt/homebrew/bin/racket,
;; while the project runs on /Applications/Racket v9.0 (CLAUDE.local.md says so
;; explicitly). A harness that shells out by name therefore A/Bs with a DIFFERENT
;; COMPILER than the one you invoked it with — silently, and the result looks
;; like a corpus finding. This is the same family as the documented
;; collection-path trap ("Two Compiler Instances"), reached by a new door.
;; `(find-system-path 'exec-file)` is the running executable, so the child is the
;; same Racket by construction rather than by PATH luck.
(define this-racket
  (let ([e (find-system-path 'exec-file)])
    (cond [(absolute-path? e) e]
          [(find-executable-path e) => values]
          [else (build-path (find-system-path 'orig-dir) e)])))

(define (run-one/subprocess tree src)
  (define runner (path->string (build-path tree "racket" "prologos" "tools" "run-file.rkt")))
  ;; ⚠ BOTH CAPS LIVE IN THE CHILD, and the external `timeout` binary is gone.
  ;; The first cut wrapped the child in `timeout N …`; GNU timeout signals a
  ;; process group, and the signal reached THIS process — every run died with
  ;; "user break" raised in the parent's own frame, before any file was read.
  ;; Doing both caps in-child removes the signal plumbing, removes a PATH
  ;; dependency, and makes the caps portable: a watchdog thread enforces wall
  ;; time, a custodian limit enforces memory, and the child exits with a distinct
  ;; code for each so a breach can never be mistaken for a pass.
  (define expr
    (format
     (string-append
      "(let ([c (make-custodian)])"
      "  (custodian-limit-memory c ~a c)"
      "  (parameterize ([current-custodian c]"
      "                 [current-command-line-arguments (vector ~s)])"
      "    (define done (make-semaphore 0))"
      "    (define worker (thread (lambda () (dynamic-require (string->path ~s) #f) (semaphore-post done))))"
      "    (unless (sync/timeout ~a done)"
      "      (eprintf \"CORPUS-AB: wall cap exceeded\\n\") (exit 124))))")
     (* (per-file-memory) 1024 1024) src runner (per-file-timeout)))
  (define outp (open-output-string))
  (define errp (open-output-string))
  (define-values (sp pout pin perr)
    (subprocess #f #f #f this-racket "-e" expr))
  (define t-out (thread (lambda () (copy-port pout outp))))
  (define t-err (thread (lambda () (copy-port perr errp))))
  (subprocess-wait sp)
  (thread-wait t-out) (thread-wait t-err)
  (close-input-port pout) (close-input-port perr) (close-output-port pin)
  (define txt (string-append (get-output-string outp) (get-output-string errp)))
  (define code (subprocess-status sp))
  (values (cond [(= code 124) 'timeout]
                [(regexp-match? #rx"out of memory|memory limit" txt) 'oom]
                [(zero? code) 'ok]
                [else 'error])
          txt))

(define (leg-name tree) (if (equal? tree (head-tree)) "head" "base"))

(printf "corpus-ab: ~a files · base=~a · head=~a\n" (length files) (base-tree) (head-tree))
(printf "           inputs from ~a · per-file cap ~as / ~aMB\n\n"
        (if (snapshot-inputs?) "the BASE TREE (⚠ see --snapshot-inputs)" "the WORKING TREE")
        (per-file-timeout) (per-file-memory))

(define results
  (for/list ([f (in-list files)])
    (define src-head f)
    (define src-base (if (snapshot-inputs?)
                         (path->string (build-path (base-tree) (find-relative-path
                                                                (head-tree) (path->complete-path f))))
                         f))
    (define-values (bc btxt) (run-one/subprocess (base-tree) src-base))
    (define-values (hc htxt) (run-one/subprocess (head-tree) src-head))
    (define tag (regexp-replace* #rx"/" f "_"))
    (call-with-output-file (build-path OUT (string-append tag ".base")) #:exists 'replace
      (lambda (p) (display btxt p)))
    (call-with-output-file (build-path OUT (string-append tag ".head")) #:exists 'replace
      (lambda (p) (display htxt p)))
    (define nb (normalize btxt)) (define nh (normalize htxt))
    (define outcome
      (cond [(memq bc '(timeout oom)) 'CAPPED]
            [(memq hc '(timeout oom)) 'CAPPED]
            [(string=? nb nh)         'IDENTICAL]
            [else                     'DIFFERS]))
    (printf "  ~a  ~a~a\n"
            (case outcome [(IDENTICAL) "IDENTICAL "] [(DIFFERS) "***DIFFERS"] [else "!!CAPPED "])
            f
            (if (eq? outcome 'DIFFERS)
                (format "  (~a differing lines)"
                        (let loop ([a (string-split nb "\n")] [b (string-split nh "\n")] [n 0])
                          (cond [(and (null? a) (null? b)) n]
                                [(null? a) (+ n (length b))]
                                [(null? b) (+ n (length a))]
                                [(string=? (car a) (car b)) (loop (cdr a) (cdr b) n)]
                                [else (loop (cdr a) (cdr b) (add1 n))])))
                ""))
    (list f outcome)))

(newline)
(define diffs (filter (lambda (r) (eq? (cadr r) 'DIFFERS)) results))
(define timeouts (filter (lambda (r) (eq? (cadr r) 'CAPPED)) results))
(printf "~a identical · ~a differing · ~a hit a cap\n"
        (- (length results) (length diffs) (length timeouts))
        (length diffs) (length timeouts))
(printf "outputs: ~a\n" OUT)
(when (pair? timeouts)
  (printf "\n⚠ A CAP BREACH IS NOT A PASS — investigate each before reading the diff summary.\n"))
(printf "\n⚠ Did you include a CONTROL file that CANNOT be affected by the change?\n")
(printf "  Without one you cannot distinguish a real diff from ambient drift.\n")
(exit (if (or (pair? diffs) (pair? timeouts)) 1 0))
