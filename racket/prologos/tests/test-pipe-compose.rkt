#lang racket/base

;;;
;;; Unit/Preparse Tests for Phase 2c: Pipe (|>) and Compose (>>) Operators
;;;
;;; Fast tests only — reader tokenization, preparse desugaring, edge cases.
;;; E2E tests are in test-pipe-compose-e2e.rkt (split for performance).
;;; See docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md
;;;
;;; |> threads a value through a pipeline: x |> f |> g → g(f(x))
;;; >> composes functions left-to-right: f >> g → (fn x -> g(f(x)))
;;; _ in pipe step = placeholder: x |> insert _ table → insert x table
;;;

(require rackunit
         racket/string
         "../macros.rkt"
         "../parse-reader.rkt")

;; ========================================
;; A. Reader Tokenization (6 tests)
;; ========================================

(test-case "reader/|>: tokenizes as $pipe-gt"
  (define toks (tokenize-string "x |> f"))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$pipe-gt)) toks)))

(test-case "reader/>>: tokenizes as $compose"
  (define toks (tokenize-string "f >> g"))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$compose)) toks)))

(test-case "reader/|: bare pipe still $pipe"
  (define toks (tokenize-string "A | B"))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$pipe)) toks))
  (check-false (ormap (lambda (t) (eq? (token-value t) '$pipe-gt)) toks)))

(test-case "reader/<>: angle brackets unaffected"
  (define toks (tokenize-string "x <Nat>"))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'langle)) toks))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'rangle)) toks)))

(test-case "reader/>>-in-brackets: >> works inside [] brackets"
  (define toks (tokenize-string "[suc >> suc]"))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$compose)) toks)))

(test-case "reader/mixed: |> and >> coexist with <>"
  (define toks (tokenize-string "x <Nat> |> f >> g"))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$pipe-gt)) toks))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$compose)) toks))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'rangle)) toks)))

;; ========================================
;; B. Preparse Desugaring (8 tests)
;; ========================================

