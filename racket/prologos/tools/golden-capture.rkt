#lang racket/base

;;;
;;; PPN Track 1 Phase 0: Golden Baseline Capture
;;;
;;; Captures 4 levels of reader output for all .prologos files:
;;; Level 1: Tree topology (line → indent level, parent line)
;;; Level 1b: Bracket groups (open position → close position)
;;; Level 2: Datum output (read-all-forms-string S-expressions)
;;; Level 3: Source locations (per-form srcloc)
;;;
;;; Output: data/golden/ directory with one .golden file per .prologos file
;;;

(require racket/file
         racket/path
         racket/string
         racket/list
         racket/port
         "../parse-reader.rkt")

(provide capture-golden-baseline
         capture-golden-for-file
         compare-golden-for-file)

;; ============================================================
;; Path resolution (CWD-independent)
;; ============================================================

(define here (path-only (syntax-source #'here)))
(define project-root (simplify-path (build-path here "..")))
(define golden-dir (build-path project-root "data" "golden"))

(define (golden-path-for source-path)
  (define rel (find-relative-path project-root source-path))
  (define golden-name (string-append (path->string rel) ".golden"))
  (build-path golden-dir golden-name))

;; ============================================================
;; Level 1: Tree topology (indent + parent structure)
;; ============================================================

(define (capture-tree-topology source-str)
  ;; Parse the indentation structure: for each content line,
  ;; record (line-number indent-level parent-line-number)
  (define lines (string-split source-str "\n"))
  (define content-lines '())
  (define stack '())  ;; list of (indent . line-idx)

  (for ([line (in-list lines)]
        [i (in-naturals)])
    (define trimmed (string-trim line))
    (when (and (> (string-length trimmed) 0)
               (not (string-prefix? trimmed ";")))
      ;; Content line — measure indent
      (define indent
        (let loop ([j 0])
          (if (and (< j (string-length line))
                   (char=? (string-ref line j) #\space))
              (loop (+ j 1))
              j)))
      ;; Pop stack until top < indent
      (set! stack
        (let loop ([s stack])
          (if (and (pair? s) (>= (car (car s)) indent))
              (loop (cdr s))
              s)))
      (define parent (if (null? stack) -1 (cdr (car stack))))
      (set! stack (cons (cons indent (length content-lines)) stack))
      (set! content-lines
        (cons (list (length content-lines) i indent parent) content-lines))))

  (reverse content-lines))

;; ============================================================
;; Level 1b: Bracket groups
;; ============================================================

(define (capture-bracket-groups source-str)
  ;; Tokenize and match brackets: record (open-idx . close-idx) pairs
  ;; Uses token INDEX (not position — token-pos not exported)
  (with-handlers ([exn? (lambda (e) (list (cons 'error (exn-message e))))])
    (define tokens (tokenize-string source-str))
    (define stack '())  ;; list of open-indices
    (define groups '())
    (for ([tok (in-list tokens)]
          [i (in-naturals)])
      (define tt (token-type tok))
      (when (memq tt '(lbracket lparen lbrace langle quote-lbracket))
        (set! stack (cons i stack)))
      (when (memq tt '(rbracket rparen rbrace rangle))
        (when (pair? stack)
          (set! groups (cons (cons (car stack) i) groups))
          (set! stack (cdr stack)))))
    (reverse groups)))

;; ============================================================
;; Level 2: Datum output
;; ============================================================

(define (capture-datum-output source-str)
  (with-handlers ([exn? (lambda (e) (list (cons 'error (exn-message e))))])
    (define forms (read-all-forms-string source-str))
    (map (lambda (f) (format "~s" f)) forms)))

;; ============================================================
;; Level 3: Source locations
;; ============================================================

(define (capture-source-locations source-str source-name)
  (with-handlers ([exn? (lambda (e) (list (cons 'error (exn-message e))))])
    (define port (open-input-string source-str))
    (define stxs (prologos-read-syntax-all source-name port))
    (for/list ([stx (in-list stxs)])
      (list (syntax-line stx)
            (syntax-column stx)
            (syntax-position stx)
            (syntax-span stx)))))

;; ============================================================
;; Capture all 4 levels for one file
;; ============================================================

(define (capture-golden-for-file source-path)
  (define source-str (file->string source-path))
  (define source-name (path->string (file-name-from-path source-path)))

  (list
   (cons 'file (path->string source-path))
   (cons 'topology (capture-tree-topology source-str))
   (cons 'brackets (capture-bracket-groups source-str))
   (cons 'datums (capture-datum-output source-str))
   (cons 'srclocs (capture-source-locations source-str source-name))))

;; ============================================================
;; Capture baselines for all .prologos files
;; ============================================================

(define (find-prologos-files)
  (define lib-dir (build-path project-root "lib" "prologos"))
  (define examples-dir (build-path project-root "examples"))
  (define (find-in dir)
    (if (directory-exists? dir)
        (for/list ([f (in-directory dir)]
                   #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
          f)
        '()))
  (append (find-in lib-dir) (find-in examples-dir)))

(define (capture-golden-baseline)
  (define files (find-prologos-files))
  (printf "Capturing golden baselines for ~a .prologos files...\n" (length files))

  ;; Ensure golden directory exists
  (make-directory* golden-dir)

  (define succeeded 0)
  (define failed 0)

  (for ([f (in-list files)])
    (define gpath (golden-path-for f))
    (make-directory* (path-only gpath))
    (with-handlers
      ([exn? (lambda (e)
               (set! failed (+ failed 1))
               (printf "  FAIL ~a: ~a\n"
                       (find-relative-path project-root f)
                       (substring (exn-message e)
                                  0 (min 80 (string-length (exn-message e))))))])
      (define golden (capture-golden-for-file f))
      (call-with-output-file gpath
        (lambda (out) (write golden out))
        #:exists 'replace)
      (set! succeeded (+ succeeded 1))))

  (printf "\nCaptured: ~a succeeded, ~a failed\n" succeeded failed)
  (printf "Golden files in: ~a\n" (path->string golden-dir)))

;; ============================================================
;; Compare new output against golden baseline
;; ============================================================

(define (compare-golden-for-file source-path)
  (define gpath (golden-path-for source-path))
  (unless (file-exists? gpath)
    (error 'compare-golden "No golden baseline for ~a" source-path))

  (define golden (call-with-input-file gpath read))
  (define current (capture-golden-for-file source-path))

  (define diffs '())

  ;; Compare each level
  (for ([level '(topology brackets datums srclocs)])
    (define gold-val (cdr (assq level golden)))
    (define curr-val (cdr (assq level current)))
    (unless (equal? gold-val curr-val)
      (set! diffs (cons level diffs))))

  (if (null? diffs)
      'pass
      (cons 'fail (reverse diffs))))

;; ============================================================
;; Main: run when executed directly
;; ============================================================

(module+ main
  (capture-golden-baseline))
