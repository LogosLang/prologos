#lang racket/base
;; C6 probe 2 — fire-context mechanisms: bytes per entry (main evidence) and ns (secondary).
;; Each row runs M iterations of the mechanism around a trivial body, measured with
;; (current-memory-use 'cumulative); the loop overhead row is subtracted.
(require racket/fixnum)
(define M 2000000)
(define p1 (make-parameter 0))
(define p2 (make-parameter 0))
(define p3 (make-parameter 0))
(define k (make-continuation-mark-key 'fire-ctx))
(define priv-tag (make-continuation-prompt-tag 'private))
(define sink (box 0))
(define opaque (box (lambda () 1)))
(define captured (parameterize ([p1 1] [p2 2] [p3 3]) (current-parameterization)))

(define-syntax-rule (row label body)
  (begin
    (collect-garbage)
    (let ([b0 (current-memory-use 'cumulative)]
          [t0 (current-inexact-milliseconds)])
      (let loop ([i 0])
        (when (fx< i M)
          (set-box! sink body)
          (loop (fx+ i 1))))
      (let ([b1 (current-memory-use 'cumulative)]
            [t1 (current-inexact-milliseconds)])
        (list label (/ (- b1 b0) (exact->inexact M)) (/ (* 1e6 (- t1 t0)) M))))))

(define (deep n thunk) (if (fx= n 0) (thunk) (fx+ 0 (deep (fx- n 1) thunk))))

(define rows
  (with-continuation-mark k 99 (list
   (row "loop overhead (body = fixnum)" 1)
   (row "parameterize 1 binding" (parameterize ([p1 1]) (p1)))
   (row "parameterize 2 then nested 1 (today's shape)" (parameterize ([p1 1] [p2 2]) (parameterize ([p3 3]) (p3))))
   (row "with-continuation-mark (non-tail body)" (fx+ 0 (with-continuation-mark k 7 (fx+ 1 0))))
   (row "wcm + read mark with default tag" (fx+ 0 (with-continuation-mark k 7 (continuation-mark-set-first #f k))))
   (row "wcm + read mark with private tag" (fx+ 0 (with-continuation-mark k 7 (continuation-mark-set-first #f k #f priv-tag))))
   (row "call-with-parameterization (captured)" (call-with-parameterization captured (lambda () (p3))))
   (row "parameter read, no parameterize" (p1))
   (row "wcm around an opaque call (mark must exist)" (fx+ 0 (with-continuation-mark k 7 ((unbox opaque)))))
   (row "parameterize 1 around an opaque call" (fx+ 0 (parameterize ([p1 1]) ((unbox opaque)))))
   (row "read mark only (installed once outside loop)" (continuation-mark-set-first #f k))
   (row "read mark only, private tag" (continuation-mark-set-first #f k #f priv-tag)))))

(printf "M = ~a iterations per row; bytes/op and ns/op (ns is secondary: machine loaded)\n" M)
(for ([r rows]) (printf "  ~a: ~a B/op  ~a ns/op\n" (car r) (cadr r) (caddr r)))

;; read cost of a mark/parameter set far up the stack (fire wrapper at the base, reader deep)
(define M2 200000)
(define (read-at-depth d reader)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (define b0 (current-memory-use 'cumulative))
  (for ([i (in-range M2)]) (set-box! sink (deep d reader)))
  (list d (/ (- (current-memory-use 'cumulative) b0) (exact->inexact M2))
        (/ (* 1e6 (- (current-inexact-milliseconds) t0)) M2)))
(printf "depth rows (depth B/op ns/op), includes the recursion itself:\n")
(for ([d '(0 100 1000)])
  (printf "  recursion only        ~a\n" (read-at-depth d (lambda () 1)))
  (printf "  mark read (set at base) ~a\n"
          (let ([r (with-continuation-mark k 7 (list (read-at-depth d (lambda () (continuation-mark-set-first #f k)))))]) (car r)))
  (printf "  param read (pz at base) ~a\n"
          (parameterize ([p1 7]) (read-at-depth d (lambda () (p1))))))
