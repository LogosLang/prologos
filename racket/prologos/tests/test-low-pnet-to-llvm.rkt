#lang racket/base

;; test-low-pnet-to-llvm.rkt — SH Track 2 Phase 2.C unit tests.
;;
;; Tests assert on emitted IR string contents (not on actual link/run;
;; that's exercised by tools/pnet-test or the pnet-compile e2e in CI).

(require rackunit
         racket/string
         "../low-pnet-ir.rkt"
         "../low-pnet-to-llvm.rkt")

;; ============================================================
;; N0-equivalent: 1 cell, init value 42
;; ============================================================

(test-case "1 cell with i64 init-value lowers to alloc + write + read + ret"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 42)
       (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "declare i32 @prologos_cell_alloc()"))
  (check-true (string-contains? ir "declare i64 @prologos_cell_read(i32)"))
  (check-true (string-contains? ir "declare void @prologos_cell_write(i32, i64)"))
  (check-true (string-contains? ir "%c0 = call i32 @prologos_cell_alloc()"))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c0, i64 42)"))
  (check-true (string-contains? ir "%r = call i64 @prologos_cell_read(i32 %c0)"))
  (check-true (string-contains? ir "ret i64 %r"))
  (check-true (string-contains? ir "define i64 @main()")))

(test-case "Bool cell with init-value #t emits 1; #f emits 0"
  (define lp-true
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 bool merge-bool 0 never)
       (cell-decl 0 0 #t)
       (entry-decl 0))))
  (define lp-false
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 bool merge-bool 0 never)
       (cell-decl 0 0 #f)
       (entry-decl 0))))
  (check-true (string-contains? (lower-low-pnet-to-llvm lp-true)
                                "i64 1"))
  (check-true (string-contains? (lower-low-pnet-to-llvm lp-false)
                                "call void @prologos_cell_write(i32 %c0, i64 0)")))

(test-case "multiple cells: each gets its own SSA name"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 1)
       (cell-decl 1 0 2)
       (cell-decl 2 0 3)
       (entry-decl 2))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "%c0 = call"))
  (check-true (string-contains? ir "%c1 = call"))
  (check-true (string-contains? ir "%c2 = call"))
  (check-true (string-contains? ir "i32 %c2)\n  ret i64 %r"))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c0, i64 1)"))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c1, i64 2)"))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c2, i64 3)")))

(test-case "write-decl emits an additional write"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 0)
       (write-decl 0 99 0)
       (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "i64 0)"))
  (check-true (string-contains? ir "i64 99)")))

;; ============================================================
;; Failure paths
;; ============================================================

;; Phase 2.D: propagator-decl lowering
(test-case "propagator-decl with kernel-int-add lowers to install_2_1"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl 0 0 1)
       (cell-decl 1 0 2)
       (cell-decl 2 0 0)
       (propagator-decl 0 (0 1) (2) kernel-int-add 0)
       (entry-decl 2))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "declare i32 @prologos_propagator_install_2_1"))
  (check-true (string-contains? ir "declare void @prologos_run_to_quiescence"))
  ;; tag id for kernel-int-add is 0
  (check-true (string-contains?
               ir
               "%p0 = call i32 @prologos_propagator_install_2_1(i32 0, i32 %c0, i32 %c1, i32 %c2)"))
  (check-true (string-contains? ir "call void @prologos_run_to_quiescence()")))

(test-case "kernel-int-sub/mul/div/mod have distinct tag ids"
  (for ([sym (in-list '(kernel-int-sub kernel-int-mul kernel-int-div kernel-int-mod))]
        [expected-id (in-list '(1 2 3 7))])
    (define lp
      (parse-low-pnet
       `(low-pnet
         (domain-decl 0 int kernel-merge-int 0 never)
         (cell-decl 0 0 0)
         (cell-decl 1 0 0)
         (cell-decl 2 0 0)
         (propagator-decl 0 (0 1) (2) ,sym 0)
         (entry-decl 2))))
    (define ir (lower-low-pnet-to-llvm lp))
    (check-true (string-contains?
                 ir
                 (format "install_2_1(i32 ~a," expected-id)))))

(test-case "(1,1) unary kernel-int-neg/abs lower to install_1_1 with tag 1/2"
  (for ([sym (in-list '(kernel-identity kernel-int-neg kernel-int-abs))]
        [expected-id (in-list '(0 1 2))])
    (define lp
      (parse-low-pnet
       `(low-pnet
         (domain-decl 0 int kernel-merge-int 0 never)
         (cell-decl 0 0 0)
         (cell-decl 1 0 0)
         (propagator-decl 0 (0) (1) ,sym 0)
         (entry-decl 1))))
    (define ir (lower-low-pnet-to-llvm lp))
    (check-true (string-contains?
                 ir
                 (format "install_1_1(i32 ~a," expected-id))
                (format "tag id for ~a should be ~a" sym expected-id))))

(test-case "propagator-decl with unknown tag raises unsupported"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl 0 0 0)
       (cell-decl 1 0 0)
       (cell-decl 2 0 0)
       (propagator-decl 0 (0 1) (2) some-user-tag 0)
       (entry-decl 2))))
  (check-exn unsupported-low-pnet-decl?
    (lambda () (lower-low-pnet-to-llvm lp))))

(test-case "propagator-decl with non-(2,1) shape raises unsupported"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl 0 0 0)
       (cell-decl 1 0 0)
       (propagator-decl 0 (0) (1) kernel-int-add 0)  ; only 1 input
       (entry-decl 1))))
  (check-exn unsupported-low-pnet-decl?
    (lambda () (lower-low-pnet-to-llvm lp))))

