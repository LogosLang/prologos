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

  (test-case "tier 0: non-Int/Bool type raises unsupported-llvm-node"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Type 0) (expr-int 1)))))))

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

  (test-case "tier 1: still rejects non-Int/Bool main type"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Type 0) (expr-int 1)))))))
)

;; ============================================================
;; Tier 2 — top-level functions, calls, m0 erasure
;; ============================================================

(parameterize ([current-llvm-tier 2])

  ;; ---- Helpers to build canonical Tier 2 fixtures ----

  ;; add(x : Int, y : Int) : Int
  (define add-type
    (expr-Pi 'mw (expr-Int) (expr-Pi 'mw (expr-Int) (expr-Int))))
  (define add-body
    (expr-lam 'mw (expr-Int)
      (expr-lam 'mw (expr-Int)
        (expr-int-add (expr-bvar 1) (expr-bvar 0)))))

  ;; id : {A : Type} A -> A   (m0 type binder + mw value binder)
  (define id-type
    (expr-Pi 'm0 (expr-Type 0)
      (expr-Pi 'mw (expr-bvar 0) (expr-bvar 1))))
  (define id-body
    (expr-lam 'm0 (expr-Type 0)
      (expr-lam 'mw (expr-bvar 0) (expr-bvar 0))))

  (test-case "tier 2: simple call to add"
    (define main-body
      (expr-app (expr-app (expr-fvar 'add) (expr-int 5)) (expr-int 7)))
    (define ir
      (lower-program
       (list (list 'def 'add add-type add-body)
             (list 'def 'main (expr-Int) main-body))))
    (check-true (string-contains? ir "define i64 @p_add(i64 %p0, i64 %p1)")
                "function definition with two i64 params")
    (check-true (string-contains? ir "%t1 = add i64 %p0, %p1")
                "body uses param SSA names in correct de Bruijn order")
    (check-true (regexp-match? #rx"= call i64 @p_add\\(i64 5, i64 7\\)" ir)
                "main calls add with literals"))

  (test-case "tier 2: m0 binder dropped from signature"
    ;; main calls id with implicit Type arg + Int value
    (define main-body
      (expr-app (expr-app (expr-fvar 'id) (expr-Int)) (expr-int 99)))
    (define ir
      (lower-program
       (list (list 'def 'id id-type id-body)
             (list 'def 'main (expr-Int) main-body))))
    (check-true (string-contains? ir "define i64 @p_id(i64 %p1)")
                "id has only the value param, m0 type binder is erased")
    (check-true (string-contains? ir "ret i64 %p1")
                "id returns its value param")
    (check-true (regexp-match? #rx"= call i64 @p_id\\(i64 99\\)" ir)
                "call site passes only the value arg"))

  (test-case "tier 2: closure capture rejected"
    ;; A body that reaches into a non-existent outer scope.
    ;; bvar 5 in a nullary main body has no enclosing binder.
    (define bad-main
      (list 'def 'main (expr-Int) (expr-bvar 5)))
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program (list bad-main)))))

  (test-case "tier 2: erased binder used at runtime is rejected"
    ;; A function whose body uses bvar pointing at the m0 type binder.
    (define bad-id-type
      (expr-Pi 'm0 (expr-Type 0) (expr-Int)))
    (define bad-id-body
      (expr-lam 'm0 (expr-Type 0) (expr-bvar 0)))  ; body references the m0 binder
    (define main-body
      (expr-app (expr-fvar 'bad-id) (expr-Int)))
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'bad-id bad-id-type bad-id-body)
               (list 'def 'main (expr-Int) main-body))))))

  (test-case "tier 2: arity mismatch in call rejected"
    (define main-body
      (expr-app (expr-fvar 'add) (expr-int 5))) ; only 1 arg, add wants 2
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'add add-type add-body)
               (list 'def 'main (expr-Int) main-body))))))

  (test-case "tier 2: unknown function rejected"
    (define main-body
      (expr-app (expr-fvar 'no-such-fn) (expr-int 5)))
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Int) main-body))))))

  (test-case "tier 2: bare expr-fvar (function-as-value) rejected"
    ;; main := add  (would need closure conversion)
    (define main-body (expr-fvar 'add))
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'add add-type add-body)
               (list 'def 'main (expr-Int) main-body))))))

  (test-case "tier 2: nested call inside arithmetic"
    (define main-body
      (expr-int-add (expr-app (expr-app (expr-fvar 'add) (expr-int 1)) (expr-int 2))
                    (expr-int 100)))
    (define ir
      (lower-program
       (list (list 'def 'add add-type add-body)
             (list 'def 'main (expr-Int) main-body))))
    (check-true (string-contains? ir "= call i64 @p_add(i64 1, i64 2)"))
    (check-true (regexp-match? #rx"add i64 %t[0-9]+, 100" ir)))
)

;; ============================================================
;; Tier 3 — Bool, comparisons, conditionals
;; ============================================================

(parameterize ([current-llvm-tier 3])

  (test-case "tier 3: Bool literals lower as i64 0/1"
    (define ir-true
      (lower-program (list (list 'def 'main (expr-Bool) (expr-true)))))
    (define ir-false
      (lower-program (list (list 'def 'main (expr-Bool) (expr-false)))))
    (check-true (string-contains? ir-true "ret i64 1"))
    (check-true (string-contains? ir-false "ret i64 0")))

  (test-case "tier 3: int-eq emits icmp + zext"
    (define ir
      (lower-program
       (list (list 'def 'main (expr-Bool)
                   (expr-int-eq (expr-int 7) (expr-int 7))))))
    (check-true (string-contains? ir "icmp eq i64 7, 7"))
    (check-true (regexp-match? #rx"zext i1 %t[0-9]+ to i64" ir)))

  (test-case "tier 3: int-lt and int-le emit slt and sle"
    (define ir-lt
      (lower-program
       (list (list 'def 'main (expr-Bool)
                   (expr-int-lt (expr-int 1) (expr-int 2))))))
    (define ir-le
      (lower-program
       (list (list 'def 'main (expr-Bool)
                   (expr-int-le (expr-int 2) (expr-int 2))))))
    (check-true (string-contains? ir-lt "icmp slt i64 1, 2"))
    (check-true (string-contains? ir-le "icmp sle i64 2, 2")))

  (test-case "tier 3: expr-boolrec emits br i1 + 2 arms + phi"
    ;; if (1==0) then 99 else 7 — should pick 7
    (define body
      (expr-boolrec (expr-Bool)
                    (expr-int 99) (expr-int 7)
                    (expr-int-eq (expr-int 1) (expr-int 0))))
    (define ir
      (lower-program (list (list 'def 'main (expr-Int) body))))
    (check-true (regexp-match? #rx"icmp ne i64" ir)
                "boolrec target wrapped with icmp ne 0")
    (check-true (regexp-match? #rx"br i1 %t[0-9]+, label %true_[0-9]+, label %false_[0-9]+" ir))
    (check-true (regexp-match? #rx"true_[0-9]+:" ir))
    (check-true (regexp-match? #rx"false_[0-9]+:" ir))
    (check-true (regexp-match? #rx"join_[0-9]+:" ir))
    (check-true (regexp-match? #rx"phi i64 \\[99, %true_[0-9]+\\], \\[7, %false_[0-9]+\\]" ir)))

  (test-case "tier 3: expr-reduce on Bool dispatches to true/false arms by tag"
    ;; pick true arm value (42) via reduce on (true)
    (define body
      (expr-reduce (expr-true)
                   (list (expr-reduce-arm 'false 0 (expr-int 7))
                         (expr-reduce-arm 'true 0 (expr-int 42)))
                   #t))  ;; arm order intentionally reversed; lookup is by tag
    (define ir
      (lower-program (list (list 'def 'main (expr-Int) body))))
    (check-true (regexp-match? #rx"phi i64 \\[42, %true_[0-9]+\\], \\[7, %false_[0-9]+\\]" ir)))

  (test-case "tier 3: expr-reduce missing an arm raises"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Int)
                     (expr-reduce (expr-true)
                                  (list (expr-reduce-arm 'true 0 (expr-int 1)))
                                  #t)))))))

  (test-case "tier 3: expr-reduce-arm with binding-count > 0 raises (Tier 4 territory)"
    (check-exn unsupported-llvm-node?
      (lambda ()
        (lower-program
         (list (list 'def 'main (expr-Int)
                     (expr-reduce (expr-true)
                                  (list (expr-reduce-arm 'true 1 (expr-int 1))
                                        (expr-reduce-arm 'false 0 (expr-int 0)))
                                  #t)))))))

  (test-case "tier 3: let-binding via (expr-app (expr-lam ...) arg) extends env"
    ;; let x = 99 in x + 1   -- with x as bvar 0
    (define body
      (expr-app
       (expr-lam 'mw (expr-Int)
         (expr-int-add (expr-bvar 0) (expr-int 1)))
       (expr-int 99)))
    (define ir
      (lower-program (list (list 'def 'main (expr-Int) body))))
    (check-true (string-contains? ir "add i64 99, 1")
                "let-binding folds the arg literal into the body's reference"))

  (test-case "tier 3: m0 let-binding does not evaluate its arg"
    ;; (\m0 x : Type . 7) Int  -- should yield 7, no evaluation of Int
    (define body
      (expr-app
       (expr-lam 'm0 (expr-Type 0) (expr-int 7))
       (expr-Int)))  ; the m0 arg is a type expression that we should NOT lower
    (define ir
      (lower-program (list (list 'def 'main (expr-Int) body))))
    (check-true (string-contains? ir "ret i64 7")))
)
