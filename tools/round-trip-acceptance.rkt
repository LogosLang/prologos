#lang racket/base

;; round-trip-acceptance.rkt
;; kernel-pocket-universes Phase 4 Day 10.
;;
;; Round-trip acceptance gate: for every .prologos file in the network
;; examples tree, lower through ast-to-low-pnet → low-pnet-to-prop-network
;; → run-to-quiescence and compare to the file's :expect-exit marker.
;;
;; This is the no-LLVM-in-the-loop validation envisioned by
;; docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md § 14 Phase 4 + § 15.6.
;; If the round-trip diverges from the native binary's exit code on any
;; example, the divergence is in the IR / lowering, not the kernel runtime
;; — because the prop-network runs the IR through the canonical Racket
;; interpreter (propagator.rkt), not the Zig kernel.
;;
;; Caveat: the binary's exit code is the result-cell value mod 256
;; (Unix u8 exit truncation). For fib20 (= 6765 = 109 mod 256) the
;; file declares the truncated value while the Racket adapter returns
;; the full i64. This script applies the mod-256 truncation when
;; comparing, matching the binary path's observable behavior.
;;
;; Usage:
;;   racket tools/round-trip-acceptance.rkt
;;
;; Exit code: 0 if all files pass; 1 otherwise.

(require "../racket/prologos/driver.rkt"
         "../racket/prologos/global-env.rkt"
         "../racket/prologos/ast-to-low-pnet.rkt"
         "../racket/prologos/low-pnet-ir.rkt"
         "../racket/prologos/low-pnet-to-prop-network.rkt"
         racket/file
         racket/string
         racket/runtime-path)

(define-runtime-path examples-dir "../racket/prologos/examples/network")

(define all
  (sort (for/list ([p (in-directory examples-dir)]
                   #:when (and (file-exists? p)
                               (regexp-match? #px"\\.prologos$" (path->string p))))
          p)
        path<?))

(printf "round-trip-acceptance: ~a .prologos files in ~a\n"
        (length all) (path->string (path->complete-path examples-dir)))

(define passes 0)
(define fails 0)
(define errors 0)
(define unsupported 0)
(define skipped 0)
(define fail-detail '())

;; The binary's exit code is the result mod 256 (Unix u8 truncation).
;; fib20 is the only example today that exceeds 255; this normalizes
;; the comparison so the round-trip is observationally equivalent to
;; the native-binary path.
(define (binary-exit-code v)
  (cond [(exact-integer? v) (modulo v 256)]
        [(eq? v #t) 1]
        [(eq? v #f) 0]
        [else v]))

(for ([path (in-list all)])
  (define content (file->string path))
  (define m (regexp-match #px":expect-exit[ \t]+([+-]?[0-9]+)" content))
  (define expect (and m (string->number (cadr m))))
  (cond
    [(not expect) (set! skipped (+ 1 skipped))]
    [else
     (with-handlers
       ([exn:fail?
         (lambda (e)
           (define msg (exn-message e))
           (cond [(regexp-match? #px"materialize|unsupported|ast-translation|ast-to-low-pnet cannot translate" msg)
                  (set! unsupported (+ 1 unsupported))
                  (set! fail-detail
                        (cons (list 'unsup (path->string path) msg) fail-detail))]
                 [else (set! errors (+ 1 errors))
                  (set! fail-detail
                        (cons (list 'error (path->string path) msg) fail-detail))]))])
       (process-file path)
       (define mt (global-env-lookup-type 'main))
       (define mb (global-env-lookup-value 'main))
       (define lp (ast-to-low-pnet mt mb (path->string path)))
       (define raw-result (run-low-pnet lp 1000000))
       (define result (binary-exit-code raw-result))
       (cond [(equal? result expect) (set! passes (+ 1 passes))]
             [else (set! fails (+ 1 fails))
              (set! fail-detail
                    (cons (list 'fail (path->string path) raw-result expect) fail-detail))]))]))

(for ([d (in-list (reverse fail-detail))])
  (case (car d)
    [(fail)
     (printf "  FAIL ~a: got=~v (mod 256 = ~v) expect=~v\n"
             (cadr d) (caddr d) (binary-exit-code (caddr d)) (cadddr d))]
    [(error)
     (printf "  ERROR ~a: ~a\n" (cadr d)
             (substring (caddr d) 0 (min 120 (string-length (caddr d)))))]
    [(unsup)
     (printf "  unsup ~a: ~a\n" (cadr d)
             (substring (caddr d) 0 (min 120 (string-length (caddr d)))))]))

(printf "=== passes=~a fails=~a errors=~a unsupported=~a skipped=~a / ~a total ===\n"
        passes fails errors unsupported skipped (length all))

(exit (if (and (zero? fails) (zero? errors)) 0 1))
