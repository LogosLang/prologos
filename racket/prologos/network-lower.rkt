#lang racket/base

;; network-lower.rkt — SH Series Track 3 (N-series), Phase N0.
;;
;; Translates a network-skeleton (from network-emit.rkt) into LLVM IR
;; text. The IR contains:
;;
;;   - external declarations for the runtime kernel functions
;;     (prologos_cell_alloc, prologos_cell_write, prologos_cell_read)
;;     which are provided by runtime/prologos-runtime.zig (or a parallel
;;     C kernel during local validation; both share the same C ABI)
;;
;;   - a `main` function that:
;;       1. allocates each cell declared in the skeleton
;;       2. emits each constant write declared in the skeleton
;;       3. reads the result cell's value
;;       4. returns it (becomes the process exit code)
;;
;; SCAFFOLDING (per plan doc § 12): same statement as network-emit.rkt.
;; The lowering pass itself is a Racket function, not a propagator stratum.

(require racket/match
         racket/format
         "network-emit.rkt")

(provide lower-skeleton)

;; lower-skeleton : network-skeleton -> String
(define (lower-skeleton sk)
  (match sk
    [(network-skeleton cells writes result-cell)
     (string-append
      (header-text)
      (declarations-text)
      "\n"
      (main-text cells writes result-cell))]))

(define (header-text)
  (string-append
   "; ModuleID = 'prologos-network-n0'\n"
   "target triple = \"" (default-target-triple) "\"\n"
   "\n"))

(define (declarations-text)
  (string-append
   "declare i32 @prologos_cell_alloc()\n"
   "declare i64 @prologos_cell_read(i32)\n"
   "declare void @prologos_cell_write(i32, i64)\n"))

(define (main-text cells writes result-cell)
  ;; SSA names: %c0, %c1, ... for each allocated cell-id (the runtime's
  ;; returned u32). %r is the final i64 read from the result cell.
  (define alloc-lines
    (for/list ([c (in-list cells)])
      (define i (cell-decl-idx c))
      (format "  %c~a = call i32 @prologos_cell_alloc()" i)))
  (define write-lines
    (for/list ([w (in-list writes)])
      (define i (write-decl-idx w))
      (define v (write-decl-value w))
      (format "  call void @prologos_cell_write(i32 %c~a, i64 ~a)" i v)))
  (string-append
   "define i64 @main() {\n"
   "entry:\n"
   (apply string-append (for/list ([l (in-list alloc-lines)]) (string-append l "\n")))
   (apply string-append (for/list ([l (in-list write-lines)]) (string-append l "\n")))
   (format "  %r = call i64 @prologos_cell_read(i32 %c~a)\n" result-cell)
   "  ret i64 %r\n"
   "}\n"))

(define (default-target-triple)
  (or (getenv "PROLOGOS_LLVM_TRIPLE")
      "x86_64-unknown-linux-gnu"))
