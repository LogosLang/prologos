#lang racket/base

;; low-pnet-to-llvm.rkt — SH Track 2 Phase 2.C+D.
;;
;; Lowers a Low-PNet IR structure to LLVM IR text. Third of three Track 2
;; phases per the design doc (e9e59ab); Phase 2.D adds propagator-decl
;; lowering on top of 2.C's cell/write/entry handling.
;;
;; Pipeline position:
;;   .prologos → process-file → typed AST
;;       → ast-to-low-pnet (or Phase 2.B for prop-net path) → Low-PNet IR
;;       → THIS PASS → LLVM IR text
;;       → clang + libprologos-runtime.o → native binary
;;
;; Scope:
;;   - cell-decl       → call prologos_cell_alloc; SSA name %cN
;;   - write-decl      → call prologos_cell_write
;;   - propagator-decl → call prologos_propagator_install_2_1 (only the
;;                       (2,1) shape; tag resolved against fire-fn-tag
;;                       map below); subscribes to inputs implicitly;
;;                       enqueues for initial firing
;;   - dep-decl        → noop (subscribe is implicit on install_2_1;
;;                       dep-decl is informational at this kernel scope)
;;   - entry-decl      → emit @main with prologos_run_to_quiescence
;;                       before prologos_cell_read + ret
;;   - domain-decl     → noop at lowering time (kernel doesn't dispatch
;;                       merging by domain yet; domain-decls are
;;                       informational for the IR layer)
;;   - meta-decl       → emit as IR comment
;;
;; Out of scope (raised as unsupported):
;;   - propagator-decl with shapes other than (2,1)
;;   - propagator-decl with unknown fire-fn-tag (not in built-in map)
;;   - stratum-decl: meaningful with multi-stratum scheduler

(require racket/match
         racket/list
         racket/format
         "low-pnet-ir.rkt")

(provide lower-low-pnet-to-llvm
         (struct-out unsupported-low-pnet-decl)
         FIRE-FN-TAG-REGISTRY)

(struct unsupported-low-pnet-decl exn:fail (decl reason) #:transparent)

(define (unsupported! d reason)
  (raise (unsupported-low-pnet-decl
          (format "Phase 2.C/D cannot lower ~v: ~a" d reason)
          (current-continuation-marks)
          d
          reason)))

(define (default-target-triple)
  (or (getenv "PROLOGOS_LLVM_TRIPLE")
      "x86_64-unknown-linux-gnu"))

;; ============================================================
;; Fire-fn tag → kernel-side numeric ID
;; ============================================================
;;
;; The Zig kernel's prologos_propagator_install_2_1 takes a u32 tag
;; that selects the fire-fn implementation. This is the 1:1 map
;; between Low-PNet's symbolic tags and the kernel's numeric registry.
;;
;; Naming convention per fire-fn-tag audit doc § 6: 'kernel-* prefix.
;; The kernel's switch in prologos-runtime.zig must stay in sync with
;; the integers here.

;; Each shape (2,1) and (3,1) has its own tag namespace per the kernel's
;; fire dispatch (see runtime/prologos-runtime.zig).

(define FIRE-FN-TAG-REGISTRY-2-1
  '#hasheq((kernel-int-add . 0)
           (kernel-int-sub . 1)
           (kernel-int-mul . 2)
           (kernel-int-div . 3)
           (kernel-int-eq  . 4)
           (kernel-int-lt  . 5)
           (kernel-int-le  . 6)))

