#lang racket/base

;;;
;;; DEFERRED 170 — a `make-temporary-file` path is never written with `#:exists 'replace`.
;;;
;;; `make-temporary-file` creates its file EXCLUSIVELY under a name drawn from the clock
;;; (seconds + milliseconds). `#:exists 'replace` then DELETES that file and creates it
;;; again; in between, a concurrent process using the same template (a twin shard of the
;;; same test file, or another test sharing a template such as test-support's
;;; `prologos-ws-~a`) can draw the same name and create it, and the re-create fails with
;;; `open-output-file: file exists`. Measured: 3 processes × 3 000 writes, 'replace fails
;;; 6–8 % per process, 'truncate 0 of 18 000 (handoffs/2026-10-13_SW24_DATA/tmp-race.rkt).
;;; `'truncate` writes into the file the process already owns, so there is no window.
;;;
;;; This guard reads every module under racket/prologos (root, tests/, tools/, lsp/,
;;; benchmarks/) as syntax and refuses any write call whose path is a variable bound to
;;; a non-directory `make-temporary-file` (or the call itself) with `#:exists 'replace`.
;;; A directory from `make-temporary-file … 'directory` is exclusive to its creator, so
;;; files inside it are not this hazard and are not flagged.
;;;

(require rackunit
         racket/list
         racket/path
         racket/runtime-path)

(define-runtime-path root "..")

(define WRITERS
  '(call-with-output-file call-with-output-file* with-output-to-file with-output-to-file*
    open-output-file display-to-file write-to-file display-lines-to-file))

(define (sym? s x) (and (identifier? s) (eq? (syntax-e s) x)))

;; (make-temporary-file …) without a 'directory argument
(define (temp-file-call? stx)
  (define e (syntax-e stx))
  (and (pair? e)
       (sym? (car e) 'make-temporary-file)
       (not (for/or ([a (in-list (syntax->list stx))])
              (equal? (syntax->datum a) ''directory)))))

;; temp-vars : syntax -> (listof symbol) — names bound to a temp-file call anywhere in the module
(define (temp-vars stx)
  (let walk ([s stx])
    (define e (syntax-e s))
    (cond
      [(pair? e)
       (define l (syntax->list s))
       (append
        (if (and l (= (length l) 3) (sym? (first l) 'define) (identifier? (second l))
                 (temp-file-call? (third l)))
            (list (syntax-e (second l)))
            '())
        (if (and l (= (length l) 2) (identifier? (first l)) (temp-file-call? (second l)))  ; [v (make-temporary-file …)]
            (list (syntax-e (first l)))
            '())
        (if l (append-map walk l) (append (walk (car e)) (walk (datum->syntax #f (cdr e))))))]
      [else '()])))

;; offenders : syntax -> (listof (cons line text))
(define (offenders stx)
  (define tv (temp-vars stx))
  (let walk ([s stx])
    (define l (and (pair? (syntax-e s)) (syntax->list s)))
    (cond
      [(not l) '()]
      [else
       (define here
         (if (and (pair? l) (identifier? (first l)) (memq (syntax-e (first l)) WRITERS)
                  (>= (length l) 2)
                  (let ([path (second l)])
                    (or (and (identifier? path) (memq (syntax-e path) tv))
                        (temp-file-call? path)))
                  (for/or ([a (in-list l)] [b (in-list (rest l))])
                    (and (equal? (syntax->datum a) '#:exists)
                         (equal? (syntax->datum b) ''replace))))
             (list (cons (syntax-line s)
                         (format "(~a ~a … #:exists 'replace …)" (syntax-e (first l)) (syntax->datum (second l)))))
             '()))
       (append here (append-map walk l))])))

(define (read-module p)
  (parameterize ([read-accept-reader #t] [read-accept-lang #t] [port-count-lines-enabled #t])
    (with-input-from-file p (λ () (read-syntax p)))))

(define (scanned-files)
  (define dirs (list root (build-path root "tests") (build-path root "tools") (build-path root "lsp")))
  (append
   (for*/list ([d (in-list dirs)] #:when (directory-exists? d)
               [f (in-list (directory-list d #:build? #t))]
               #:when (and (file-exists? f) (regexp-match? #rx"[.]rkt$" (path->string f))))
     f)
   (if (directory-exists? (build-path root "benchmarks"))
       (for/list ([f (in-directory (build-path root "benchmarks"))]
                  #:when (regexp-match? #rx"[.]rkt$" (path->string f)))
         f)
       '())))

(define (offenders-in-string s)
  (offenders (parameterize ([read-accept-reader #t] [read-accept-lang #t])
               (read-syntax 'snippet (let ([in (open-input-string s)]) (port-count-lines! in) in)))))

(test-case "the detector can fail: 'replace on a temp file is flagged; 'truncate, a directory, and a plain path are not"
  (check-equal? (length (offenders-in-string
                         "(module m racket/base (define (f s) (define tmp (make-temporary-file \"x-~a\")) (call-with-output-file tmp #:exists 'replace (λ (o) (display s o)))))"))
                1)
  (check-equal? (length (offenders-in-string
                         "(module m racket/base (let ([t (make-temporary-file)]) (with-output-to-file t (λ () 1) #:exists 'replace)))"))
                1 "let-bound, keyword after the thunk")
  (check-equal? (offenders-in-string
                 "(module m racket/base (define tmp (make-temporary-file \"x-~a\")) (call-with-output-file tmp #:exists 'truncate void))")
                '())
  (check-equal? (offenders-in-string
                 "(module m racket/base (define d (make-temporary-file \"d-~a\" 'directory)) (call-with-output-file d #:exists 'replace void))")
                '() "a temp DIRECTORY is exclusive to its creator")
  (check-equal? (offenders-in-string
                 "(module m racket/base (define p \"out.txt\") (call-with-output-file p #:exists 'replace void))")
                '() "not a temp file"))

(test-case "no module writes a make-temporary-file path with #:exists 'replace (DEFERRED 170)"
  (define found
    (for*/list ([f (in-list (scanned-files))]
                [o (in-list (with-handlers ([exn:fail:read? (λ (_) '())]) (offenders (read-module f))))])
      (format "~a:~a ~a" (find-relative-path (simplify-path root) (simplify-path f)) (car o) (cdr o))))
  (check-equal? found '() (format "~a site(s); write these with #:exists 'truncate" (length found))))
