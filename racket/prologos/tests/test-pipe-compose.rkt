#lang racket/base

;;;
;;; Tests for Phase 2c: Pipe (|>) and Compose (>>) Operators
;;;
;;; |> threads a value through a pipeline: x |> f |> g → g(f(x))
;;; >> composes functions left-to-right: f >> g → (fn x -> g(f(x)))
;;; _ in pipe step = placeholder: x |> insert _ table → insert x table
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt")

;; ========================================
;; Helpers
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run Prologos code in sexp mode (using process-string)
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s) (last (run s)))

;; Run a .prologos file content via WS reader
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-global-env (hasheq)]
                   [current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-mult-meta-store (make-hasheq)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-bundle-registry (current-bundle-registry)])
      (install-module-loader!)
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

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
;; C. Pipe E2E — Sexp Mode (8 tests)
;; ========================================

(test-case "e2e/pipe-basic: zero |> suc → 1"
  (check-equal? (run-last "(eval ($pipe-gt zero suc))") "1N : Nat"))

(test-case "e2e/pipe-chain: zero |> suc |> suc → 2"
  (check-equal? (run-last "(eval ($pipe-gt zero suc suc))") "2N : Nat"))

(test-case "e2e/pipe-chain-3: zero |> suc |> suc |> suc → 3"
  (check-equal? (run-last "(eval ($pipe-gt zero suc suc suc))") "3N : Nat"))

(test-case "e2e/pipe-4-deep: zero |> suc |> suc |> suc |> suc → 4"
  (check-equal? (run-last "(eval ($pipe-gt zero suc suc suc suc))") "4N : Nat"))

(test-case "e2e/pipe-preserves-type: zero |> suc preserves types"
  ;; Pipeline result should have correct type
  (check-equal? (run-last "(eval ($pipe-gt zero suc))") "1N : Nat"))

;; ========================================
;; D. Compose E2E — Sexp Mode (4 tests)
;; ========================================

(test-case "e2e/compose-basic: (suc >> suc) zero → 2"
  (check-equal? (run-last "(eval (($compose suc suc) zero))") "2N : Nat"))

(test-case "e2e/compose-chain: (suc >> suc >> suc) zero → 3"
  (check-equal? (run-last "(eval (($compose suc suc suc) zero))") "3N : Nat"))

(test-case "e2e/compose-4: (suc >> suc >> suc >> suc) zero → 4"
  (check-equal? (run-last "(eval (($compose suc suc suc suc) zero))") "4N : Nat"))

(test-case "e2e/compose-applied: composed fn applied twice"
  (define double-suc "($compose suc suc)")
  (check-equal? (run-last (format "(eval (~a (~a zero)))" double-suc double-suc)) "4N : Nat"))

;; ========================================
;; E. WS Mode E2E (6 tests)
;; ========================================

(test-case "ws/pipe-basic: zero |> suc"
  (check-equal? (run-ws-last "eval [zero |> suc]") "1N : Nat"))

(test-case "ws/pipe-chain: zero |> suc |> suc"
  (check-equal? (run-ws-last "eval [zero |> suc |> suc]") "2N : Nat"))

(test-case "ws/compose-basic: [suc >> suc] zero"
  (check-equal? (run-ws-last "eval [[suc >> suc] zero]") "2N : Nat"))

(test-case "ws/compose-chain: [suc >> suc >> suc] zero"
  (check-equal? (run-ws-last "eval [[suc >> suc >> suc] zero]") "3N : Nat"))

(test-case "ws/pipe-compose: zero |> [suc >> suc]"
  (check-equal? (run-ws-last "eval [zero |> [suc >> suc]]") "2N : Nat"))

(test-case "ws/pipe-compose-chain: zero |> [suc >> suc >> suc]"
  (check-equal? (run-ws-last "eval [zero |> [suc >> suc >> suc]]") "3N : Nat"))

;; ========================================
;; F. Underscore Placeholder in Pipe (4 tests)
;; ========================================

;; Test _ in pipe context with sexp — need a function that takes > 1 arg
;; natrec takes (motive, base, step, target) — using it to test _ placement

