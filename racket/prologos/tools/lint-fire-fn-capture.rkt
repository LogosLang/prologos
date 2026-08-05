#lang racket/base

;;;
;;; lint-fire-fn-capture.rkt — fire functions must not capture stale networks
;;;
;;; Purpose: static guard for propagator-design.md § "Fire Function Network
;;; Parameter (CRITICAL)". A propagator's fire function MUST use its `net`
;;; parameter for ALL cell reads and writes. A fire function that reads or
;;; writes through a variable captured from the INSTALLATION-TIME scope
;;; operates on a stale network; BSP merges the returned stale network over
;;; the snapshot and silently loses other propagators' writes. The bug is
;;; silent — no error, no crash (Track 2 Bug #2; Track 2B Phase 1a).
;;;
;;; Detection: a "fire scope" is
;;;   (a) any lambda appearing inside the arguments of a propagator
;;;       installer call (net-add-propagator, net-add-fire-once-propagator,
;;;       net-add-broadcast-propagator, net-add-threshold,
;;;       elab-add-propagator), or
;;;   (b) any define / let-family binding whose NAME matches #px"fire"
;;;       (fire-fn, fire, make-*-fire-fn, ...).
;;; Within a fire scope, every cell-op call (net-cell-read, net-cell-write,
;;; elab-cell-read, elab-cell-write, ...) whose network argument is an
;;; identifier NOT bound anywhere inside that scope is flagged: the
;;; identifier necessarily comes from the enclosing (installation-time)
;;; scope.
;;;
;;; Binder collection is deliberately OVER-approximate (lambda formals,
;;; define/define-values, let family, named let, for family clauses, match
;;; family patterns): over-approximation can only produce false negatives,
;;; never false positives, so every flag is worth reading.
;;;
;;; Known limitation: a factory like
;;;   (define (make-fire net) (lambda (net2) (net-cell-write net ...)))
;;; captures the factory's own parameter — bound inside the scope, so not
;;; flagged, though it is the same hazard when the factory runs at install
;;; time. The lint catches the documented bug shape (capture from a
;;; sibling/outer installation binding), not every possible staleness.
;;;
;;; Usage:
;;;   racket tools/lint-fire-fn-capture.rkt              # scan production, exit 0
;;;   racket tools/lint-fire-fn-capture.rkt --strict     # exit 1 on NEW findings
;;;   racket tools/lint-fire-fn-capture.rkt --save-baseline
;;;   racket tools/lint-fire-fn-capture.rkt FILE.rkt ... # scan specific files
;;;

(require racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/string
         syntax/modread)

(define strict-mode? (make-parameter #f))
(define save-baseline? (make-parameter #f))

(define this-file (path->string (simplify-path (syntax-source #'here))))
(define tools-dir (path-only this-file))
(define project-root (simplify-path (build-path tools-dir 'up)))
(define baseline-path (build-path tools-dir "fire-fn-capture-baseline.txt"))

;; ============================================================
;; Configuration
;; ============================================================

(define installer-heads
  '(net-add-propagator
    net-add-fire-once-propagator
    net-add-broadcast-propagator
    net-add-threshold
    elab-add-propagator))

;; Cell ops whose FIRST argument is the network.
(define net-ops
  '(net-cell-read net-cell-read-raw net-cell-write net-cell-write-widen
    net-cell-reset net-cell-replace net-cell-direction
    net-cell-decomp-insert net-cell-decomp-lookup
    elab-cell-read elab-cell-write elab-cell-replace
    elab-cell-read-worldview elab-cell-read-or elab-cell-solved?))

(define fire-name-rx #px"fire")

;; ============================================================
;; Module reading + generic walks
;; ============================================================

(define (read-module-stx path)
  (with-module-reading-parameterization
    (lambda ()
      (call-with-input-file path
        (lambda (p)
          (port-count-lines! p)
          (read-syntax path p))))))

;; Walk a syntax object, calling (f stx datum) on every syntax pair node.
(define (walk-stx f stx)
  (let loop ([s stx])
    (define e (if (syntax? s) (syntax-e s) s))
    (when (pair? e)
      (when (syntax? s) (f s (syntax->datum s)))
      (let inner ([rest e])
        (cond
          [(pair? rest) (loop (car rest)) (inner (cdr rest))]
          [(syntax? rest) (loop rest)]
          [else (void)])))))

(define (walk-datum f form)
  (f form)
  (cond
    [(pair? form) (walk-datum f (car form)) (walk-datum f (cdr form))]
    [(vector? form) (for ([x (in-vector form)]) (walk-datum f x))]
    [else (void)]))

;; ============================================================
;; Binder collection (over-approximate)
;; ============================================================

;; Collect every symbol in a formals/pattern datum (skips keywords).
(define (collect-symbols! acc form)
  (walk-datum (lambda (f) (when (symbol? f) (hash-set! acc f #t))) form))

;; Collect ids bound anywhere within a scope's datum subtree.
(define (collect-binders form)
  (define acc (make-hasheq))
  (walk-datum
   (lambda (f)
     (when (and (pair? f) (symbol? (car f)))
       (define head (car f))
       (define rest (cdr f))
       (cond
         ;; (lambda formals body ...) / (λ ...)
         [(and (memq head '(lambda λ)) (pair? rest))
          (collect-symbols! acc (car rest))]
         ;; (case-lambda [formals body ...] ...)
         [(eq? head 'case-lambda)
          (for ([clause (in-list rest)] #:when (pair? clause))
            (collect-symbols! acc (car clause)))]
         ;; (define (name . args) ...) / (define name expr)
         [(and (memq head '(define define-values match-define match-define-values))
               (pair? rest))
          (collect-symbols! acc (car rest))]
         ;; let family: (let ([x e] ...) ...) / named let (let loop ([x e] ...) ...)
         [(and (memq head '(let let* letrec let-values let*-values letrec-values))
               (pair? rest))
          (cond
            [(symbol? (car rest))                     ;; named let
             (hash-set! acc (car rest) #t)
             (when (pair? (cdr rest))
               (for ([b (in-list (if (list? (cadr rest)) (cadr rest) '()))]
                     #:when (pair? b))
                 (collect-symbols! acc (car b))))]
            [(list? (car rest))
             (for ([b (in-list (car rest))] #:when (pair? b))
               (collect-symbols! acc (car b)))])]
         ;; for family: (for CLAUSES body ...) / (for/fold ACCUM CLAUSES body ...)
         [(regexp-match? #px"^for(\\*|/|$)" (symbol->string head))
          ;; over-approximate: harvest binding position of every clause-shaped
          ;; element in the first two argument positions
          (for ([arg (in-list (take rest (min 2 (length (filter (lambda (_) #t) rest)))))]
                #:when (list? arg))
            (for ([clause (in-list arg)] #:when (pair? clause))
              (collect-symbols! acc (car clause))))]
         ;; match family: harvest ALL symbols in clause patterns
         [(and (memq head '(match match* match-let match-let*)) (pair? rest))
          (for ([clause (in-list (cdr rest))] #:when (pair? clause))
            (collect-symbols! acc (car clause)))]
         [else (void)])))
   form)
  acc)

;; ============================================================
;; Fire-scope discovery
;; ============================================================

;; Returns a list of (cons stx datum) fire scopes found in the module.
(define (find-fire-scopes stx)
  (define scopes '())
  (walk-stx
   (lambda (s datum)
     (define head (and (pair? datum) (car datum)))
     (cond
       ;; installer call → every lambda within its arguments is a fire scope
       [(and (symbol? head) (memq head installer-heads))
        (walk-stx
         (lambda (inner-s inner-d)
           (when (and (pair? inner-d) (memq (car inner-d) '(lambda λ case-lambda)))
             (set! scopes (cons inner-s scopes))))
         s)]
       ;; (define fire-ish ...) / (define (fire-ish ...) ...) / let-binding
       [(and (memq head '(define define-values)) (pair? (cdr datum)))
        (define target (cadr datum))
        (define name (cond [(symbol? target) target]
                           [(and (pair? target) (symbol? (car target))) (car target)]
                           [else #f]))
        (when (and name (regexp-match? fire-name-rx (symbol->string name)))
          (set! scopes (cons s scopes)))]
       [(and (memq head '(let let* letrec)) (pair? (cdr datum))
             (list? (cadr datum)))
        (for ([b (in-list (cadr datum))])
          (when (and (pair? b) (symbol? (car b))
                     (regexp-match? fire-name-rx (symbol->string (car b))))
            (set! scopes (cons s scopes))))]
       [else (void)]))
   stx)
  scopes)

;; ============================================================
;; Violation check
;; ============================================================

;; A finding: (list file line op netvar)
(define (check-fire-scope scope-stx)
  (define binders (collect-binders (syntax->datum scope-stx)))
  (define findings '())
  (walk-stx
   (lambda (s datum)
     (when (and (pair? datum)
                (symbol? (car datum))
                (memq (car datum) net-ops)
                (pair? (cdr datum))
                (symbol? (cadr datum))
                (not (hash-ref binders (cadr datum) #f)))
       (set! findings
             (cons (list (syntax-line s) (car datum) (cadr datum)) findings))))
   scope-stx)
  findings)

(define (scan-file path)
  (define rel (path->string (find-relative-path project-root (simplify-path path))))
  (with-handlers ([exn:fail? (lambda (e)
                               (eprintf "SKIP ~a (read error: ~a)\n" rel (exn-message e))
                               '())])
    (define stx (read-module-stx path))
    (for*/list ([scope (in-list (remove-duplicates (find-fire-scopes stx) eq?))]
                [f (in-list (check-fire-scope scope))])
      (list rel (car f) (cadr f) (caddr f)))))

;; ============================================================
;; Baseline
;; ============================================================

;; Baseline key: file::op::var (line numbers drift; this is stable enough).
(define (finding-key f)
  (format "~a::~a::~a" (car f) (caddr f) (cadddr f)))

(define (read-baseline)
  (cond
    [(file-exists? baseline-path)
     (for/hash ([line (in-list (string-split (file->string baseline-path) "\n"))]
                #:when (and (not (string=? (string-trim line) ""))
                            (not (regexp-match? #px"^\\s*#" line))))
       (values (string-trim line) #t))]
    [else (hash)]))

(define (write-baseline findings)
  (define keys (sort (remove-duplicates (map finding-key findings)) string<?))
  (with-output-to-file baseline-path #:exists 'replace
    (lambda ()
      (displayln "# fire-fn-capture-baseline.txt")
      (displayln "# Accepted fire-scope captured-network findings as of last baseline")
      (displayln "# save (key: file::op::variable). Each entry should be audited: a")
      (displayln "# genuine capture is the silent stale-network bug of")
      (displayln "# propagator-design.md § Fire Function Network Parameter.")
      (displayln "# Regenerate with: racket tools/lint-fire-fn-capture.rkt --save-baseline")
      (displayln "")
      (for ([k (in-list keys)]) (displayln k)))))

;; ============================================================
;; Main
;; ============================================================

(define (production-files)
  (for/list ([f (in-directory project-root)]
             #:when (and (regexp-match? #rx"\\.rkt$" (path->string f))
                         (not (regexp-match? #rx"/(tests|tools|benchmarks|compiled|examples|lsp)/"
                                             (path->string f)))))
    f))

(define (main)
  (define explicit-files
    (command-line
     #:program "lint-fire-fn-capture"
     #:once-each
     ["--strict" "Exit non-zero if NEW findings appear (not in baseline)"
      (strict-mode? #t)]
     ["--save-baseline" "Regenerate the baseline from current findings"
      (save-baseline? #t)]
     #:args files
     files))

  (define targets
    (if (pair? explicit-files)
        (map (lambda (f) (simplify-path (path->complete-path f))) explicit-files)
        (production-files)))

  (define findings (append-map scan-file targets))
  (define baseline (read-baseline))

  (when (save-baseline?)
    (write-baseline findings)
    (printf "Baseline saved: ~a findings recorded.\n"
            (length (remove-duplicates (map finding-key findings))))
    (exit 0))

  (define new-findings
    (filter (lambda (f) (not (hash-ref baseline (finding-key f) #f))) findings))

  (printf "fire-fn capture check (~a files): ~a findings (baselined: ~a, NEW: ~a)\n"
          (length targets) (length findings)
          (- (length findings) (length new-findings)) (length new-findings))

  (when (pair? new-findings)
    (printf "\n⚠ NEW captured-network reads/writes inside fire scopes:\n")
    (for ([f (in-list (sort new-findings string<? #:key finding-key))])
      (printf "  ~a:~a — (~a ~a ...) uses '~a', not bound inside the fire scope\n"
              (car f) (cadr f) (caddr f) (cadddr f) (cadddr f)))
    (printf "\nA fire function must use its own `net` parameter for every cell read\n")
    (printf "and write. A captured installation-time network is STALE: BSP merges the\n")
    (printf "returned network and silently drops other propagators' writes.\n")
    (printf "See .claude/rules/propagator-design.md § Fire Function Network Parameter.\n"))

  (if (and (strict-mode?) (pair? new-findings))
      (exit 1)
      (exit 0)))

(main)