(define FIRE-FN-TAG-REGISTRY-3-1
  '#hasheq((kernel-select . 0)))

;; Backwards-compat alias for callers that just want the union view.
(define FIRE-FN-TAG-REGISTRY
  (for/fold ([h FIRE-FN-TAG-REGISTRY-2-1])
            ([(k v) (in-hash FIRE-FN-TAG-REGISTRY-3-1)])
    (hash-set h k v)))

(define (lookup-fire-fn-tag-id sym shape d)
  (define table
    (case shape
      [(2-1) FIRE-FN-TAG-REGISTRY-2-1]
      [(3-1) FIRE-FN-TAG-REGISTRY-3-1]
      [else (unsupported! d (format "no tag table for shape ~a" shape))]))
  (or (hash-ref table sym #f)
      (unsupported! d
                    (format "fire-fn-tag '~a' not in shape-~a registry. Supported (2,1): kernel-int-{add,sub,mul,div,eq,lt,le}. Supported (3,1): kernel-select."
                            sym shape))))

;; lower-low-pnet-to-llvm : low-pnet → String
(define (lower-low-pnet-to-llvm lp)
  (unless (low-pnet? lp)
    (error 'lower-low-pnet-to-llvm "expected low-pnet, got ~v" lp))
  (validate-low-pnet lp)  ;; raises if malformed
  (match-define (low-pnet version nodes) lp)

  ;; Refuse stratum decls — multi-stratum scheduling deferred.
  (for ([n (in-list nodes)])
    (when (stratum-decl? n)
      (unsupported! n "stratum-decl lowering deferred")))

  ;; Find the entry cell.
  (define entry
    (or (findf entry-decl? nodes)
        (error 'lower-low-pnet-to-llvm "no entry-decl in Low-PNet")))
  (define entry-cell-id (entry-decl-main-cell-id entry))

  ;; Walk decls, build LLVM IR fragments.
  (define cell-decls       (filter cell-decl? nodes))
  (define write-decls      (filter write-decl? nodes))
  (define propagator-decls (filter propagator-decl? nodes))
  (define meta-decls       (filter meta-decl? nodes))

  ;; Map cell-decl id → SSA name for this @main scope.
  ;; Each cell-decl emits %cN where N is its id.
  (define (cell-ssa-name id)
    (format "%c~a" id))

  (define alloc-lines
    (for/list ([c (in-list cell-decls)])
      (define id (cell-decl-id c))
      (format "  ~a = call i32 @prologos_cell_alloc()" (cell-ssa-name id))))

  ;; init-value emission via cell-decl: if marshalable to i64, emit a write.
  (define (init-value->i64-or-error c)
    (define v (cell-decl-init-value c))
    (cond
      [(exact-integer? v) v]
      [(eq? v #t) 1]
      [(eq? v #f) 0]
      [else
       (unsupported! c
                     (format "init-value ~v is not i64-marshalable. Phase 2.C/D lowers only Int and Bool cells."
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

  ;; Phase 2.D: propagator-decl → prologos_propagator_install_{2_1,3_1} call.
  ;; Each install enqueues the propagator; the run_to_quiescence call
  ;; below drains the worklist before the entry-cell read.
  (define prop-lines
    (for/list ([p (in-list propagator-decls)])
      (define ins (propagator-decl-input-cells p))
      (define outs (propagator-decl-output-cells p))
      (unless (= (length outs) 1)
        (unsupported! p
                      (format "lowering supports single-output propagators only; got ~a outputs"
                              (length outs))))
      (cond
        [(= (length ins) 2)
         (define tag-id (lookup-fire-fn-tag-id (propagator-decl-fire-fn-tag p) '2-1 p))
         (format "  %p~a = call i32 @prologos_propagator_install_2_1(i32 ~a, i32 ~a, i32 ~a, i32 ~a)"
                 (propagator-decl-id p)
                 tag-id
                 (cell-ssa-name (car ins))
                 (cell-ssa-name (cadr ins))
                 (cell-ssa-name (car outs)))]
        [(= (length ins) 3)
         (define tag-id (lookup-fire-fn-tag-id (propagator-decl-fire-fn-tag p) '3-1 p))
         (format "  %p~a = call i32 @prologos_propagator_install_3_1(i32 ~a, i32 ~a, i32 ~a, i32 ~a, i32 ~a)"
                 (propagator-decl-id p)
                 tag-id
                 (cell-ssa-name (car ins))
                 (cell-ssa-name (cadr ins))
                 (cell-ssa-name (caddr ins))
                 (cell-ssa-name (car outs)))]
        [else
         (unsupported! p
                       (format "lowering supports only (2,1) and (3,1) shapes; got ~a inputs"
                               (length ins)))])))

  (define have-3-1? (for/or ([p (in-list propagator-decls)])
                      (= (length (propagator-decl-input-cells p)) 3)))

  ;; If any propagators were installed, emit a run-to-quiescence call
  ;; before reading the entry cell. (No propagators → constant network,
  ;; no scheduler invocation needed.)
  (define quiescence-line
    (if (null? propagator-decls)
        ""
        "  call void @prologos_run_to_quiescence()\n"))

  (define propagator-decls-non-empty? (not (null? propagator-decls)))

  ;; Module metadata from meta-decls (debug / diagnostic).
  (define meta-comment-lines
    (for/list ([m (in-list meta-decls)])
      (format "; meta: ~a = ~v" (meta-decl-key m) (meta-decl-value m))))

  ;; Always-present declarations.
  (define base-decls
    (string-append
     "declare i32 @prologos_cell_alloc()\n"
     "declare i64 @prologos_cell_read(i32)\n"
     "declare void @prologos_cell_write(i32, i64)\n"))

  ;; Conditionally-emitted declarations for the propagator API.
  (define prop-decls-text
    (if propagator-decls-non-empty?
        (string-append
         "declare i32 @prologos_propagator_install_2_1(i32, i32, i32, i32)\n"
         (if have-3-1?
             "declare i32 @prologos_propagator_install_3_1(i32, i32, i32, i32, i32)\n"
             "")
         "declare void @prologos_run_to_quiescence()\n")
        ""))

  ;; Assemble.
  (string-append
   "; ModuleID = 'prologos-low-pnet'\n"
   (format "target triple = \"~a\"\n" (default-target-triple))
   (format "; Low-PNet format version: ~a\n" version)
   (apply string-append
          (for/list ([l (in-list meta-comment-lines)]) (string-append l "\n")))
   "\n"
   base-decls
   prop-decls-text
   "\n"
   "define i64 @main() {\n"
   "entry:\n"
   (apply string-append
          (for/list ([l (in-list alloc-lines)]) (string-append l "\n")))
   (apply string-append
          (for/list ([l (in-list init-lines)]) (string-append l "\n")))
   (apply string-append
          (for/list ([l (in-list write-lines)]) (string-append l "\n")))
   (apply string-append
          (for/list ([l (in-list prop-lines)]) (string-append l "\n")))
   quiescence-line
   (format "  %r = call i64 @prologos_cell_read(i32 ~a)\n"
           (cell-ssa-name entry-cell-id))
   "  ret i64 %r\n"
   "}\n"))
