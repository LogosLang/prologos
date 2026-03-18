#lang racket/base

;;;
;;; PROLOGOS QUOTE & QUASIQUOTE TESTS
;;; Tests for Phase III: runtime quote, Symbol type, Datum type, quasiquote.
;;; See docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md (Phase III).
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/port
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../source-location.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../sexp-readtable.rkt"
         "../reader.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run sexp-mode code
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-bundle-registry (current-bundle-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; A. datum->datum-expr unit tests (preparse level)
;; ========================================

(test-case "quote/preparse: symbol becomes datum-sym"
  (define result (datum->datum-expr 'foo))
  (check-equal? result '(datum-sym (symbol-lit foo))))

(test-case "quote/preparse: keyword-like symbol becomes datum-kw"
  (define result (datum->datum-expr ':bar))
  (check-equal? result '(datum-kw :bar)))

(test-case "quote/preparse: natural number becomes datum-nat"
  (define result (datum->datum-expr 42))
  (check-equal? result '(datum-nat ($nat-literal 42))))

(test-case "quote/preparse: negative integer becomes datum-int"
  (define result (datum->datum-expr -5))
  (check-equal? result '(datum-int (int -5))))

(test-case "quote/preparse: rational becomes datum-rat"
  (define result (datum->datum-expr 1/3))
  (check-equal? result '(datum-rat 1/3)))

(test-case "quote/preparse: boolean becomes datum-bool"
  (check-equal? (datum->datum-expr #t) '(datum-bool true))
  (check-equal? (datum->datum-expr #f) '(datum-bool false)))

(test-case "quote/preparse: empty list becomes datum-nil"
  (check-equal? (datum->datum-expr '()) 'datum-nil))

(test-case "quote/preparse: list becomes datum-cons chain"
  (define result (datum->datum-expr '(add 1 2)))
  ;; (add 1 2) → (datum-cons (datum-sym (symbol-lit add))
  ;;               (datum-cons (datum-nat 1)
  ;;                 (datum-cons (datum-nat 2) datum-nil)))
  (check-equal? (car result) 'datum-cons)
  (check-equal? (cadr result) '(datum-sym (symbol-lit add)))
  (check-equal? (car (caddr result)) 'datum-cons)
  (check-equal? (cadr (caddr result)) '(datum-nat ($nat-literal 1))))

(test-case "quote/preparse: $quote macro emits datum constructor chain"
  (define result (preparse-expand-1 '($quote foo)))
  (check-equal? result '(datum-sym (symbol-lit foo))))

(test-case "quote/preparse: nested quote becomes data"
  (define result (preparse-expand-1 '($quote (add 1 2))))
  ;; Should be a datum-cons chain
  (check-equal? (car result) 'datum-cons))

;; ========================================
;; B. Symbol type pipeline tests (e2e)
;; ========================================

(test-case "quote/symbol: Symbol type is valid"
  (define result
    (run-last (string-append
      "(ns t-q-s1)\n"
      "(infer Symbol)")))
  (check-true (string? result))
  (check-true (string-contains? result "Type")))

(test-case "quote/symbol: symbol-lit produces Symbol value"
  (define result
    (run-last (string-append
      "(ns t-q-s2)\n"
      "(infer (symbol-lit foo))")))
  (check-true (string? result))
  (check-true (string-contains? result "Symbol")))

(test-case "quote/symbol: symbol-lit checks against Symbol type"
  (define result
    (run-last (string-append
      "(ns t-q-s3)\n"
      "(check (symbol-lit bar) : Symbol)")))
  ;; check should succeed (no error)
  (check-true (string? result))
  (check-false (string-contains? result "error")))

;; ========================================
;; C. Datum type + quote e2e tests
;; ========================================

(test-case "quote/datum: datum-nil has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d1)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer datum-nil)")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: datum-nat 42 has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d2)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer (datum-nat 42N))")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: datum-sym with symbol-lit has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d3)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer (datum-sym (symbol-lit foo)))")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: datum-cons builds nested Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d4)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer (datum-cons (datum-nat 1N) datum-nil))")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: '42 has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d5)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer '42)")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: 'foo has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d6)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer 'foo)")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: '(add 1 2) has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-d7)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer '(add 1 2))")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quote/datum: '() is datum-nil"
  (define result
    (run-last (string-append
      "(ns t-q-d8)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(eval '())")))
  (check-true (string? result))
  ;; Should reduce to datum-nil
  (check-true (string-contains? result "datum-nil")))

(test-case "quote/datum: ':foo is datum-kw"
  (define result
    (run-last (string-append
      "(ns t-q-d9)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(eval ':foo)")))
  (check-true (string? result))
  (check-true (string-contains? result "datum-kw")))

(test-case "quote/datum: expand-1 shows quote desugaring"
  (define result
    (run-last (string-append
      "(ns t-q-d10)\n"
      "(expand-1 '42)")))
  (check-true (string? result))
  ;; Should show datum-nat in the expansion
  (check-true (string-contains? result "datum-nat")))

(test-case "quote/datum: expand-1 shows nested quote desugaring"
  (define result
    (run-last (string-append
      "(ns t-q-d11)\n"
      "(expand-1 '(add 1))")))
  (check-true (string? result))
  ;; Should show datum-cons chain
  (check-true (string-contains? result "datum-cons")))

;; ========================================
;; D. Pattern matching on Datum
;; ========================================

(test-case "quote/pattern: match datum-nat extracts Nat"
  (define result
    (run-last (string-append
      "(ns t-q-p1)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(eval (the Nat (match (datum-nat 42N) (datum-nat n -> n))))")))
  (check-true (string? result))
  (check-true (string-contains? result "42")))

(test-case "quote/pattern: match datum-nil"
  (define result
    (run-last (string-append
      "(ns t-q-p2)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(eval (the Nat (match datum-nil (datum-nil -> zero) (datum-nat n -> n))))")))
  (check-true (string? result))
  (check-true (string-contains? result "0N")))

;; ========================================
;; E. Quasiquote reader tests (sexp mode)
;; ========================================

(test-case "quasiquote/reader: `foo reads as ($quasiquote foo)"
  (define result
    (with-input-from-string "`foo"
      (lambda ()
        (parameterize ([current-readtable (dynamic-require
                         "../sexp-readtable.rkt" 'prologos-readtable)])
          (read)))))
  (check-equal? result '($quasiquote foo)))

(test-case "quasiquote/reader: `(add 1 2) reads as ($quasiquote (add 1 2))"
  (define result
    (with-input-from-string "`(add 1 2)"
      (lambda ()
        (parameterize ([current-readtable (dynamic-require
                         "../sexp-readtable.rkt" 'prologos-readtable)])
          (read)))))
  (check-equal? result '($quasiquote (add 1 2))))

(test-case "quasiquote/reader: `(add ,x 2) has $unquote"
  (define result
    (with-input-from-string "`(add ,x 2)"
      (lambda ()
        (parameterize ([current-readtable (dynamic-require
                         "../sexp-readtable.rkt" 'prologos-readtable)])
          (read)))))
  (check-equal? result '($quasiquote (add ($unquote x) 2))))

(test-case "quasiquote/reader: `(,a ,b) has two unquotes"
  (define result
    (with-input-from-string "`(,a ,b)"
      (lambda ()
        (parameterize ([current-readtable (dynamic-require
                         "../sexp-readtable.rkt" 'prologos-readtable)])
          (read)))))
  (check-equal? result '($quasiquote (($unquote a) ($unquote b)))))

(test-case "quasiquote/reader: `,x reads as ($quasiquote ($unquote x))"
  (define result
    (with-input-from-string "`,x"
      (lambda ()
        (parameterize ([current-readtable (dynamic-require
                         "../sexp-readtable.rkt" 'prologos-readtable)])
          (read)))))
  (check-equal? result '($quasiquote ($unquote x))))

;; ========================================
;; F. Quasiquote preparse macro tests
;; ========================================

(test-case "quasiquote/preparse: `foo same as 'foo"
  (define qq-result (preparse-expand-1 '($quasiquote foo)))
  (define q-result (preparse-expand-1 '($quote foo)))
  (check-equal? qq-result q-result))

(test-case "quasiquote/preparse: `42 same as '42"
  (define qq-result (preparse-expand-1 '($quasiquote 42)))
  (define q-result (preparse-expand-1 '($quote 42)))
  (check-equal? qq-result q-result))

(test-case "quasiquote/preparse: `(add 1 2) same as '(add 1 2)"
  (define qq-result (preparse-expand-1 '($quasiquote (add 1 2))))
  (define q-result (preparse-expand-1 '($quote (add 1 2))))
  (check-equal? qq-result q-result))

(test-case "quasiquote/preparse: `(add ($unquote x) 2) passes x through"
  (define result (preparse-expand-1 '($quasiquote (add ($unquote x) 2))))
  ;; Should be (datum-cons (datum-sym (symbol-lit add))
  ;;             (datum-cons x
  ;;               (datum-cons (datum-nat 2) datum-nil)))
  (check-equal? (car result) 'datum-cons)
  ;; Second element: (datum-cons x ...)
  (define inner (caddr result))
  (check-equal? (car inner) 'datum-cons)
  ;; x should be passed through raw (not quoted)
  (check-equal? (cadr inner) 'x))

(test-case "quasiquote/preparse: nested unquotes in list"
  (define result (preparse-expand-1 '($quasiquote (($unquote a) ($unquote b)))))
  ;; Should be (datum-cons a (datum-cons b datum-nil))
  (check-equal? (car result) 'datum-cons)
  (check-equal? (cadr result) 'a)
  (define inner (caddr result))
  (check-equal? (car inner) 'datum-cons)
  (check-equal? (cadr inner) 'b)
  (check-equal? (caddr inner) 'datum-nil))

(test-case "quasiquote/preparse: unquote at top level passes through"
  ;; `,$unquote x → ($quasiquote ($unquote x)) → x
  (define result (preparse-expand-1 '($quasiquote ($unquote x))))
  (check-equal? result 'x))

;; ========================================
;; G. Quasiquote e2e tests (sexp mode)
;; ========================================

(test-case "quasiquote/e2e: `42 has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-qq1)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer `42)")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quasiquote/e2e: `(add 1 2) has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-qq2)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(infer `(add 1 2))")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quasiquote/e2e: `(add ,x 2) with x : Datum has type Datum"
  (define result
    (run-last (string-append
      "(ns t-q-qq3)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(def x : Datum datum-nil)\n"
      "(infer `(add ,x 2))")))
  (check-true (string? result))
  (check-true (string-contains? result "Datum")))

(test-case "quasiquote/e2e: quasiquote with no unquotes same as quote"
  (define result-qq
    (run-last (string-append
      "(ns t-q-qq4a)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(eval `foo)")))
  (define result-q
    (run-last (string-append
      "(ns t-q-qq4b)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(eval 'foo)")))
  (check-equal? result-qq result-q))

(test-case "quasiquote/e2e: quasiquote splices unquoted Datum value"
  ;; `(,x) with x = (datum-nat 99) should produce (datum-cons (datum-nat 99) datum-nil)
  ;; Match the head of the cons, then match the head element as datum-nat
  (define result
    (run-last (string-append
      "(ns t-q-qq5)\n"
      "(imports [prologos::data::datum :refer [Datum datum-sym datum-kw datum-nat datum-int datum-rat datum-bool datum-nil datum-cons]])\n"
      "(def x : Datum (datum-nat 99N))\n"
      "(def result : Datum (the Datum (match `(,x) (datum-cons hd tl -> hd))))\n"
      "(eval (the Nat (match result (datum-nat n -> n))))")))
  (check-true (string? result))
  (check-true (string-contains? result "99")))

;; ========================================
;; H. Quasiquote WS-mode reader tests
;; ========================================
;; These test the WS reader (read-all-forms-string) to verify that commas
;; inside quasiquoted paren/bracket forms produce ($unquote ...) instead
;; of being silently skipped as parameter separators.

(test-case "quasiquote/ws-reader: `(add ,x 2) has $unquote"
  (define forms (read-all-forms-string "`(add ,x 2)"))
  (check-equal? (length forms) 1)
  (define form (car forms))
  (check-equal? form '($quasiquote (add ($unquote x) 2))))

(test-case "quasiquote/ws-reader: `(,a ,b) has two unquotes"
  (define forms (read-all-forms-string "`(,a ,b)"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '($quasiquote (($unquote a) ($unquote b)))))

(test-case "quasiquote/ws-reader: `[,a ,b] bracket form has unquotes"
  (define forms (read-all-forms-string "`[,a ,b]"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '($quasiquote (($unquote a) ($unquote b)))))

(test-case "quasiquote/ws-reader: `foo bare symbol"
  (define forms (read-all-forms-string "`foo"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '($quasiquote foo)))

(test-case "quasiquote/ws-reader: `,x reads as quasiquote-unquote"
  (define forms (read-all-forms-string "`,x"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '($quasiquote ($unquote x))))

(test-case "quasiquote/ws-reader: commas still separate outside quasiquote"
  ;; (Nat, Bool) without quasiquote → commas are separators → (Nat Bool)
  (define forms (read-all-forms-string "(Nat, Bool)"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '(Nat Bool)))

(test-case "quasiquote/ws-reader: unquote inside nested parens"
  ;; `(f (g ,x)) — comma inside nested paren
  (define forms (read-all-forms-string "`(f (g ,x))"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '($quasiquote (f (g ($unquote x))))))

(test-case "quasiquote/ws-reader: commas in unquoted subexpr are separators"
  ;; `(f ,(g a, b)) — the comma before (g...) is unquote,
  ;; but commas inside (g a, b) are separators (back to depth 0)
  (define forms (read-all-forms-string "`(f ,(g a, b))"))
  (check-equal? (length forms) 1)
  (check-equal? (car forms) '($quasiquote (f ($unquote (g a b))))))
