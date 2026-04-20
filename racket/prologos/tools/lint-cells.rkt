#lang racket/base

;;;
;;; lint-cells.rkt — PPN Track 4C Phase 1a baseline tool
;;;
;;; Purpose: baseline the merge-function surface across production
;;; `net-new-cell[-variant]` call sites, so Phase 1b's Tier 2
;;; registration (`register-merge-fn!/lattice`) has a concrete
;;; target list and can regression-gate against new additions.
;;;
;;; Classification per site:
;;;   - registered       : merge fn is named in a `register-merge-fn!/lattice`
;;;                        call somewhere in the codebase (Phase 1b+ only)
;;;   - unregistered     : named merge fn, no registration yet
;;;   - inline-lambda    : `(lambda ...)` appears at call site (Phase 1d target:
;;;                        rename to a registered function)
;;;   - parameterized-passthrough   : merge fn identifier at call site is a
;;;                        local binding or parameter carrying a merge fn
;;;                        (e.g., `merge`, `merge-fn`). These sites are
;;;                        ARCHITECTURALLY CORRECT — runtime Tier 3
;;;                        inheritance resolves the actual merge fn's domain
;;;                        via lookup-merge-fn-domain. Forcing #:domain
;;;                        override would BREAK inheritance. D3 resolution
;;;                        2026-04-19: leave as-is; the "ambiguous" framing
;;;                        from earlier D.2 drafts was misleading.
;;;   - multi-line       : can't parse merge fn from single-line grep; review
;;;                        manually (rare; typically when initial-value is long)
;;;   - domain-override  : site uses explicit `#:domain` keyword (should stay
;;;                        rare; each override should be justified)
;;;
;;; Scope — four cell-creation variants treated uniformly:
;;;   net-new-cell, net-new-cell-desc, net-new-cell-widen, net-new-cells-batch
;;;
;;; Exit code: 0 by default. --strict → 1 if NEW unregistered sites appear
;;; beyond the baseline. Baseline shrinks as Phase 1b/d/e land registrations.
;;;
;;; Architectural direction: PM Track 12 consolidates off-network registries.
;;; This lint tracks 4C's Tier 2 registration progress; retires when the
;;; Tier 2 registry is migrated to a cell.
;;;
;;; Usage:
;;;   racket tools/lint-cells.rkt                  # report, exit 0
;;;   racket tools/lint-cells.rkt --strict         # exit 1 on NEW unregistered
;;;   racket tools/lint-cells.rkt --verbose        # also list registered sites
;;;   racket tools/lint-cells.rkt --save-baseline  # accept current state
;;;

(require racket/cmdline
         racket/file
         racket/path
         racket/string
         racket/list)

;; ============================================================
;; Configuration
;; ============================================================