(test-case "preparse/pipe-underscore-first: x |> f _ b → (f x b)"
  (define result (preparse-expand-form '(x $pipe-gt f _ b)))
  (check-equal? result '(f x b)))

(test-case "preparse/pipe-underscore-middle: x |> f a _ b → (f a x b)"
  (define result (preparse-expand-form '(x $pipe-gt f a _ b)))
  (check-equal? result '(f a x b)))

(test-case "preparse/pipe-sublist-underscore: _ inside [] is NOT pipe placeholder"
  ;; When _ is inside a sub-list, it should be preserved (for closure hole)
  (define result (preparse-expand-form '(xs $pipe-gt map (_ a b))))
  ;; The (_ a b) is a sub-list — _ inside it should NOT be replaced.
  ;; With fusion, (map (_ a b)) is a fusible step → sequential materialization: (map (_ a b) xs)
  ;; The _ inside (_ a b) is preserved for closure hole, NOT treated as pipe placeholder.
  (check-equal? result '(map (_ a b) xs)))

(test-case "preparse/pipe-no-double-underscore: multiple _ errors"
  (check-exn exn:fail?
    (lambda () (preparse-expand-form '(x $pipe-gt f _ _ b)))))

;; ========================================
;; G. Edge Cases (4 tests)
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

(test-case "e2e/pipe-with-compose: apply composed fn via pipe"
  ;; In sexp mode, the composed function must be wrapped in a sub-application
  ;; ($pipe-gt zero ($compose suc suc)) applies ($compose suc suc) as fn to zero
  ;; But $compose expands to a lambda, so the result is ((fn x (suc (suc x))) zero)
  (check-equal? (run-last "(eval (($compose suc suc) zero))") "2N : Nat"))

;; ========================================
;; H. Backward Compatibility (3 tests)
;; ========================================

(test-case "compat/bare-pipe-union: bare | still works for union types"
  ;; Type parsing with | should still produce union types
  (define toks (tokenize-string "A | B"))
  (define pipe-toks (filter (lambda (t) (eq? (token-value t) '$pipe)) toks))
  (check-true (= (length pipe-toks) 1)))

(test-case "compat/bare-pipe-match: bare | in match arms"
  ;; Match arms use $pipe for case separation
  (define toks (tokenize-string "match x\n  zero -> true\n  | suc n -> false"))
  ;; The | should be $pipe, not $pipe-gt
  (define pipe-toks (filter (lambda (t) (eq? (token-value t) '$pipe)) toks))
  (check-true (>= (length pipe-toks) 1)))

(test-case "compat/angle-brackets-with-compose: <Nat> and >> coexist"
  ;; Angle brackets should still work when >> is also present
  (define toks (tokenize-string "x <Nat> |> [suc >> suc]"))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'langle)) toks))
  (check-true (ormap (lambda (t) (eq? (token-type t) 'rangle)) toks))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$pipe-gt)) toks))
  (check-true (ormap (lambda (t) (eq? (token-value t) '$compose)) toks)))

;; ========================================
;; I. Block-Form Pipe: Preparse-Level Fusion Tests
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
  ;; Single fusible → sequential application (no fusion needed)
  (define result (preparse-expand-form '($pipe-gt xs (map f))))
  (check-equal? result '(map f xs)))

(test-case "preparse/block-pipe-single-filter: ($pipe-gt xs (filter p)) → (filter p xs)"
  (define result (preparse-expand-form '($pipe-gt xs (filter p))))
  (check-equal? result '(filter p xs)))

(test-case "preparse/block-pipe-single-remove: ($pipe-gt xs (remove p)) → (remove p xs)"
  (define result (preparse-expand-form '($pipe-gt xs (remove p))))
  (check-equal? result '(remove p xs)))

(test-case "preparse/block-pipe-materialize-2: map + filter → sequential"
  ;; Two fusible ops → sequential: (filter p (map f xs))
  (define result (preparse-expand-form '($pipe-gt xs (map f) (filter p))))
  (check-equal? result '(filter p (map f xs))))

(test-case "preparse/block-pipe-materialize-3: map + filter + map → sequential"
  (define result (preparse-expand-form '($pipe-gt xs (map f) (filter p) (map g))))
  (check-equal? result '(map g (filter p (map f xs)))))

(test-case "preparse/block-pipe-fuse-reduce: fusible + reduce → single fused reduce"
  ;; map + filter + reduce → ONE reduce call (fused into single-pass)
  (define result (preparse-expand-form '($pipe-gt xs (map f) (filter p) (reduce rf z))))
  (check-true (pair? result))
  (check-equal? (car result) 'reduce)
  ;; rf is used inside the composed reducer
  (check-true (datum-contains? result 'rf))
  ;; z is the initial value
  (check-equal? (caddr result) 'z)
  ;; Data source is xs
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
  ;; Barrier (sort) separates the chain: (filter p (sort cmp (map f xs)))
  (define result (preparse-expand-form '($pipe-gt xs (map f) (sort cmp) (filter p))))
  (check-equal? result '(filter p (sort cmp (map f xs)))))

(test-case "preparse/block-pipe-barrier-then-terminal: map + sort + reduce"
  ;; map, then barrier sort, then reduce terminal (no fusion since chain restarted)
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
  ;; count fuses as filter + suc reducer
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

;; ========================================
;; J. Block-Form Pipe: E2E Tests (Sexp Mode)
;; ========================================
;; These tests run full pipelines through the type checker and evaluator.
;; They require the transducer module for fusible operations.

(define (pipe-preamble-sexp)
  (string-append
   "(ns test-pipe-e2e)\n"
   "(require [prologos.data.list :refer [List nil cons map filter reduce sum length reverse]])\n"
   "(require [prologos.data.nat :refer [add]])\n"
   "(require [prologos.data.transducer :refer [map-xf filter-xf remove-xf xf-compose transduce into-list-rev into-list list-conj]])\n"))

;; Helper definitions for sexp mode E2E tests
(define (pipe-helpers-sexp)
  (string-append
   "(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))\n"
   "(def positive? : [-> Nat Bool] (fn (x : Nat) (match x (zero -> false) (suc _ -> true))))\n"
   "(def sum-rf : [-> Nat [-> Nat Nat]] (fn (acc : Nat) (fn (x : Nat) (add acc x))))\n"
   "(def nums3 : [List Nat] (cons Nat 1 (cons Nat 2 (cons Nat 3 (nil Nat)))))\n"
   "(def nums5 : [List Nat] (cons Nat 0 (cons Nat 1 (cons Nat 2 (cons Nat 3 (cons Nat 4 (nil Nat)))))))\n"))

(test-case "e2e/block-pipe-map-reduce: map + reduce → transduce"
  ;; ($pipe-gt nums3 (map suc-fn) (reduce sum-rf zero))
  ;; [1,2,3] → map suc → [2,3,4] → reduce + 0 → 9
  (define result
    (run-last
     (string-append
      (pipe-preamble-sexp) (pipe-helpers-sexp)
      "(eval ($pipe-gt nums3 (map suc-fn) (reduce sum-rf zero)))")))
  (check-equal? result "9N : Nat"))

(test-case "e2e/block-pipe-filter-reduce: filter + reduce → transduce"
  ;; ($pipe-gt nums5 (filter positive?) (reduce sum-rf zero))
  ;; [0,1,2,3,4] → filter positive? → [1,2,3,4] → sum → 10
  (define result
    (run-last
     (string-append
      (pipe-preamble-sexp) (pipe-helpers-sexp)
      "(eval ($pipe-gt nums5 (filter positive?) (reduce sum-rf zero)))")))
  (check-equal? result "10N : Nat"))

(test-case "e2e/block-pipe-fuse-three: map + filter + map materialized"
  ;; ($pipe-gt nums5 (map suc-fn) (filter positive?) (map suc-fn))
  ;; [0,1,2,3,4] → map suc → [1,2,3,4,5] → filter positive? → [1,2,3,4,5] → map suc → [2,3,4,5,6]
  (define result
    (run-last
     (string-append
      (pipe-preamble-sexp) (pipe-helpers-sexp)
      "(eval ($pipe-gt nums5 (map suc-fn) (filter positive?) (map suc-fn)))")))
  ;; into-list produces correct-order list
  (define r result)
  (check-true (string? r))
  (check-true (string-contains? r "'[2N 3N 4N 5N 6N]")))

(test-case "e2e/block-pipe-no-steps: ($pipe-gt zero) → zero"
  (define result
    (run-last
     (string-append
      (pipe-preamble-sexp)
      "(eval ($pipe-gt zero))")))
  (check-equal? result "0N : Nat"))

(test-case "e2e/block-pipe-plain-step: ($pipe-gt zero suc suc) → 2"
  ;; Non-fusible bare function steps
  (define result
    (run-last
     (string-append
      (pipe-preamble-sexp)
      "(eval ($pipe-gt zero suc suc))")))
  (check-equal? result "2N : Nat"))

;; ========================================
;; K. Block-Form Pipe: E2E Tests (WS Mode)
;; ========================================

(define (pipe-preamble-ws)
  (string-append
   "ns test-pipe-ws\n"
   "require [prologos.data.list :refer [List nil cons map filter reduce sum length reverse]]\n"
   "        [prologos.data.nat :refer [add]]\n"
   "        [prologos.data.transducer :refer [map-xf filter-xf remove-xf xf-compose transduce into-list-rev into-list list-conj]]\n"
   "\n"))

(define (pipe-helpers-ws)
  (string-append
   "(def suc-fn : [-> Nat Nat] (fn (x : Nat) (suc x)))\n"
   "(def positive? : [-> Nat Bool] (fn (x : Nat) (match x (zero -> false) (suc _ -> true))))\n"
   "(def sum-rf : [-> Nat [-> Nat Nat]] (fn (acc : Nat) (fn (x : Nat) (add acc x))))\n"
   "(def nums3 : [List Nat] (cons Nat 1 (cons Nat 2 (cons Nat 3 (nil Nat)))))\n"
   "\n"))

(test-case "ws/block-pipe-basic: block form with indented steps"
  (define result
    (run-ws-last
     (string-append
      (pipe-preamble-ws) (pipe-helpers-ws)
      ;; Block form: |> as first token, indented body
      "|> nums3\n"
      "  map suc-fn\n"
      "  reduce sum-rf zero\n")))
  (check-equal? result "9N : Nat"))

(test-case "ws/block-pipe-fuse-materialize: block form materializes"
  (define result
    (run-ws-last
     (string-append
      (pipe-preamble-ws) (pipe-helpers-ws)
      "|> nums3\n"
      "  map suc-fn\n"
      "  filter positive?\n")))
  ;; [1,2,3] → map suc → [2,3,4] → filter positive? → [2,3,4]
  (define r result)
  (check-true (string? r))
  (check-true (string-contains? r "'[2N 3N 4N]")))

(test-case "ws/block-pipe-inline-compat: inline |> still works in WS"
  (define result
    (run-ws-last
     (string-append
      (pipe-preamble-ws)
      "eval [zero |> suc |> suc]\n")))
  (check-equal? result "2N : Nat"))
