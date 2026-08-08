#lang racket/base

;;;
;;; lint-pnet-registration.rkt — AST nodes must be registered for .pnet caching
;;;
;;; Purpose: static guard for pipeline.md § "New AST Node" step 6. Every
;;; struct defined in syntax.rkt must be registered in pnet-serialize.rkt
;;; (reg0!/reg1!/reg2!/reg3!/regN!/auto-cache!/cache-ctor!) or it hits the
;;; .pnet reader's unknown-tag fallback, which silently returns a raw VECTOR
;;; impostor that fails the first struct `match` to touch it — arbitrarily
;;; far from the real cause, with an error that PRINTS like the real struct
;;; (Numerics Q11, 2026-07-01). The gap stays latent until the node first
;;; appears in — or is first INVOKED from — a cached module body, so a green
;;; suite is no defence.
;;;
;;; Detection: reads syntax.rkt for (struct NAME ...) definitions, reads
;;; pnet-serialize.rkt for every symbol appearing in CODE (comments are
;;; stripped by the reader, so a name mentioned only in a comment does NOT
;;; count as registered). A struct name absent from pnet-serialize.rkt's
;;; code cannot possibly be registered. The check is necessary-not-
;;; sufficient: a name may appear without being registered (e.g. in a
;;; helper) — but the common failure is the clean miss, and that is caught.
;;;
;;; Baseline: tools/pnet-registration-baseline.txt holds the pre-existing
;;; unregistered set (latent debt, tracked). Only NEW additions are flagged.
;;;
;;; Usage:
;;;   racket tools/lint-pnet-registration.rkt              # report, exit 0
;;;   racket tools/lint-pnet-registration.rkt --strict     # exit 1 on NEW gaps
;;;   racket tools/lint-pnet-registration.rkt --save-baseline
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

(define syntax-rkt (build-path project-root "syntax.rkt"))
(define pnet-serialize-rkt (build-path project-root "pnet-serialize.rkt"))
(define baseline-path (build-path tools-dir "pnet-registration-baseline.txt"))

;; ============================================================
;; Module reading
;; ============================================================

;; Read a #lang module file as one syntax object (comments stripped).
(define (read-module-stx path)
  (with-module-reading-parameterization
    (lambda ()
      (call-with-input-file path
        (lambda (p)
          (port-count-lines! p)
          (read-syntax path p))))))

;; Generic walk over a datum tree.
(define (walk-datum f form)
  (f form)
  (cond
    [(pair? form) (walk-datum f (car form)) (walk-datum f (cdr form))]
    [(vector? form) (for ([x (in-vector form)]) (walk-datum f x))]
    [else (void)]))

;; ============================================================
;; Struct definitions in syntax.rkt (with line numbers)
;; ============================================================

;; Recognize (struct NAME (field ...) opt ...) and
;; (struct NAME PARENT (field ...) opt ...) forms.
(define (struct-def-name form)
  (and (pair? form)
       (eq? (car form) 'struct)
       (pair? (cdr form))
       (symbol? (cadr form))
       (pair? (cddr form))
       (or (list? (caddr form))
           (and (symbol? (caddr form))
                (pair? (cdddr form))
                (list? (cadddr form))))
       (cadr form)))

;; Walk syntax objects (not datums) so we can report line numbers.
;; Returns (listof (cons name line)).
(define (collect-struct-defs stx)
  (define acc '())
  (let loop ([s stx])
    (define e (if (syntax? s) (syntax-e s) s))
    (when (pair? e)
      (define datum (if (syntax? s) (syntax->datum s) s))
      (define name (struct-def-name datum))
      (when name
        (set! acc (cons (cons name (and (syntax? s) (syntax-line s))) acc)))
      (let inner ([rest e])
        (cond
          [(pair? rest) (loop (car rest)) (inner (cdr rest))]
          [(syntax? rest) (loop rest)]
          [else (void)]))))
  (reverse acc))

;; ============================================================
;; Registered symbols in pnet-serialize.rkt
;; ============================================================

(define (collect-code-symbols path)
  (define syms (make-hasheq))
  (walk-datum (lambda (f) (when (symbol? f) (hash-set! syms f #t)))
              (syntax->datum (read-module-stx path)))
  syms)

;; ============================================================
;; Baseline
;; ============================================================

(define (read-baseline)
  (cond
    [(file-exists? baseline-path)
     (for/hash ([line (in-list (string-split (file->string baseline-path) "\n"))]
                #:when (and (not (string=? (string-trim line) ""))
                            (not (regexp-match? #px"^\\s*#" line))))
       (values (string-trim line) #t))]
    [else (hash)]))

(define (write-baseline names)
  (with-output-to-file baseline-path #:exists 'replace
    (lambda ()
      (displayln "# pnet-registration-baseline.txt")
      (displayln "# syntax.rkt structs NOT registered in pnet-serialize.rkt as of the")
      (displayln "# last baseline save — latent .pnet vector-impostor debt (see")
      (displayln "# pipeline.md § New AST Node step 6). New struct additions missing")
      (displayln "# registration are flagged; this list should only SHRINK as gaps")
      (displayln "# are registered.")
      (displayln "# Regenerate with: racket tools/lint-pnet-registration.rkt --save-baseline")
      (displayln "")
      (for ([n (in-list (sort names string<?))]) (displayln n)))))

;; ============================================================
;; Main
;; ============================================================

(define (main)
  (command-line
   #:program "lint-pnet-registration"
   #:once-each
   ["--strict" "Exit non-zero if NEW unregistered structs are found"
    (strict-mode? #t)]
   ["--save-baseline" "Regenerate the baseline from the current unregistered set"
    (save-baseline? #t)])

  (define struct-defs (collect-struct-defs (read-module-stx syntax-rkt)))
  (define registered (collect-code-symbols pnet-serialize-rkt))
  (define baseline (read-baseline))

  (define missing
    (for/list ([def (in-list struct-defs)]
               #:unless (hash-ref registered (car def) #f))
      def))
  (define missing-names (remove-duplicates (map (lambda (d) (symbol->string (car d))) missing)))

  (when (save-baseline?)
    (write-baseline missing-names)
    (printf "Baseline saved: ~a unregistered structs recorded.\n" (length missing-names))
    (printf "File: ~a\n" (path->string baseline-path))
    (exit 0))

  (define new-missing
    (filter (lambda (d) (not (hash-ref baseline (symbol->string (car d)) #f))) missing))
  (define baselined-count (- (length missing) (length new-missing)))

  (printf "pnet registration check (~a structs in syntax.rkt):\n" (length struct-defs))
  (printf "  registered (name appears in pnet-serialize.rkt code): ~a\n"
          (- (length struct-defs) (length missing)))
  (printf "  unregistered: ~a (baselined: ~a, NEW: ~a)\n"
          (length missing) baselined-count (length new-missing))

  (when (pair? new-missing)
    (printf "\n⚠ NEW unregistered structs (not in baseline):\n")
    (for ([d (in-list new-missing)])
      (printf "  ~a (syntax.rkt:~a)\n" (car d) (or (cdr d) "?")))
    (printf "\nEvery AST node needs a pnet-serialize.rkt registration (reg0!/reg1!/regN!\n")
    (printf "or the auto-cache! block) — otherwise cached module bodies deserialize the\n")
    (printf "node as a raw vector impostor that fails a distant struct match.\n")
    (printf "See .claude/rules/pipeline.md § New AST Node, step 6.\n"))

  (if (and (strict-mode?) (pair? new-missing))
      (exit 1)
      (exit 0)))

(main)
