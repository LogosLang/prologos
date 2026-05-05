#lang racket/base

;;;
;;; check-stdout-clean.rkt — Verify .rkt files don't pollute stdout on require.
;;;
;;; The Prologos LSP server uses stdout for JSON-RPC framing
;;; (Content-Length: N\r\n\r\n{json}). Any module-load-time stdout output
;;; corrupts the protocol stream and breaks editor integration.
;;;
;;; Common offender: top-level expressions in #lang racket/base modules that
;;; return non-void values. Racket's current-print emits those to stdout.
;;;
;;; Origin: surfaced 2026-04-28 — VS Code LSP failed with
;;;   "Header must provide a Content-Length property."
;;;   {"#t\n#t\n#t\n#t\n#t\ncontent-length":"394"}
;;; Root cause: 5 top-level (verify-rewrite-rule ...) calls in sre-rewrite.rkt
;;; returning #t. Fix: wrap in (void ...). Commit 1fe1422f.
;;;
;;; Usage:
;;;   racket tools/check-stdout-clean.rkt              # check all production .rkt
;;;   racket tools/check-stdout-clean.rkt FILE [FILE...] # check specific files
;;;
;;; Exit 0 = all clean. Exit 1 = at least one file polluted stdout.

(require racket/cmdline
         racket/file
         racket/path
         racket/port
         racket/list)

;; Anchor from script's own location: tools/ → repo-root/
(define this-file (path->string (simplify-path (syntax-source #'here))))
(define tools-dir (path-only this-file))
(define project-root (simplify-path (build-path tools-dir 'up)))
(define racket/prologos-dir (build-path project-root "racket" "prologos"))
(define lsp-dir (build-path racket/prologos-dir "lsp"))

;; ============================================================
;; File discovery
;; ============================================================

(define (production-files)
  (define top-level
    (for/list ([p (in-list (directory-list racket/prologos-dir #:build? #t))]
               #:when (and (file-exists? p)
                           (regexp-match? #px"\\.rkt$" (path->string p))))
      p))
  (define lsp-files
    (cond
      [(directory-exists? lsp-dir)
       (for/list ([p (in-list (directory-list lsp-dir #:build? #t))]
                  #:when (and (file-exists? p)
                              (regexp-match? #px"\\.rkt$" (path->string p))))
         p)]
      [else '()]))
  (append top-level lsp-files))

(define (skip-path? path-str)
  ;; tests/, benchmarks/, examples/, tools/, lib/ have intentional output
  (or (regexp-match? #px"/(tests|benchmarks|examples|tools|lib)/" path-str)
      (regexp-match? #px"^(tests|benchmarks|examples|tools|lib)/" path-str)))

;; ============================================================
;; Stdout capture via dynamic-require
;; ============================================================

;; Load a file and return the captured stdout as a string.
;; Uses dynamic-require with stdout redirected to a string port.
;; Errors during load are caught and treated as "clean" (the file
;; failed to compile, which is check-parens / raco make territory,
;; not stdout-pollution).
(define (capture-load-stdout path)
  (define captured (open-output-string))
  (with-handlers ([exn:fail? (lambda (_) "")])
    (parameterize ([current-output-port captured])
      (dynamic-require path #f))
    (get-output-string captured)))

;; ============================================================
;; Main check
;; ============================================================

(define (check-files paths)
  (define violations
    (for/list ([p (in-list paths)]
               #:unless (skip-path? (path->string p))
               #:when (file-exists? p))
      (define output (capture-load-stdout p))
      (cond
        [(zero? (string-length output)) #f]
        [else (cons p output)])))
  (define real-violations (filter values violations))

  (cond
    [(null? real-violations)
     (printf "check-stdout-clean: ~a file(s) clean.~n"
             (length (filter (lambda (p) (not (skip-path? (path->string p)))) paths)))
     0]
    [else
     (for ([v (in-list real-violations)])
       (define path (car v))
       (define output (cdr v))
       (define rel
         (let ([candidate (find-relative-path project-root path)])
           ;; If the relative path escapes upward, prefer the absolute path
           (if (regexp-match? #px"^\\.\\./" (path->string candidate))
               path
               candidate)))
       (eprintf "STDOUT POLLUTION: ~a~n" rel)
       (define all-lines (regexp-split #px"\n" output))
       (define preview-count (min 3 (length all-lines)))
       (for ([line (in-list (take all-lines preview-count))]
             #:unless (zero? (string-length line)))
         (eprintf "  ~a~n" line)))
     (eprintf "~ncheck-stdout-clean: ~a of ~a file(s) polluted stdout.~n"
              (length real-violations)
              (length paths))
     (eprintf "Top-level expressions returning non-void print via current-print.~n")
     (eprintf "Fix: wrap call sites in (void ...) to discard the value.~n")
     1]))

;; ============================================================
;; Entry point
;; ============================================================

(define args
  (command-line
   #:program "check-stdout-clean"
   #:args files files))

(define paths
  (cond
    [(null? args) (production-files)]
    [else
     (for/list ([f (in-list args)])
       (define p (string->path f))
       (if (absolute-path? p) p (build-path project-root p)))]))

(exit (check-files paths))
