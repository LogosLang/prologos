#lang racket/base

;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;; gen-prelude — generate prelude-imports from PRELUDE manifest
;; ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
;;
;; The PRELUDE manifest (lib/prologos/book/PRELUDE) is the single source
;; of truth for the prelude auto-imports. This tool reads the manifest
;; and generates the `prelude-requires` definition in namespace.rkt.
;;
;; Usage:
;;   racket tools/gen-prelude.rkt                  (print generated prelude to stdout)
;;   racket tools/gen-prelude.rkt --validate       (check against namespace.rkt)
;;   racket tools/gen-prelude.rkt --write          (update namespace.rkt in place)
;;   racket tools/gen-prelude.rkt --check-exports  (validate module files exist)

(require racket/file
         racket/string
         racket/path
         racket/list
         racket/format
         racket/port)

;; ========================================
;; Project root resolution
;; ========================================

(define (find-project-root)
  (let loop ([dir (simplify-path (current-directory))])
    (cond
      [(directory-exists? (build-path dir "racket" "prologos"))
       dir]
      [else
       (define parent (simplify-path (build-path dir "..")))
       (if (equal? parent dir)
           (current-directory)
           (loop parent))])))

;; ========================================
;; PRELUDE manifest reader
;; ========================================

;; Read the PRELUDE manifest → list of content lines (after header).
;; Header = everything before the first "(imports" / "(require" or ";; ----" line.
(define (read-prelude-manifest manifest-path)
  (unless (file-exists? manifest-path)
    (error 'gen-prelude "PRELUDE manifest not found: ~a" manifest-path))
  (define all-lines (file->lines manifest-path))
  (let loop ([lines all-lines] [in-header? #t])
    (cond
      [(null? lines) '()]
      [in-header?
       (define stripped (string-trim (car lines)))
       (cond
         [(or (string-prefix? stripped "(imports")
              (string-prefix? stripped "(require")
              (string-prefix? stripped ";; ----"))
          (cons (car lines) (loop (cdr lines) #f))]
         [else (loop (cdr lines) #t)])]
      [else
       (cons (car lines) (loop (cdr lines) #f))])))

;; ========================================
;; Racket prelude generator
;; ========================================

;; Generate the (define prelude-imports '(...)) block from content lines.
;; Preserves internal indentation of multi-line imports forms.
;; Returns a string.
(define (generate-prelude-string content-lines)
  ;; Strip trailing blank lines
  (define clean-lines
    (reverse
     (dropf (reverse content-lines)
            (lambda (l) (string=? (string-trim l) "")))))

  (cond
    [(null? clean-lines)
     (string-append
      ";; The prelude: a curated list of imports specs emitted into user namespaces.\n"
      ";; Generated from lib/prologos/book/PRELUDE by tools/gen-prelude.rkt.\n"
      "(define prelude-imports '())\n")]
    [else
     (define out (open-output-string))

     (fprintf out ";; The prelude: a curated list of imports specs emitted into user namespaces.\n")
     (fprintf out ";; Generated from lib/prologos/book/PRELUDE by tools/gen-prelude.rkt.\n")
     (fprintf out "(define prelude-imports\n")

     ;; First content line opens the quoted list
     (fprintf out "  '(~a\n" (car clean-lines))

     ;; Middle lines: add 4-space indent, preserving internal whitespace
     (define middle (if (> (length clean-lines) 1)
                        (cdr (drop-right clean-lines 1))
                        '()))
     (for ([line (in-list middle)])
       (cond
         [(string=? (string-trim line) "")
          (fprintf out "\n")]
         [else
          (fprintf out "    ~a\n" line)]))

     ;; Last line: add 4-space indent + close with ))
     (when (> (length clean-lines) 1)
       (define last-line (last clean-lines))
       (unless (string=? (string-trim last-line) "")
         (fprintf out "    ~a))\n" last-line)))

     (get-output-string out)]))

;; ========================================
;; namespace.rkt parser
;; ========================================

(define BEGIN-MARKER ";;; ---- BEGIN GENERATED PRELUDE ----")
(define END-MARKER   ";;; ---- END GENERATED PRELUDE ----")

;; Find markers in namespace.rkt.
;; Returns: (values before-lines mid-lines after-lines) or (values #f #f #f).
(define (parse-namespace-file ns-path)
  (define lines (file->lines ns-path))
  (define begin-idx
    (for/first ([i (in-naturals)]
                [line (in-list lines)]
                #:when (string=? (string-trim line) BEGIN-MARKER))
      i))
  (define end-idx
    (for/first ([i (in-naturals)]
                [line (in-list lines)]
                #:when (string=? (string-trim line) END-MARKER))
      i))
  (cond
    [(and begin-idx end-idx (< begin-idx end-idx))
     (values (take lines begin-idx)
             (take (drop lines (add1 begin-idx)) (- end-idx begin-idx 1))
             (drop lines (add1 end-idx)))]
    [else (values #f #f #f)]))

;; Extract current prelude-imports block from namespace.rkt (no markers needed).
;; Tracks paren depth to find the complete (define prelude-imports ...) form.
;; Returns the block as a string.
(define (extract-current-prelude ns-path)
  (define lines (file->lines ns-path))
  (define start-idx
    (for/first ([i (in-naturals)]
                [line (in-list lines)]
                #:when (or (string-contains? line "(define prelude-imports")
                           (string-contains? line "(define prelude-requires")))
      i))
  (unless start-idx
    (error 'gen-prelude "Cannot find (define prelude-imports ...) in ~a" ns-path))

  ;; Find end by tracking paren depth
  (define end-idx
    (let loop ([i start-idx] [depth 0] [started? #f])
      (cond
        [(>= i (length lines))
         (error 'gen-prelude "Unterminated prelude-imports in ~a" ns-path)]
        [else
         (define line (list-ref lines i))
         (define new-depth
           (for/fold ([d depth])
                     ([c (in-string line)])
             (case c
               [(#\() (add1 d)]
               [(#\)) (sub1 d)]
               [else d])))
         (cond
           [(and started? (<= new-depth 0)) (add1 i)]
           [else (loop (add1 i) new-depth #t)])])))

  (string-join (take (drop lines start-idx) (- end-idx start-idx)) "\n"))

;; Write generated prelude into namespace.rkt between markers.
(define (write-namespace-file! ns-path generated-block)
  (define-values (before _mid after) (parse-namespace-file ns-path))
  (cond
    [(not before)
     (eprintf "Error: No markers found in ~a.\n" ns-path)
     (eprintf "Add these markers around prelude-requires:\n")
     (eprintf "  ~a\n" BEGIN-MARKER)
     (eprintf "  ... prelude-requires ...\n")
     (eprintf "  ~a\n" END-MARKER)
     #f]
    [else
     (define new-content
       (string-append
        (string-join before "\n") "\n"
        BEGIN-MARKER "\n"
        generated-block
        END-MARKER "\n"
        (string-join after "\n")
        (if (null? after) "" "\n")))
     (display-to-file new-content ns-path #:exists 'replace)
     (printf "Updated ~a\n" ns-path)
     #t]))

;; ========================================
;; Validation
;; ========================================

;; Extract import entries from a prelude text block.
;; Returns a list of normalized imports s-expressions (as strings).
;; Multi-line imports are joined into single lines.
;; Also recognizes legacy (require ...) forms for backward compat.
(define (extract-import-entries text)
  (define lines (string-split text "\n"))
  (define result '())
  (define current-req #f)
  (define paren-depth 0)

  (for ([line (in-list lines)])
    (define stripped (string-trim line))
    (cond
      ;; Start of a new imports/require entry
      [(and (not current-req) (or (string-prefix? stripped "(imports")
                                  (string-prefix? stripped "(require")))
       (set! current-req stripped)
       (set! paren-depth
             (for/fold ([d 0]) ([c (in-string stripped)])
               (case c [(#\() (add1 d)] [(#\)) (sub1 d)] [else d])))
       (when (<= paren-depth 0)
         (set! result (cons current-req result))
         (set! current-req #f))]
      ;; Continuation of a multi-line require
      [current-req
       (set! current-req (string-append current-req " " stripped))
       (set! paren-depth
             (+ paren-depth
                (for/fold ([d 0]) ([c (in-string stripped)])
                  (case c [(#\() (add1 d)] [(#\)) (sub1 d)] [else d]))))
       (when (<= paren-depth 0)
         (set! result (cons current-req result))
         (set! current-req #f))]
      ;; Comment or blank — skip
      [else (void)]))

  (reverse result))

;; Compare generated prelude against current namespace.rkt.
;; Compares require entries only (ignoring comments and whitespace).
(define (validate-prelude manifest-path ns-path)
  (define content-lines (read-prelude-manifest manifest-path))
  (define generated (generate-prelude-string content-lines))
  (define current (extract-current-prelude ns-path))

  (define gen-reqs (extract-import-entries generated))
  (define cur-reqs (extract-import-entries current))

  (printf "Generated: ~a import entries from PRELUDE manifest\n" (length gen-reqs))
  (printf "Current:   ~a import entries in namespace.rkt\n" (length cur-reqs))

  (define max-len (max (length gen-reqs) (length cur-reqs)))
  (define diffs 0)
  (for ([i (in-range max-len)])
    (define gr (if (< i (length gen-reqs)) (list-ref gen-reqs i) "<missing>"))
    (define cr (if (< i (length cur-reqs)) (list-ref cur-reqs i) "<missing>"))
    (unless (string=? gr cr)
      (set! diffs (add1 diffs))
      (when (<= diffs 10)
        (printf "\n  DIFF at entry ~a:\n    generated: ~a\n    current:   ~a\n" (add1 i) gr cr))))

  (cond
    [(= diffs 0)
     (printf "\nValidation PASSED: all ~a import entries match\n" (length gen-reqs))
     #t]
    [else
     (when (> diffs 10)
       (printf "\n  ... and ~a more differences\n" (- diffs 10)))
     (printf "\nValidation FAILED: ~a entries differ\n" diffs)
     #f]))

;; ========================================
;; Export checking (module existence)
;; ========================================

;; Extract module namespace symbols from PRELUDE manifest content lines.
;; Handles multi-line imports forms by joining lines until parens balance.
(define (extract-prelude-modules content-lines)
  (define full-text (string-join content-lines "\n"))
  (define reqs (extract-import-entries full-text))
  (filter-map
   (lambda (req-str)
     (define spec
       (with-handlers ([exn:fail? (lambda (e) #f)])
         (read (open-input-string req-str))))
     (and spec (list? spec) (>= (length spec) 2)
          (let ([inner (cadr spec)])
            (cond
              [(and (list? inner) (pair? inner) (symbol? (car inner)))
               (car inner)]
              [else #f]))))
   reqs))

;; Verify all PRELUDE modules exist as .prologos files.
(define (check-module-existence content-lines project-root)
  (define lib-dir (build-path project-root "racket" "prologos" "lib"))
  (define modules (extract-prelude-modules content-lines))
  (define missing 0)
  (define found 0)

  (for ([ns-sym (in-list modules)])
    (define ns-str (symbol->string ns-sym))
    (define rel-path
      (string-append (string-replace ns-str "::" "/") ".prologos"))
    (define full-path (build-path lib-dir rel-path))
    (cond
      [(file-exists? full-path)
       (set! found (add1 found))]
      [else
       (printf "  MISSING: ~a (~a)\n" ns-sym rel-path)
       (set! missing (add1 missing))]))

  (printf "\nExport check: ~a modules found, ~a missing\n" found missing)
  (= missing 0))

;; ========================================
;; CLI
;; ========================================

(module+ main
  (require racket/cmdline)

  (define project-root (find-project-root))
  (define manifest-path
    (build-path project-root "racket" "prologos" "lib" "prologos" "book" "PRELUDE"))
  (define ns-path
    (build-path project-root "racket" "prologos" "namespace.rkt"))

  (define mode (make-parameter 'generate))

  (command-line
   #:program "gen-prelude"
   #:once-any
   [("--validate") "Compare generated prelude against namespace.rkt"
    (mode 'validate)]
   [("--write") "Update namespace.rkt with generated prelude"
    (mode 'write)]
   [("--check-exports") "Verify all PRELUDE modules exist as files"
    (mode 'check-exports)]
   #:args ()
   (case (mode)
     [(generate)
      (define content-lines (read-prelude-manifest manifest-path))
      (define generated (generate-prelude-string content-lines))
      (display generated)]
     [(validate)
      (define ok? (validate-prelude manifest-path ns-path))
      (unless ok? (exit 1))]
     [(write)
      (define content-lines (read-prelude-manifest manifest-path))
      (define generated (generate-prelude-string content-lines))
      (define ok? (write-namespace-file! ns-path generated))
      (unless ok? (exit 1))]
     [(check-exports)
      (define content-lines (read-prelude-manifest manifest-path))
      (printf "Checking PRELUDE modules against library files...\n")
      (define ok? (check-module-existence content-lines project-root))
      (unless ok? (exit 1))])))
