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
)
