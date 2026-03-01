#lang racket/base

;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; tangle-stdlib — extract compilation units from book chapters
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; Reads the OUTLINE manifest and chapter files from lib/prologos/book/,
;; splits each chapter at `module` directives, and emits one .prologos
;; file per module into the .tangled/ output directory.
;;
;; The tangler is pure text processing — it does NOT invoke the Prologos
;; parser. Module paths in the tangled output are identical to the current
;; file layout, preserving full backward compatibility.
;;
;; Usage:
;;   racket tools/tangle-stdlib.rkt [--book-dir DIR] [--output-dir DIR]
;;   racket tools/tangle-stdlib.rkt --verify   (diff tangled vs originals)

(require racket/file
         racket/string
         racket/path
         racket/list
         racket/match
         racket/format
         racket/system)

;; ========================================
;; OUTLINE reader
;; ========================================

;; Read OUTLINE file → list of chapter names (strings).
;; Blank lines and ;; comments are skipped.
(define (read-outline outline-path)
  (define lines (file->lines outline-path))
  (filter-map
   (lambda (line)
     (define stripped (string-trim line))
     (cond
       [(string=? stripped "") #f]
       [(string-prefix? stripped ";;") #f]
       [else stripped]))
   lines))

;; ========================================
;; Module directive parser
;; ========================================

;; Recognize a `module` directive line.
;; Returns (values module-name flags-string) or (values #f #f).
;;
;; Formats recognized:
;;   module prologos::core::eq-trait
;;   module prologos::core::algebraic-laws :no-prelude
(define (parse-module-line line)
  (define stripped (string-trim line))
  (define parts (string-split stripped))
  (cond
    [(and (pair? parts)
          (string=? (car parts) "module")
          (>= (length parts) 2))
     (values (cadr parts) (string-join (cddr parts) " "))]
    [else (values #f #f)]))

;; ========================================
;; Chapter splitter
;; ========================================

;; Split a chapter's lines at module directives.
;; Returns: list of (list module-name flags-string content-lines)
;; Content before the first module directive is discarded (chapter preamble).
(define (split-chapter-modules lines)
  (define modules '())
  (define current-name #f)
  (define current-flags "")
  (define current-lines '())

  (for ([line (in-list lines)])
    (define-values (mod-name mod-flags) (parse-module-line line))
    (cond
      [mod-name
       ;; Save previous module if any
       (when current-name
         (set! modules
               (cons (list current-name current-flags (reverse current-lines))
                     modules)))
       ;; Start new module
       (set! current-name mod-name)
       (set! current-flags (or mod-flags ""))
       (set! current-lines '())]
      [else
       ;; Accumulate line (only if we've seen a module directive)
       (when current-name
         (set! current-lines (cons line current-lines)))]))

  ;; Save final module
  (when current-name
    (set! modules
          (cons (list current-name current-flags (reverse current-lines))
                modules)))

  (reverse modules))

;; ========================================
;; Path conversion
;; ========================================

;; Convert module name to relative file path.
;; "prologos::core::eq-trait" → "prologos/core/eq-trait.prologos"
(define (module-name->rel-path mod-name)
  (string-append
   (string-replace mod-name "::" "/")
   ".prologos"))

;; ========================================
;; Line trimming
;; ========================================

;; Remove leading blank lines from a list of strings.
(define (drop-leading-blanks lines)
  (dropf lines (lambda (l) (string=? (string-trim l) ""))))

;; Remove trailing blank lines from a list of strings.
(define (drop-trailing-blanks lines)
  (reverse (dropf (reverse lines) (lambda (l) (string=? (string-trim l) "")))))

;; ========================================
;; Module file writer
;; ========================================

;; Write a single tangled module file.
;; Emits: ns <module-name> [flags]\n\n<content>
(define (write-tangled-module output-dir mod-name mod-flags content-lines)
  (define rel-path (module-name->rel-path mod-name))
  (define full-path (build-path output-dir rel-path))
  (define dir (let-values ([(base name dir?) (split-path full-path)]) base))

  ;; Ensure directory exists
  (make-directory* dir)

  ;; Build ns line
  (define ns-line
    (if (string=? mod-flags "")
        (format "ns ~a" mod-name)
        (format "ns ~a ~a" mod-name mod-flags)))

  ;; Trim content
  (define trimmed (drop-trailing-blanks (drop-leading-blanks content-lines)))

  ;; Write file
  (define output-content
    (string-append
     ns-line "\n"
     (if (null? trimmed)
         ""
         (string-append "\n" (string-join trimmed "\n") "\n"))))

  (display-to-file output-content full-path #:exists 'replace)
  (printf "  ~a → ~a~n" mod-name rel-path))

;; ========================================
;; Chapter tangler
;; ========================================

;; Tangle a single chapter file.
;; Returns the number of modules tangled.
(define (tangle-chapter book-dir output-dir chapter-name)
  (define chapter-path (build-path book-dir (format "~a.prologos" chapter-name)))
  (unless (file-exists? chapter-path)
    (error 'tangle "chapter file not found: ~a" chapter-path))

  (printf "chapter: ~a~n" chapter-name)
  (define lines (file->lines chapter-path))
  (define modules (split-chapter-modules lines))

  (when (null? modules)
    (eprintf "  warning: no module directives found in ~a~n" chapter-name))

  (for ([mod (in-list modules)])
    (match-define (list name flags content) mod)
    (write-tangled-module output-dir name flags content))

  (length modules))

;; ========================================
;; Main entry point
;; ========================================

;; Tangle all chapters listed in OUTLINE.
;; Returns total number of modules tangled.
(define (tangle-all book-dir output-dir)
  (define outline-path (build-path book-dir "OUTLINE"))
  (unless (file-exists? outline-path)
    (error 'tangle "OUTLINE not found: ~a" outline-path))

  (define chapters (read-outline outline-path))
  (printf "Tangling ~a chapter~a from ~a~n"
          (length chapters)
          (if (= (length chapters) 1) "" "s")
          book-dir)
  (printf "Output: ~a~n~n" output-dir)

  (define total
    (for/sum ([ch (in-list chapters)])
      (tangle-chapter book-dir output-dir ch)))

  (printf "~nDone: ~a module~a from ~a chapter~a.~n"
          total (if (= total 1) "" "s")
          (length chapters) (if (= (length chapters) 1) "" "s"))
  total)

;; ========================================
;; Verification mode
;; ========================================

;; Compare tangled output against original library files.
;; Reports differences (ignoring trailing whitespace).
(define (verify-tangled output-dir lib-dir)
  (define tangled-files
    (for/list ([f (in-directory output-dir)]
               #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
      f))

  (define mismatches 0)
  (define matches 0)
  (define missing 0)

  (for ([tangled-path (in-list tangled-files)])
    (define rel (find-relative-path output-dir tangled-path))
    (define original-path (build-path lib-dir rel))

    (cond
      [(not (file-exists? original-path))
       (printf "  NEW: ~a (no original)~n" rel)
       (set! missing (add1 missing))]
      [else
       (define tangled-lines
         (map string-trim (file->lines tangled-path)))
       (define original-lines
         (map string-trim (file->lines original-path)))
       (if (equal? tangled-lines original-lines)
           (begin
             (printf "  OK:  ~a~n" rel)
             (set! matches (add1 matches)))
           (begin
             (printf "  DIFF: ~a~n" rel)
             (set! mismatches (add1 mismatches))))]))

  (printf "~nVerification: ~a match, ~a differ, ~a new~n"
          matches mismatches missing)
  (= mismatches 0))

;; ========================================
;; CLI
;; ========================================

(module+ main
  (require racket/cmdline)

  ;; Default paths relative to project root.
  ;; The tool lives at racket/prologos/tools/tangle-stdlib.rkt.
  ;; We search upward from CWD for a directory containing racket/prologos/.
  (define project-root
    (let loop ([dir (simplify-path (current-directory))])
      (cond
        [(directory-exists? (build-path dir "racket" "prologos"))
         dir]
        [else
         (define parent (simplify-path (build-path dir "..")))
         (if (equal? parent dir)
             (current-directory)  ; fallback: use CWD
             (loop parent))])))

  (define book-dir
    (make-parameter
     (build-path project-root "racket" "prologos" "lib" "prologos" "book")))
  (define output-dir
    (make-parameter
     (build-path project-root ".tangled")))
  (define lib-dir
    (make-parameter
     (build-path project-root "racket" "prologos" "lib")))
  (define verify? (make-parameter #f))
  (define analyze? (make-parameter #f))

  (command-line
   #:program "tangle-stdlib"
   #:once-each
   [("--book-dir") dir "Book source directory"
    (book-dir (string->path dir))]
   [("--output-dir") dir "Tangled output directory"
    (output-dir (string->path dir))]
   [("--lib-dir") dir "Original library directory (for --verify)"
    (lib-dir (string->path dir))]
   [("--verify") "Compare tangled output against originals"
    (verify? #t)]
   [("--analyze") "Run form-level dependency analysis"
    (analyze? #t)]
   #:args ()
   (cond
     [(analyze?)
      ;; Delegate to form-deps.rkt
      (define form-deps-path
        (build-path (path-only (syntax-source #'here)) "form-deps.rkt"))
      ;; Resolve racket binary (same strategy as bench-lib.rkt)
      (define racket-exe
        (or (find-executable-path "racket")
            (let* ([exe (find-system-path 'exec-file)]
                   [dir (path-only exe)]
                   [candidate (and dir (build-path dir "racket"))])
              (and candidate (file-exists? candidate) candidate))
            (error 'tangle-stdlib "Cannot locate racket binary")))
      (define result (system* racket-exe (path->string form-deps-path)))
      (unless result (exit 1))]
     [(verify?)
      (printf "Verifying tangled output against originals...~n")
      (define ok? (verify-tangled (output-dir) (lib-dir)))
      (unless ok?
        (exit 1))]
     [else
      (tangle-all (book-dir) (output-dir))])))
