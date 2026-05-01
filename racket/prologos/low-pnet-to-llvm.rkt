#lang racket/base

;; low-pnet-to-llvm.rkt — SH Track 2 Phase 2.C.
;;
;; Lowers a Low-PNet IR structure to LLVM IR text. Third of three Track 2
;; phases per the design doc (e9e59ab).
;;
;; Pipeline position:
;;   .prologos → process-file → typed AST
;;       → network-emit (or Phase 2.B for prop-net path) → Low-PNet IR
;;       → THIS PASS → LLVM IR text
;;       → clang + libprologos-runtime.o → native binary
;;
;; Scope of Phase 2.C (this commit):
;;   - cell-decl    → call prologos_cell_alloc; store SSA cell-id name
;;   - write-decl   → call prologos_cell_write
;;   - entry-decl   → emit @main with prologos_cell_read + ret
;;   - domain-decl  → noop at lowering time (the kernel's domain registry
;;                    is initialized separately; cell-decl ignores the
;;                    domain-id field for the N0-equivalent kernel that
;;                    doesn't yet do merging)
;;   - meta-decl    → emit as LLVM module metadata
;;
;; Out of scope (raised as unsupported):
;;   - propagator-decl: needs a per-program .o with fire-fn implementations
;;     and a kernel scheduler. Future work; see fire-fn-tag audit doc.
;;   - dep-decl: meaningful only with propagators
;;   - stratum-decl: meaningful with multi-stratum scheduler
;;
;; The N0 kernel (runtime/prologos-runtime.zig) provides exactly the three
;; primitives we use here. So a simple `def main : Int := 42` lowered via
;; this pass produces an executable binary with the existing kernel.

(require racket/match
         racket/list
         racket/format
         "low-pnet-ir.rkt")

(provide lower-low-pnet-to-llvm
         (struct-out unsupported-low-pnet-decl))

(struct unsupported-low-pnet-decl exn:fail (decl reason) #:transparent)

(define (unsupported! d reason)
  (raise (unsupported-low-pnet-decl
          (format "Phase 2.C cannot lower ~v: ~a" d reason)
          (current-continuation-marks)
          d
          reason)))

(define (default-target-triple)
  (or (getenv "PROLOGOS_LLVM_TRIPLE")
      "x86_64-unknown-linux-gnu"))

;; lower-low-pnet-to-llvm : low-pnet → String
(define (lower-low-pnet-to-llvm lp)
  (unless (low-pnet? lp)
    (error 'lower-low-pnet-to-llvm "expected low-pnet, got ~v" lp))
  (validate-low-pnet lp)  ;; raises if malformed
  (match-define (low-pnet version nodes) lp)

  ;; Refuse propagator/dep/stratum decls — Phase 2.C doesn't lower them yet.
  (for ([n (in-list nodes)])
    (cond
      [(propagator-decl? n)
       (unsupported! n "propagator-decl lowering deferred (needs fire-fn .o + scheduler integration)")]
      [(dep-decl? n)
       (unsupported! n "dep-decl is meaningful only with propagator-decls (Phase 2.C+)")]
      [(stratum-decl? n)
       (unsupported! n "stratum-decl lowering deferred (Phase 2.C+)")]))

  ;; Find the entry cell.
  (define entry
    (or (findf entry-decl? nodes)
        (error 'lower-low-pnet-to-llvm "no entry-decl in Low-PNet")))
  (define entry-cell-id (entry-decl-main-cell-id entry))

  ;; Walk decls, build LLVM IR fragments.
  (define cell-decls    (filter cell-decl? nodes))
  (define write-decls   (filter write-decl? nodes))
  (define meta-decls    (filter meta-decl? nodes))

  ;; Map cell-decl id → SSA name for this @main scope.
  ;; Each cell-decl emits %cN where N is its id.
  (define (cell-ssa-name id)
    (format "%c~a" id))

  (define alloc-lines
    (for/list ([c (in-list cell-decls)])
      (define id (cell-decl-id c))
      (format "  ~a = call i32 @prologos_cell_alloc()" (cell-ssa-name id))))

  ;; init-value emission via cell-decl: if marshalable to i64, emit a write.
  ;; (Phase 2.B+ marshals exact integers, booleans, etc. — booleans become
  ;; 0/1, integers stay, anything else falls back to the placeholder symbol
  ;; which we cannot emit as an i64 literal.)
  (define (init-value->i64-or-error c)
    (define v (cell-decl-init-value c))
    (cond
      [(exact-integer? v) v]
      [(eq? v #t) 1]
      [(eq? v #f) 0]
      [else
       (unsupported! c
                     (format "init-value ~v is not i64-marshalable. Phase 2.C lowers only Int and Bool cells; complex values need a value-marshal step in Phase 2.D"
                             v))]))

  (define init-lines
    (for/list ([c (in-list cell-decls)])
      (define id (cell-decl-id c))
      (define v (init-value->i64-or-error c))
      (format "  call void @prologos_cell_write(i32 ~a, i64 ~a)"
              (cell-ssa-name id) v)))

  (define write-lines
    (for/list ([w (in-list write-decls)])
      (define cid (write-decl-cell-id w))
      (define v (write-decl-value w))
      (unless (or (exact-integer? v) (eq? v #t) (eq? v #f))
        (unsupported! w
                      (format "write-decl value ~v is not i64-marshalable" v)))
      (define vi64 (cond [(exact-integer? v) v]
                         [(eq? v #t) 1]
                         [(eq? v #f) 0]))
      (format "  call void @prologos_cell_write(i32 ~a, i64 ~a)"
              (cell-ssa-name cid) vi64)))

  ;; Module metadata from meta-decls (debug / diagnostic).
  (define meta-comment-lines
    (for/list ([m (in-list meta-decls)])
      (format "; meta: ~a = ~v" (meta-decl-key m) (meta-decl-value m))))

  ;; Assemble.
  (string-append
   "; ModuleID = 'prologos-low-pnet'\n"
   (format "target triple = \"~a\"\n" (default-target-triple))
   (format "; Low-PNet format version: ~a\n" version)
   (apply string-append
          (for/list ([l (in-list meta-comment-lines)]) (string-append l "\n")))
   "\n"
   "declare i32 @prologos_cell_alloc()\n"
   "declare i64 @prologos_cell_read(i32)\n"
   "declare void @prologos_cell_write(i32, i64)\n"
   "\n"
   "define i64 @main() {\n"
   "entry:\n"
   (apply string-append
          (for/list ([l (in-list alloc-lines)]) (string-append l "\n")))
   (apply string-append
          (for/list ([l (in-list init-lines)]) (string-append l "\n")))
   (apply string-append
          (for/list ([l (in-list write-lines)]) (string-append l "\n")))
   (format "  %r = call i64 @prologos_cell_read(i32 ~a)\n"
           (cell-ssa-name entry-cell-id))
   "  ret i64 %r\n"
   "}\n"))
