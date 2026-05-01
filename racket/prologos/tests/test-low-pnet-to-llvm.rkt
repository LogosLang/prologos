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

(test-case "kernel-int-sub/mul/div have distinct tag ids"
  (for ([sym (in-list '(kernel-int-sub kernel-int-mul kernel-int-div))]
        [expected-id (in-list '(1 2 3))])
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
