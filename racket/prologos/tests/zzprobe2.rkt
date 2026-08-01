#lang racket/base
;; Diagnostic harness: prefix-bisect a .prologos library file at TOP-LEVEL FORM
;; boundaries to find the first form whose addition makes the module fail to load.
(require racket/list racket/string racket/port racket/file
         "test-support.rkt"
         "../macros.rkt" "../prelude.rkt" "../syntax.rkt" "../source-location.rkt"
         "../surface-syntax.rkt" "../errors.rkt" "../metavar-store.rkt"
         "../parser.rkt" "../elaborator.rkt" "../pretty-print.rkt"
         "../global-env.rkt" "../driver.rkt" "../namespace.rkt" "../multi-dispatch.rkt")

(define src (vector-ref (current-command-line-arguments) 0))
(define lines (file->lines src))
(define total (length lines))

;; top-level form boundaries: line index (1-based) whose text starts at col 0,
;; is non-blank and not a comment.
(define boundaries
  (for/list ([l (in-list lines)] [i (in-naturals 1)]
             #:when (and (> (string-length l) 0)
                         (not (char-whitespace? (string-ref l 0)))
                         (not (char=? (string-ref l 0) #\;))))
    i))

(define lib-ocapn (build-path prelude-lib-dir "prologos" "ocapn"))
(define tgt (build-path lib-ocapn "zzprobenl.prologos"))

(define (try n)
  (define txt (string-join (take lines (min n total)) "\n"))
  (define txt2 (regexp-replace #rx"ns prologos::ocapn::netlayer" txt "ns prologos::ocapn::zzprobenl"))
  (call-with-output-file tgt #:exists 'replace (lambda (o) (display txt2 o) (newline o)))
  (with-handlers ([(lambda (e) #t)
                   (lambda (e) (if (exn? e) (exn-message e) (format "~s" e)))])
    (parameterize ([current-file-module-network-ref (make-module-network)]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-ctor-registry (current-ctor-registry)]
                   [current-type-meta (current-type-meta)]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-multi-defn-registry (current-multi-defn-registry)]
                   [current-use-pnet-cache? #f]
                   [current-pnet-write-enabled? #f]
                   [current-spec-store (hasheq)])
      (install-module-loader!)
      (process-string "(ns zzprobetop)\n(imports (prologos::ocapn::zzprobenl :refer-all))\n"))
    #f))

;; cut points = line just before each boundary (i.e. include forms up to prev boundary)
(define cuts (append (cdr (map sub1 boundaries)) (list total)))

(let loop ([cs cuts])
  (cond
    [(null? cs) (printf "NO-FAIL over ~a cuts\n" (length cuts))]
    [else
     (define n (car cs))
     (define r (try n))
     (printf "cut ~a => ~a\n" n (if r "FAIL" "ok"))
     (flush-output)
     (if r
         (begin
           (printf "\nFIRST-FAIL including up to line ~a\n~a\n" n r)
           (printf "--- lines ---\n")
           (for ([i (in-range (max 1 (- n 30)) (add1 n))])
             (printf "~a: ~a\n" i (list-ref lines (sub1 i)))))
         (loop (cdr cs)))]))
(delete-file tgt)