(test-case "no-propagator program does NOT emit propagator decls/calls"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int kernel-merge-int 0 never)
       (cell-decl 0 0 42)
       (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-false (string-contains? ir "prologos_propagator_install_2_1"))
  (check-false (string-contains? ir "prologos_run_to_quiescence")))

(test-case "cell with non-marshalable init-value raises unsupported"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 phase-2b-placeholder)  ;; symbol, not i64
       (entry-decl 0))))
  (check-exn unsupported-low-pnet-decl?
    (lambda () (lower-low-pnet-to-llvm lp))))

(test-case "lower-low-pnet-to-llvm rejects malformed Low-PNet"
  ;; missing entry-decl
  (define lp
    (parse-low-pnet
     '(low-pnet
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 0))))
  (check-exn exn:fail?
    (lambda () (lower-low-pnet-to-llvm lp))))

;; ============================================================
;; Meta-decl
;; ============================================================

(test-case "meta-decl emits a comment in the IR (debug)"
  (define lp
    (parse-low-pnet
     '(low-pnet
       (meta-decl source-file "test.prologos")
       (domain-decl 0 int merge-int 0 never)
       (cell-decl 0 0 7)
       (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "source-file")))

;; ============================================================
;; kernel-PU Phase 5 Day 11: write-decl mode dispatch
;; ============================================================

(test-case "Day 11: 'merge mode emits @prologos_cell_write (default)"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int merge-int 0 never)
                (cell-decl 0 0 0)
                (write-decl 0 99 0 merge)
                (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c0, i64 99)"))
  ;; cell_reset declaration not emitted unless used
  (check-false (string-contains? ir "@prologos_cell_reset")))

(test-case "Day 11: 'reset mode emits @prologos_cell_reset (with declaration)"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int merge-int 0 never)
                (cell-decl 0 0 0)
                (write-decl 0 7 0 reset)
                (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "declare void @prologos_cell_reset(i32, i64)"))
  (check-true (string-contains? ir "call void @prologos_cell_reset(i32 %c0, i64 7)"))
  ;; cell_write still emitted for the cell-decl init
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c0, i64 0)")))

(test-case "Day 11: V1.0 IR (no mode tag) round-trips with cell_write only"
  ;; Pre-Day-8 IR shape: 3-arg write-decl. Parser defaults mode to 'merge,
  ;; so emission is unchanged.
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 0)
                (domain-decl 0 int merge-int 0 never)
                (cell-decl 0 0 0)
                (write-decl 0 11 0)
                (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c0, i64 11)"))
  (check-false (string-contains? ir "@prologos_cell_reset")))

(test-case "Day 11: mixed merge + reset writes coexist"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int merge-int 0 never)
                (cell-decl 0 0 0)
                (cell-decl 1 0 0)
                (write-decl 0 1 0 merge)
                (write-decl 1 2 0 reset)
                (entry-decl 1))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "declare void @prologos_cell_reset(i32, i64)"))
  (check-true (string-contains? ir "call void @prologos_cell_write(i32 %c0, i64 1)"))
  (check-true (string-contains? ir "call void @prologos_cell_reset(i32 %c1, i64 2)")))

;; ============================================================
;; kernel-PU Phase 5 Day 11: scope-API declaration emission
;; ============================================================

(test-case "Day 11: scope APIs NOT declared by default"
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (domain-decl 0 int merge-int 0 never)
                (cell-decl 0 0 7)
                (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-false (string-contains? ir "@prologos_scope_enter"))
  (check-false (string-contains? ir "@prologos_scope_run"))
  (check-false (string-contains? ir "@prologos_scope_read"))
  (check-false (string-contains? ir "@prologos_scope_exit")))

(test-case "Day 11: meta-decl uses-scope-apis triggers scope-API declarations"
  ;; Day 12 Category-C migrations (NAF + run-stratified-resolution-pure)
  ;; will emit IR with this meta. Until then, the opt-in lets future
  ;; passes turn on the declarations without touching low-pnet-to-llvm.
  (define lp (parse-low-pnet
              '(low-pnet
                :version (1 1)
                (meta-decl uses-scope-apis #t)
                (domain-decl 0 int merge-int 0 never)
                (cell-decl 0 0 7)
                (entry-decl 0))))
  (define ir (lower-low-pnet-to-llvm lp))
  (check-true (string-contains? ir "declare i32 @prologos_scope_enter(i64)"))
  (check-true (string-contains? ir "declare i8 @prologos_scope_run(i32, i64)"))
  (check-true (string-contains? ir "declare i64 @prologos_scope_read(i32, i32)"))
  (check-true (string-contains? ir "declare void @prologos_scope_exit(i32)")))
