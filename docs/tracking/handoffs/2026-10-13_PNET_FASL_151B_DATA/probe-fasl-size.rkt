#lang racket/base
;; probe-fasl-size.rkt <v11 cache dir> <v12 cache dir> — is fasl size a function of the DATA?
;; Per common module: v11 file bytes; fasl bytes of the v11 body as text-READ; v12 file bytes;
;; fasl bytes of the v12 body re-encoded. If text-read and in-memory bodies fasl to the same size,
;; "text-read bodies lose sharing" cannot explain any size difference.
(require racket/fasl racket/path racket/list)
(define-values (d11 d12) (apply values (vector->list (current-command-line-arguments))))
(define (pnets d) (for/hash ([f (in-directory d)] #:when (regexp-match? #rx"[.]pnet$" (path->string f)))
                    (values (path->string (find-relative-path (simplify-path d) (simplify-path f))) f)))
(define f11 (pnets d11)) (define f12 (pnets d12))
(define-values (a b c e n)
  (for/fold ([a 0] [b 0] [c 0] [e 0] [n 0]) ([(k p11) (in-hash f11)] #:when (hash-ref f12 k #f))
    (define body11 (call-with-input-file p11 (λ (in) (read in) (read in))))
    (define body12 (call-with-input-file (hash-ref f12 k) (λ (in) (read in) (read-char in) (fasl->s-exp in))))
    (values (+ a (file-size p11)) (+ b (bytes-length (s-exp->fasl body11)))
            (+ c (file-size (hash-ref f12 k))) (+ e (bytes-length (s-exp->fasl body12))) (add1 n))))
(printf "modules ~a\n v11 files (text)            ~a bytes\n fasl of text-read v11 bodies ~a bytes\n v12 files (header + fasl)   ~a bytes\n fasl of v12 bodies re-encoded ~a bytes\n" n a b c e)
(printf "fasl(text-read) - fasl(v12 body) = ~a bytes\n" (- b e))
