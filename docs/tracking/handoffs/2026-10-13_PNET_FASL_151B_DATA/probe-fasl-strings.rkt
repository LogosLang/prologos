#lang racket/base
;; probe-fasl-strings.rkt <v11 cache dir> <v12 cache dir> — does eq?-sharing of STRING leaves explain the
;; fasl size gap (text-read bodies 9.65 MB vs in-memory bodies 4.49 MB)? Per body: string occurrences,
;; distinct eq? string objects, payload bytes over occurrences vs over distinct objects. fasl writes a
;; string once per eq? object (collects/racket/fasl.rkt:146-165), so the payload written is the
;; "distinct" column.
(require racket/fasl racket/path)
(define-values (d11 d12) (apply values (vector->list (current-command-line-arguments))))
(define (pnets d) (for/hash ([f (in-directory d)] #:when (regexp-match? #rx"[.]pnet$" (path->string f)))
                    (values (path->string (find-relative-path (simplify-path d) (simplify-path f))) f)))
(define (census body)
  (define seen (make-hasheq)) (define occ 0) (define occ-bytes 0)
  (let loop ([v body])
    (cond [(string? v) (set! occ (add1 occ)) (set! occ-bytes (+ occ-bytes (string-utf-8-length v))) (hash-set! seen v #t)]
          [(pair? v) (loop (car v)) (loop (cdr v))]
          [(vector? v) (for ([x (in-vector v)]) (loop x))]
          [(hash? v) (for ([(k x) (in-hash v)]) (loop k) (loop x))]
          [(box? v) (loop (unbox v))]
          [else (void)]))
  (vector occ (hash-count seen) occ-bytes (for/sum ([s (in-hash-keys seen)]) (string-utf-8-length s))))
(define f11 (pnets d11)) (define f12 (pnets d12))
(define (add a b) (for/vector ([x a] [y b]) (+ x y)))
(define-values (t11 t12)
  (for/fold ([a (vector 0 0 0 0)] [b (vector 0 0 0 0)]) ([(k p11) (in-hash f11)] #:when (hash-ref f12 k #f))
    (values (add a (census (call-with-input-file p11 (λ (in) (read in) (read in)))))
            (add b (census (call-with-input-file (hash-ref f12 k) (λ (in) (read in) (read-char in) (fasl->s-exp in))))))))
(define (show tag v)
  (printf "~a: string occurrences ~a, distinct eq? objects ~a; payload bytes over occurrences ~a, over distinct objects ~a\n"
          tag (vector-ref v 0) (vector-ref v 1) (vector-ref v 2) (vector-ref v 3)))
(show "v11 text-read " t11)
(show "v12 fasl-read " t12)
(printf "payload fasl writes: text-read ~a vs fasl-read ~a — difference ~a bytes (file-size gap was 5 158 491)\n"
        (vector-ref t11 3) (vector-ref t12 3) (- (vector-ref t11 3) (vector-ref t12 3)))
