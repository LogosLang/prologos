#lang racket/base

;; test-llvm-lower.rkt — Tier 0–2 unit tests for racket/prologos/llvm-lower.rkt.
;;
;; Pure IR-string assertions; does NOT shell out to clang or run binaries.
;; Those are exercised by tools/llvm-test.rkt against examples/llvm/tier*/.

(require rackunit
         racket/string
         "../syntax.rkt"
         "../llvm-lower.rkt")

;; ============================================================
;; Tier 0
;; ============================================================

(parameterize ([current-llvm-tier 0])

  (test-case "tier 0: literal main exits with the literal"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int) (expr-int 42)))))
    (check-true (string-contains? ir "define i64 @main()")
                "must define @main")
    (check-true (string-contains? ir "ret i64 42")
                "must return the literal")
    (check-true (string-contains? ir "target triple")
                "must declare target triple"))

  (test-case "tier 0: zero exit"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int) (expr-int 0)))))
    (check-true (string-contains? ir "ret i64 0")))

  (test-case "tier 0: expr-ann around the body unwraps"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-ann (expr-int 7) (expr-Int))))))
    (check-true (string-contains? ir "ret i64 7")))

  (test-case "tier 0: non-Int type raises unsupported-llvm-node"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Bool) (expr-int 1)))))))

  (test-case "tier 0: arithmetic body raises (deferred to Tier 1)"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Int)
                     (expr-int-add (expr-int 1) (expr-int 2))))))))

  (test-case "tier 0: missing main raises"
    (check-exn exn:fail?
      (lambda ()
        (lower-program
         (list (list 'def 'foo (expr-Int) (expr-int 1)))))))

  (test-case "tier 0: multiple top-forms raise (Tier 2 territory)"
    (check-exn exn:fail?
      (lambda ()
        (lower-program
         (list (list 'def 'a (expr-Int) (expr-int 1))
               (list 'def 'main (expr-Int) (expr-int 2)))))))

  (test-case "tier 0: arithmetic raises with tier-aware hint"
    (define raised
      (with-handlers ([unsupported-llvm-node? values])
        (lower-program
         (list (list 'def 'main (expr-Int)
                     (expr-int-add (expr-int 1) (expr-int 2)))))
        #f))
    (check-true (unsupported-llvm-node? raised))
    (check-= (unsupported-llvm-node-tier raised) 0 0)
    (check-true (regexp-match? #rx"Tier 1" (exn-message raised))))
)

;; ============================================================
;; Tier 1
;; ============================================================

(parameterize ([current-llvm-tier 1])

  (test-case "tier 1: int+ inline literals"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-add (expr-int 1) (expr-int 2))))))
    (check-true (string-contains? ir "add i64 1, 2"))
    (check-true (regexp-match? #rx"%t1 = add i64" ir))
    (check-true (regexp-match? #rx"ret i64 %t1" ir)))

  (test-case "tier 1: nested arithmetic uses fresh SSA temps in dataflow order"
    ;; [int+ 1 [int* 2 3]] -> mul first, then add
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-add (expr-int 1)
                                 (expr-int-mul (expr-int 2) (expr-int 3)))))))
    (check-true (string-contains? ir "mul i64 2, 3"))
    (check-true (string-contains? ir "add i64 1, %t1"))
    (check-true (regexp-match? #rx"ret i64 %t2" ir)))

  (test-case "tier 1: int- emits sub"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-sub (expr-int 10) (expr-int 3))))))
    (check-true (string-contains? ir "sub i64 10, 3")))

  (test-case "tier 1: int/ emits sdiv (signed)"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-div (expr-int 100) (expr-int 4))))))
    (check-true (string-contains? ir "sdiv i64 100, 4")))

  (test-case "tier 1: int-mod emits srem (signed remainder)"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-mod (expr-int 100) (expr-int 7))))))
    (check-true (string-contains? ir "srem i64 100, 7")))

  (test-case "tier 1: int-neg emits sub i64 0, x"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-neg (expr-int 5))))))
    (check-true (string-contains? ir "sub i64 0, 5")))

  (test-case "tier 1: int-abs declares and calls @llvm.abs.i64"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-abs (expr-int 5))))))
    (check-true (string-contains? ir "declare i64 @llvm.abs.i64"))
    (check-true (string-contains? ir "call i64 @llvm.abs.i64(i64 5, i1 false)")))

  (test-case "tier 1: no abs => no declare"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Int)
                   (expr-int-add (expr-int 1) (expr-int 2))))))
    (check-false (string-contains? ir "declare i64 @llvm.abs.i64")))

  (test-case "tier 1: still rejects unsupported nodes (e.g. Bool comparison)"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Int)
                     (expr-int-lt (expr-int 1) (expr-int 2))))))))

  (test-case "tier 1: still rejects non-Int main type"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Bool) (expr-true)))))))
)