(define strict-mode? (make-parameter #f))
(define verbose-mode? (make-parameter #f))
(define save-baseline? (make-parameter #f))

(define this-file (path->string (simplify-path (syntax-source #'here))))
(define tools-dir (path-only this-file))
(define project-root (simplify-path (build-path tools-dir 'up)))

(define baseline-path
  (build-path tools-dir "cell-lint-baseline.txt"))

;; Ambiguous names: surface these for manual disambiguation rather
;; than counting them as merge functions. A local binding named
;; `merge` or a parameter `merge-fn` may NOT be a registerable
;; function.
(define parameterized-passthroughs (list "merge" "merge-fn"))

;; ============================================================
;; Source scanning
;; ============================================================

;; Variants of net-new-cell we recognize as sites requiring Tier 2 classification.
(define cell-variants
  '("net-new-cell"
    "net-new-cell-desc"
    "net-new-cell-widen"
    "net-new-cells-batch"))

;; Is this a call to a cell-creation variant? Return the variant name or #f.
(define (cell-call-variant? line)
  (for/or ([v (in-list cell-variants)])
    (define pattern (pregexp (string-append "\\(" (regexp-quote v) "[\\s\\)]")))
    (and (regexp-match? pattern line) v)))

;; Extract merge function from a single-line call.
;; For net-new-cell / -desc / -widen: 3rd positional arg after the paren.
;; For net-new-cells-batch: can't be parsed (specs list); flag as multi-line.
;;
;; Returns one of:
;;   (list 'named name)         — named merge function
;;   (list 'lambda)              — inline lambda
;;   (list 'domain-override)     — site uses #:domain keyword
;;   (list 'multi-line)          — can't parse from this line
;;   (list 'parameterized-passthrough name)      — named but name is parameterized-passthrough
(define (extract-merge-fn line variant)
  (cond
    ;; batch: can't classify from single line
    [(string=? variant "net-new-cells-batch")
     '(multi-line)]
    ;; #:domain present anywhere on line → override
    [(regexp-match? #px"#:domain\\s" line)
     '(domain-override)]
    ;; inline lambda at call site
    [(regexp-match? #px"\\(lambda\\s|\\(λ\\s" line)
     '(lambda)]
    [else
     ;; Match: (VARIANT ARG1 ARG2 ARG3 ...) — extract ARG3
     ;; ARG3 is a bare identifier (named merge fn)
     (define pattern
       (pregexp
        (string-append "\\(" (regexp-quote variant)
                       "\\s+[^\\s]+\\s+[^\\s]+\\s+([a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*)")))
     (define m (regexp-match pattern line))
     (cond
       [(not m) '(multi-line)]
       [(member (cadr m) parameterized-passthroughs)
        (list 'parameterized-passthrough (cadr m))]
       [else
        (list 'named (cadr m))])]))

;; Scan a file for all cell-creation call sites.
;; Returns (listof (list line-num variant classification)).
(define (scan-file file-path)
  (define content (file->string file-path))
  (define lines (string-split content "\n" #:trim? #f))
  (for/list ([line (in-list lines)]
             [line-num (in-naturals 1)]
             #:when (cell-call-variant? line)
             ;; skip comments (naive: line starts with optional whitespace + ;)
             #:unless (regexp-match? #px"^\\s*;" line)
             ;; skip struct definitions and function signatures
             #:unless (regexp-match? #px"^\\(struct\\s|^\\(define\\s+\\(net-new-cell" line))
    (define variant (cell-call-variant? line))
    (define classification (extract-merge-fn line variant))
    (list line-num variant classification)))

;; Find merge functions that are already registered.
;; Two registration patterns detected:
;;   (a) (register-merge-fn!/lattice NAME #:for-domain DOMAIN) — literal
;;   (b) (register/minimal 'DOMAIN NAME ...) — helper in phase1d-registrations.rkt
;;       which internally calls register-merge-fn!/lattice. The helper shape
;;       hides the NAME from the literal regex, so we match the helper form
;;       too. If more helper shapes emerge, add them here.
;; Returns a hash from merge-fn-name to #t.
(define (find-registered-merge-fns source-files)
  (define registered (make-hash))
  (define (collect-matches! pattern content)
    (define matches
      (regexp-match* pattern content #:match-select cadr))
    (for ([m (in-list matches)])
      (hash-set! registered m #t)))
  (for ([f (in-list source-files)])
    (define content (file->string f))
    ;; Pattern (a): literal register-merge-fn!/lattice call.
    (collect-matches!
     #px"\\(register-merge-fn!/lattice\\s+([a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*)"
     content)
    ;; Pattern (b): register/minimal helper (3rd positional arg is the fn name).
    (collect-matches!
     #px"\\(register/minimal\\s+'[a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*\\s+([a-zA-Z][a-zA-Z0-9!?*/<>+=:-]*)"
     content))
  registered)


;; ============================================================
;; Baseline I/O
;; ============================================================

(define (read-baseline)
  (cond
    [(file-exists? baseline-path)
     (define lines (string-split (file->string baseline-path) "\n"))
     (for/hash ([line (in-list lines)]
                #:when (and (not (string=? line ""))
                            (not (regexp-match? #px"^\\s*#" line))))
       (values (string-trim line) #t))]
    [else (hash)]))

(define (write-baseline unregistered-names)
  (define names (sort (hash-keys unregistered-names) string<?))
  (with-output-to-file baseline-path #:exists 'replace
    (lambda ()
      (displayln "# cell-lint-baseline.txt")
      (displayln "# Accepted unregistered merge functions as of last baseline save.")
      (displayln "# New additions (unregistered AND not in this list) are flagged.")
      (displayln "# Shrinks over time as Phase 1b/d/e registrations land")
      (displayln "# (PPN Track 4C Tier 2 `register-merge-fn!/lattice`).")
      (displayln "# Regenerate with: racket tools/lint-cells.rkt --save-baseline")
      (displayln "")
      (for ([n (in-list names)]) (displayln n)))))

;; ============================================================
;; Main
;; ============================================================

(define (main)
  (command-line
   #:program "lint-cells"
   #:once-each
   ["--strict" "Exit non-zero if NEW unregistered sites appear beyond baseline"
    (strict-mode? #t)]
   ["--verbose" "Also list registered + parameterized-passthrough + override sites with locations"
    (verbose-mode? #t)]
   ["--save-baseline" "Regenerate the baseline from current unregistered set"
    (save-baseline? #t)])

  ;; Collect production .rkt files (exclude tests, tools, benchmarks, compiled, examples)
  (define source-files
    (for/list ([f (in-directory project-root)]
               #:when (and (regexp-match? #rx"\\.rkt$" (path->string f))
                           (not (regexp-match? #rx"/tests/" (path->string f)))
                           (not (regexp-match? #rx"/tools/" (path->string f)))
                           (not (regexp-match? #rx"/compiled/" (path->string f)))
                           (not (regexp-match? #rx"/benchmarks/" (path->string f)))
                           (not (regexp-match? #rx"/examples/" (path->string f)))))
      f))

  (define registered-fns (find-registered-merge-fns source-files))
  (define baseline (read-baseline))

  ;; Classify every site
  (define registered-sites '())
  (define unregistered-sites '())
  (define lambda-sites '())
  (define parameterized-passthrough-sites '())
  (define override-sites '())
  (define multi-line-sites '())

  (for ([f (in-list source-files)])
    (define rel-path (path->string (find-relative-path project-root f)))
    (define sites (scan-file f))
    (for ([site (in-list sites)])
      (define line-num (car site))
      (define variant (cadr site))
      (define cls (caddr site))
      (define location (list rel-path line-num variant))
      (case (car cls)
        [(named)
         (define name (cadr cls))
         (if (hash-ref registered-fns name #f)
             (set! registered-sites (cons (cons name location) registered-sites))
             (set! unregistered-sites (cons (cons name location) unregistered-sites)))]
        [(lambda)
         (set! lambda-sites (cons location lambda-sites))]
        [(parameterized-passthrough)
         (set! parameterized-passthrough-sites (cons (cons (cadr cls) location) parameterized-passthrough-sites))]
        [(domain-override)
         (set! override-sites (cons location override-sites))]
        [(multi-line)
         (set! multi-line-sites (cons location multi-line-sites))])))

  ;; Unique unregistered names (for baseline)
  (define unregistered-name-set
    (for/hash ([entry (in-list unregistered-sites)])
      (values (car entry) #t)))

  ;; Save baseline and exit if requested
  (when (save-baseline?)
    (write-baseline unregistered-name-set)
    (printf "Baseline saved: ~a unique unregistered merge functions recorded.\n"
            (hash-count unregistered-name-set))
    (printf "File: ~a\n" (path->string baseline-path))
    (exit 0))

  ;; Split unregistered by baseline membership
  (define new-unregistered
    (filter (lambda (entry) (not (hash-ref baseline (car entry) #f)))
            unregistered-sites))
  (define new-unregistered-names
    (for/hash ([e (in-list new-unregistered)])
      (values (car e) #t)))

  ;; Totals
  (define total-sites (+ (length registered-sites)
                         (length unregistered-sites)
                         (length lambda-sites)
                         (length parameterized-passthrough-sites)
                         (length override-sites)
                         (length multi-line-sites)))

  ;; Report
  (printf "Cell-creation site classification (~a production sites, ~a files scanned):\n"
          total-sites (length source-files))
  (printf "  registered      : ~a\n" (length registered-sites))
  (printf "  unregistered    : ~a sites, ~a unique merge fns\n"
          (length unregistered-sites)
          (hash-count unregistered-name-set))
  (printf "    baseline-accepted: ~a\n"
          (- (length unregistered-sites) (length new-unregistered)))
  (printf "    NEW (not in baseline): ~a sites, ~a unique\n"
          (length new-unregistered)
          (hash-count new-unregistered-names))
  (printf "  inline-lambda   : ~a (Phase 1d: rename to registered fn)\n"
          (length lambda-sites))
  (printf "  parameterized-passthrough  : ~a (manual review: ~a)\n"
          (length parameterized-passthrough-sites)
          (string-join parameterized-passthroughs ", "))
  (printf "  domain-override : ~a (each should be justified)\n"
          (length override-sites))
  (printf "  multi-line      : ~a (manual review — can't parse from line)\n"
          (length multi-line-sites))

  (when (verbose-mode?)
    (when (pair? registered-sites)
      (printf "\nRegistered sites:\n")
      (for ([entry (in-list (sort registered-sites string<? #:key car))])
        (printf "  ~a (~a:~a ~a)\n"
                (car entry) (cadr entry) (caddr entry) (cadddr entry))))
    (when (pair? parameterized-passthrough-sites)
      (printf "\nAmbiguous-name sites:\n")
      (for ([entry (in-list (sort parameterized-passthrough-sites string<? #:key car))])
        (printf "  ~a (~a:~a ~a)\n"
                (car entry) (cadr entry) (caddr entry) (cadddr entry))))
    (when (pair? override-sites)
      (printf "\nDomain-override sites:\n")
      (for ([entry (in-list (sort override-sites string<? #:key car))])
        (printf "  (~a:~a ~a)\n" (car entry) (cadr entry) (caddr entry))))
    (when (pair? multi-line-sites)
      (printf "\nMulti-line sites (manual review):\n")
      (for ([entry (in-list (sort multi-line-sites string<? #:key car))])
        (printf "  (~a:~a ~a)\n" (car entry) (cadr entry) (caddr entry))))
    (when (pair? lambda-sites)
      (printf "\nInline-lambda sites:\n")
      (for ([entry (in-list (sort lambda-sites string<? #:key car))])
        (printf "  (~a:~a ~a)\n" (car entry) (cadr entry) (caddr entry)))))

  (when (pair? new-unregistered)
    (printf "\n⚠ NEW unregistered merge functions (not in baseline):\n")
    (define new-by-name
      (for/fold ([h (hash)]) ([entry (in-list new-unregistered)])
        (define name (car entry))
        (hash-update h name (lambda (lst) (cons (cdr entry) lst)) '())))
    (for ([name (in-list (sort (hash-keys new-by-name) string<?))])
      (define sites (hash-ref new-by-name name))
      (printf "  ~a (~a sites)\n" name (length sites))
      (for ([site (in-list sites)])
        (printf "      ~a:~a ~a\n" (car site) (cadr site) (caddr site))))
    (printf "\nResolution options:\n")
    (printf "  1. Register via `register-merge-fn!/lattice` (Phase 1b+ Tier 2 API)\n")
    (printf "  2. Add #:domain override at the call site (rare; each justified)\n")
    (printf "  3. Accept as baseline: racket tools/lint-cells.rkt --save-baseline\n"))

  (cond
    [(and (strict-mode?) (pair? new-unregistered))
     (exit 1)]
    [else
     (exit 0)]))

(main)