(test-case "preparse/pipe-simple: x |> f → (f x)"
  (define result (preparse-expand-form '(x $pipe-gt f)))
  (check-equal? result '(f x)))

(test-case "preparse/pipe-multi-arg: x |> f a b → (f a b x)"
  (define result (preparse-expand-form '(x $pipe-gt f a b)))
  (check-equal? result '(f a b x)))

(test-case "preparse/pipe-chain: data |> f |> g → (g (f data))"
  (define result (preparse-expand-form '(data $pipe-gt f $pipe-gt g)))
  (check-equal? result '(g (f data))))

(test-case "preparse/pipe-chain-multi: data |> f a |> g b → (g b (f a data))"
  (define result (preparse-expand-form '(data $pipe-gt f a $pipe-gt g b)))
  (check-equal? result '(g b (f a data))))

(test-case "preparse/pipe-underscore: x |> insert _ table → (insert x table)"
  (define result (preparse-expand-form '(x $pipe-gt insert _ table)))
  (check-equal? result '(insert x table)))

(test-case "preparse/compose-simple: f >> g → lambda"
  (define result (preparse-expand-form '(f $compose g)))
  (check-equal? result '(fn ($>>0 : _) (g (f $>>0)))))

(test-case "preparse/compose-chain: f >> g >> h → lambda"
  (define result (preparse-expand-form '(f $compose g $compose h)))
  (check-equal? result '(fn ($>>0 : _) (h (g (f $>>0))))))

(test-case "preparse/sexp-pipe: ($pipe-gt data f g) → (g (f data))"
  (define result (preparse-expand-form '($pipe-gt data f g)))
  (check-equal? result '(g (f data))))

;; ========================================
;; F. Underscore Placeholder in Pipe (4 tests)
;; ========================================

(test-case "preparse/pipe-underscore-first: x |> f _ b → (f x b)"
  (define result (preparse-expand-form '(x $pipe-gt f _ b)))
  (check-equal? result '(f x b)))

(test-case "preparse/pipe-underscore-middle: x |> f a _ b → (f a x b)"
  (define result (preparse-expand-form '(x $pipe-gt f a _ b)))
  (check-equal? result '(f a x b)))

(test-case "preparse/pipe-sublist-underscore: _ inside [] is NOT pipe placeholder"
  (define result (preparse-expand-form '(xs $pipe-gt map (_ a b))))
  (check-equal? result '(map (_ a b) xs)))

(test-case "preparse/pipe-no-double-underscore: multiple _ errors"
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(x $pipe-gt f _ _ b)))))

;; ========================================
;; G. Edge Cases — Preparse Only (3 tests)
;; ========================================

(test-case "preparse/compose-preserves-args: f a >> g b"
  (define result (preparse-expand-form '(f a $compose g b)))
  (check-equal? result '(fn ($>>0 : _) (g b (f a $>>0)))))

(test-case "preparse/pipe-single-atom-step: x |> f → (f x)"
  (define result (preparse-expand-form '(x $pipe-gt f)))
  (check-equal? result '(f x)))

(test-case "preparse/compose-single-pair: f >> g"
  (define result (preparse-expand-form '(f $compose g)))
  (check-equal? result '(fn ($>>0 : _) (g (f $>>0)))))

;; ========================================
;; H. Backward Compatibility (3 tests)
;; ========================================

(test-case "compat/bare-pipe-union: bare | still works for union types"
  (define toks (tokenize-string "A | B"))
  (define pipe-toks (filter (lambda (t) (eq? (token-value t) '$pipe)) toks))
  (check-true (= (length pipe-toks) 1)))

(test-case "compat/bare-pipe-match: bare | in match arms"
  (define toks (tokenize-string "match x\n  zero -> true\n  | suc n -> false"))
  (define pipe-toks (filter (lambda (t) (eq? (token-value t) '$pipe)) toks))
  (check-true (>= (length pipe-toks) 1)))

(test-case "compat/angle-brackets-with-compose: <Nat> and >> coexist"
  (define toks (tokenize-string "x <Nat> |> [suc >> suc]"))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'langle)) toks))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'rangle)) toks))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$pipe-gt)) toks))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$compose)) toks)))

;; ========================================
;; I. Block-Form Pipe: Preparse-Level Fusion Tests (22 tests)
;; ========================================
;; Fusible chains ending with a terminal (reduce, sum, length, count) are fused into
;; a single reduce call with an inline composed reducer (O(n) single-pass).
;; Fusible chains without a terminal are materialized via sequential ops (map/filter).
;; The preparse layer expands `if` → `boolrec` and `let` → `fn`, so fused reducers
;; contain those forms.

(define (datum->string d) (format "~s" d))
(define (datum-contains? d sym)
  (string-contains? (datum->string d) (symbol->string sym)))

(test-case "preparse/block-pipe-no-steps: ($pipe-gt xs) → xs"
  (define result (preparse-expand-form '($pipe-gt xs)))
  (check-equal? result 'xs))

(test-case "preparse/block-pipe-single-map: ($pipe-gt xs (map f)) → (map f xs)"
  (define result (preparse-expand-form '($pipe-gt xs (map f))))
  (check-equal? result '(map f xs)))

(test-case "preparse/block-pipe-single-filter: ($pipe-gt xs (filter p)) → (filter p xs)"
  (define result (preparse-expand-form '($pipe-gt xs (filter p))))
  (check-equal? result '(filter p xs)))

(test-case "preparse/block-pipe-single-remove: ($pipe-gt xs (remove p)) → (remove p xs)"
  (define result (preparse-expand-form '($pipe-gt xs (remove p))))
  (check-equal? result '(remove p xs)))

(test-case "preparse/block-pipe-materialize-2: map + filter → sequential"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (filter p))))
  (check-equal? result '(filter p (map f xs))))

(test-case "preparse/block-pipe-materialize-3: map + filter + map → sequential"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (filter p) (map g))))
  (check-equal? result '(map g (filter p (map f xs)))))

(test-case "preparse/block-pipe-fuse-reduce: fusible + reduce → single fused reduce"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (filter p) (reduce rf z))))
  (check-true (pair? result))
  (check-equal? (car result) 'reduce)
  (check-true (datum-contains? result 'rf))
  (check-equal? (caddr result) 'z)
  (check-equal? (cadddr result) 'xs))

(test-case "preparse/block-pipe-fuse-sum: filter + sum → single fused reduce"
  (define result (preparse-expand-form '($pipe-gt xs (filter p) (sum))))
  (check-equal? (car result) 'reduce)
  (check-true (datum-contains? result 'add))
  (check-equal? (caddr result) 'zero)
  (check-equal? (cadddr result) 'xs))

(test-case "preparse/block-pipe-reduce-no-fusion: reduce without fusible → plain apply"
  (define result (preparse-expand-form '($pipe-gt xs (reduce + 0))))
  (check-equal? result '(reduce + 0 xs)))

(test-case "preparse/block-pipe-sum-no-fusion: sum without fusible → plain apply"
  (define result (preparse-expand-form '($pipe-gt xs (sum))))
  (check-equal? result '(sum xs)))

(test-case "preparse/block-pipe-barrier-breaks-fusion: map + sort + filter → sequential"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (sort cmp) (filter p))))
  (check-equal? result '(filter p (sort cmp (map f xs)))))

(test-case "preparse/block-pipe-barrier-then-terminal: map + sort + reduce"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (sort cmp) (reduce + 0))))
  (check-equal? result '(reduce + 0 (sort cmp (map f xs)))))

(test-case "preparse/block-pipe-plain-step: ($pipe-gt xs (foo a b)) → (foo a b xs)"
  (define result (preparse-expand-form '($pipe-gt xs (foo a b))))
  (check-equal? result '(foo a b xs)))

(test-case "preparse/block-pipe-underscore-plain: ($pipe-gt xs (get-in _ path)) → (get-in xs path)"
  (define result (preparse-expand-form '($pipe-gt xs (get-in _ path))))
  (check-equal? result '(get-in xs path)))

(test-case "preparse/block-pipe-bare-symbol: ($pipe-gt xs suc) → (suc xs)"
  (define result (preparse-expand-form '($pipe-gt xs suc)))
  (check-equal? result '(suc xs)))

(test-case "preparse/block-pipe-mixed: fusible + barrier + fusible → sequential"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (reverse) (filter p))))
  (check-equal? result '(filter p (reverse (map f xs)))))

(test-case "preparse/block-pipe-count-terminal: fusible + count → fused reduce"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (count p))))
  (check-equal? (car result) 'reduce)
  (check-true (datum-contains? result 'suc))
  (check-equal? (caddr result) 'zero))

(test-case "preparse/block-pipe-length-no-fusion: length without fusible → plain apply"
  (define result (preparse-expand-form '($pipe-gt xs (length))))
  (check-equal? result '(length _ xs)))

(test-case "preparse/block-pipe-terminal-must-be-last: error after terminal"
  (check-exn exn:fail?
    (lambda ()
      (preparse-expand-form '($pipe-gt xs (reduce + 0) (map f))))))

(test-case "preparse/block-pipe-infix-compat: x |> f |> g still works"
  (define result (preparse-expand-form '(x $pipe-gt f $pipe-gt g)))
  (check-equal? result '(g (f x))))

(test-case "preparse/block-pipe-infix-multi-arg: x |> f a → (f a x)"
  (define result (preparse-expand-form '(x $pipe-gt f a)))
  (check-equal? result '(f a x)))
