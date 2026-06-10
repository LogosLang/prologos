#lang racket/base
;; PCE/1 tests — PReduce Track 1 (D.3 §2 identity package; ledger iter 7).
(require rackunit racket/string racket/runtime-path
         "../pce.rkt"
         "../syntax.rkt")

(define (gdig v) (pce-digest PCE-KIND-GROUND-TERM v))

;; determinism: separately-constructed structurally-equal terms → same digest
(check-equal? (gdig (expr-app (expr-bvar 0) (expr-int 42)))
              (gdig (expr-app (expr-bvar 0) (expr-int 42))))
(check-equal? (gdig (expr-lam 'm1 (expr-Int) (expr-bvar 0)))
              (gdig (expr-lam 'm1 (expr-Int) (expr-bvar 0))))

;; distinctness: different terms → different digests
(check-not-equal? (gdig (expr-int 42)) (gdig (expr-int 43)))
(check-not-equal? (gdig (expr-bvar 0)) (gdig (expr-bvar 1)))
(check-not-equal? (gdig (expr-int -7)) (gdig (expr-int 7)))
(check-not-equal? (gdig (expr-lam 'm1 (expr-Int) (expr-bvar 0)))
                  (gdig (expr-lam 'mw (expr-Int) (expr-bvar 0))))

;; kind-byte domain separation: same payload, different kind → different digest
(check-not-equal? (pce-digest PCE-KIND-GROUND-TERM (expr-int 42))
                  (pce-digest PCE-KIND-EFFECTFUL-SESSION (expr-int 42)))

;; persisted-domain guard (D.3 §2 closure iv): effectful-session NEVER persists
(check-exn exn:fail?
  (lambda () (pce-persistable-digest PCE-KIND-EFFECTFUL-SESSION (expr-int 1))))
(check-not-exn
  (lambda () (pce-persistable-digest PCE-KIND-GROUND-TERM (expr-int 1))))

;; admission guards: uninterned symbols + inexact floats are OUTSIDE the domain
(check-exn exn:fail? (lambda () (gdig (gensym 'nope))))
(check-exn exn:fail? (lambda () (gdig 3.14)))

;; hash insertion-order independence (sorted by encoded-key bytes)
(check-equal? (gdig (hasheq 'a 1 'b 2 'c 3))
              (gdig (hash-set (hash-set (hash-set (hasheq) 'c 3) 'a 1) 'b 2)))

;; bignum-safe integers
(check-equal? (gdig (expr-int (expt 2 128))) (gdig (expr-int (expt 2 128))))
(check-not-equal? (gdig (expr-int (expt 2 128))) (gdig (expr-int (add1 (expt 2 128)))))

;; exact rationals
(check-equal? (gdig 22/7) (gdig 22/7))
(check-not-equal? (gdig 22/7) (gdig 22/8))  ;; note: 22/8 normalizes to 11/4

;; golden vectors: recompute and compare against the committed artifact
(define-runtime-path gv-path "../data/pce-golden-vectors-v1.txt")
(check-true (file-exists? gv-path) "golden vectors artifact must exist")
(when (file-exists? gv-path)
  (define lines (with-input-from-file gv-path
                  (lambda () (for/list ([l (in-lines)]) l))))
  (define expected
    (for/hash ([l (in-list lines)]
               #:when (and (non-empty-string? l)
                           (not (string-prefix? l "PCE/"))
                           (not (string-prefix? l ";;"))))
      (define parts (string-split l " "))
      (values (car parts) (cadr parts))))
  (define terms
    (hash "int-42"    (expr-int 42)
          "bvar-0"    (expr-bvar 0)
          "lam-id"    (expr-lam 'm1 (expr-Int) (expr-bvar 0))
          "app"       (expr-app (expr-bvar 0) (expr-int 42))
          "symbol"    'hello
          "rational"  22/7))
  (for ([(name term) (in-hash terms)])
    (check-equal? (pce-hex (gdig term)) (hash-ref expected name)
                  (format "golden vector ~a" name))))
