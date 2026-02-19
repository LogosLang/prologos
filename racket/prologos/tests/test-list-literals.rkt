#lang racket/base

;;;
;;; PROLOGOS LIST LITERAL TESTS
;;; Tests for the '[...] list literal sigil syntax.
;;; Tests tokenizer, reader, pre-parse expansion, sexp readtable,
;;; pretty printer, and full integration pipeline.
;;;

(require rackunit
         racket/string
         racket/list
         racket/path
         "../reader.rkt"
         "../macros.rkt"
         "../sexp-readtable.rkt"
         "../pretty-print.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt")

;; ================================================================
;; Helpers
;; ================================================================

;; Token type at index
(define (tok-type tokens i)
  (vector-ref (struct->vector (list-ref tokens i)) 1))

(define (tok-val tokens i)
  (vector-ref (struct->vector (list-ref tokens i)) 2))

;; Compute lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run prologos code with full namespace/module system
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; ================================================================
;; TOKENIZER TESTS
;; ================================================================

(test-case "tokenize: '[ produces quote-lbracket token"
  (define toks (tokenize-string "'[1N 2N 3N]"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-not-false (member 'quote-lbracket types)))

(test-case "tokenize: standalone ' without [ produces quote token"
  ;; 'x now produces a 'quote token (quote operator), not an error
  (define toks (tokenize-string "'x"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-not-false (member 'quote types)))

;; ================================================================
;; WS READER PARSE TESTS
;; ================================================================

(test-case "parse: '[1N 2N 3N] produces $list-literal"
  (define forms (read-all-forms-string "eval '[1N 2N 3N]"))
  (check-equal? forms '((eval ($list-literal ($nat-literal 1) ($nat-literal 2) ($nat-literal 3))))))

(test-case "parse: '[] produces empty $list-literal"
  (define forms (read-all-forms-string "eval '[]"))
  (check-equal? forms '((eval ($list-literal)))))

(test-case "parse: '[1 2 | ys] produces $list-tail"
  (define forms (read-all-forms-string "eval '[1 2 | ys]"))
  (check-equal? forms '((eval ($list-literal 1 2 ($list-tail ys))))))

(test-case "parse: '[x] single element"
  (define forms (read-all-forms-string "eval '[x]"))
  (check-equal? forms '((eval ($list-literal x)))))

(test-case "parse: '[ with nested grouping"
  (define forms (read-all-forms-string "eval '[[suc zero] 2 3]"))
  (check-equal? forms '((eval ($list-literal (suc zero) 2 3)))))

(test-case "parse: '[ with commas stripped"
  (define forms (read-all-forms-string "eval '[1, 2, 3]"))
  (check-equal? forms '((eval ($list-literal 1 2 3)))))

(test-case "parse: '[ tail-only with pipe"
  (define forms (read-all-forms-string "eval '[| xs]"))
  (check-equal? forms '((eval ($list-literal ($list-tail xs))))))

;; ================================================================
;; PRE-PARSE MACRO EXPANSION TESTS
;; ================================================================

(test-case "expand: ($list-literal) -> nil"
  (check-equal? (preparse-expand-form '($list-literal))
                'nil))

(test-case "expand: ($list-literal 1 2 3) -> nested cons"
  (check-equal? (preparse-expand-form '($list-literal 1 2 3))
                '(cons 1 (cons 2 (cons 3 nil)))))

(test-case "expand: ($list-literal x) -> (cons x nil)"
  (check-equal? (preparse-expand-form '($list-literal x))
                '(cons x nil)))

(test-case "expand: ($list-literal 1 ($list-tail ys)) -> cons with tail"
  (check-equal? (preparse-expand-form '($list-literal 1 ($list-tail ys)))
                '(cons 1 ys)))

(test-case "expand: ($list-literal 1 2 ($list-tail ys)) -> nested cons with tail"
  (check-equal? (preparse-expand-form '($list-literal 1 2 ($list-tail ys)))
                '(cons 1 (cons 2 ys))))

(test-case "expand: ($list-literal ($list-tail ys)) -> just tail"
  (check-equal? (preparse-expand-form '($list-literal ($list-tail ys)))
                'ys))

(test-case "expand: nested $list-literal in subform"
  ;; When a $list-literal appears nested in another form,
  ;; preparse-expand-form should expand it recursively
  (define result (preparse-expand-form '(eval ($list-literal 1 2))))
  (check-equal? result '(eval (cons 1 (cons 2 nil)))))

;; ================================================================
;; SEXP READTABLE TESTS
;; ================================================================

(test-case "sexp: '[1N 2N 3N] produces $list-literal"
  (define in (open-input-string "'[1N 2N 3N]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($list-literal 1N 2N 3N)))

(test-case "sexp: '[] produces empty $list-literal"
  (define in (open-input-string "'[]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($list-literal)))

(test-case "sexp: '[1 | xs] produces $list-tail"
  (define in (open-input-string "'[1 | xs]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($list-literal 1 ($list-tail xs))))

(test-case "sexp: '[1, 2, 3] strips commas"
  (define in (open-input-string "'[1, 2, 3]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($list-literal 1 2 3)))

(test-case "sexp: regular 'foo produces $quote"
  ;; 'foo in sexp mode now produces ($quote foo) for parity with WS mode
  (define in (open-input-string "'foo"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($quote foo)))

(test-case "sexp: '(1 2) produces $quote (regular parens)"
  ;; '(1 2) in sexp mode now produces ($quote (1 2)) for parity with WS mode
  (define in (open-input-string "'(1 2)"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($quote (1 2))))

;; ================================================================
;; PRETTY PRINTER TESTS
;; ================================================================

(test-case "pp: cons chain ending in nil -> '[...]"
  ;; cons 1 (cons 2 (cons 3 nil))
  (define e
    (expr-app (expr-app (expr-fvar 'cons) (expr-suc (expr-zero)))
              (expr-app (expr-app (expr-fvar 'cons) (expr-suc (expr-suc (expr-zero))))
                        (expr-app (expr-app (expr-fvar 'cons) (expr-suc (expr-suc (expr-suc (expr-zero)))))
                                  (expr-fvar 'nil)))))
  (check-equal? (pp-expr e) "'[1N 2N 3N]"))

(test-case "pp: cons with non-nil tail -> '[... | tail]"
  ;; cons 1 xs
  (define e
    (expr-app (expr-app (expr-fvar 'cons) (expr-suc (expr-zero)))
              (expr-fvar 'xs)))
  (check-equal? (pp-expr e) "'[1N | xs]"))

(test-case "pp: single element list -> '[x]"
  (define e
    (expr-app (expr-app (expr-fvar 'cons) (expr-fvar 'x))
              (expr-fvar 'nil)))
  (check-equal? (pp-expr e) "'[x]"))

(test-case "pp: bare nil stays as nil"
  (check-equal? (pp-expr (expr-fvar 'nil)) "nil"))

(test-case "pp: cons with complex tail -> '[... | tail]"
  ;; cons 1 (cons 2 xs) — improper list
  (define e
    (expr-app (expr-app (expr-fvar 'cons) (expr-suc (expr-zero)))
              (expr-app (expr-app (expr-fvar 'cons) (expr-suc (expr-suc (expr-zero))))
                        (expr-fvar 'xs))))
  (check-equal? (pp-expr e) "'[1N 2N | xs]"))

;; ================================================================
;; INTEGRATION TESTS — Full Pipeline
;; ================================================================

(test-case "integration: $list-literal expands to cons chain via sexp reader"
  (define results
    (run-ns (string-append
             "(ns t-list-1)\n"
             "(require [prologos.data.list :refer [List nil cons]])\n"
             "(check '[1N 2N 3N] : (List Nat))")))
  (check-not-false results)
  ;; Should not contain any errors
  (for ([r (in-list results)])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~a" r))))

(test-case "integration: empty list literal '[] works"
  (define results
    (run-ns (string-append
             "(ns t-list-2)\n"
             "(require [prologos.data.list :refer [List nil cons]])\n"
             "(check '[] : (List Nat))")))
  (check-not-false results)
  (for ([r (in-list results)])
    (check-false (prologos-error? r)
                 (format "Unexpected error: ~a" r))))

(test-case "integration: map over list literal"
  (define results
    (run-ns (string-append
             "(ns t-list-3)\n"
             "(require [prologos.data.list :refer [List nil cons map]])\n"
             "(eval (map (fn (x : Nat) (suc x)) '[1N 2N 3N]))")))
  ;; Should produce a list [2, 3, 4]
  (check-not-false results)
  ;; Result should be a cons chain: '[2N 3N 4N]
  (define result-str (last results))
  (check-true (string? result-str)
              (format "Expected string result, got: ~a" result-str))
  (check-true (string-contains? result-str "'[2N 3N 4N]")
              (format "Expected '[2N 3N 4N] in output, got: ~a" result-str)))

(test-case "integration: length of list literal"
  (define results
    (run-ns (string-append
             "(ns t-list-4)\n"
             "(require [prologos.data.list :refer [List nil cons length]])\n"
             "(eval (length '[1N 2N 3N]))")))
  (check-not-false results)
  (define result-str (last results))
  (check-true (string? result-str)
              (format "Expected string result, got: ~a" result-str))
  (check-true (string-contains? result-str "3")
              (format "Expected 3 in output, got: ~a" result-str)))

(test-case "integration: def with list literal body"
  (define results
    (run-ns (string-append
             "(ns t-list-5)\n"
             "(require [prologos.data.list :refer [List nil cons length]])\n"
             "(def my-list : (List Nat) '[1N 2N 3N])\n"
             "(eval (length my-list))")))
  (check-not-false results)
  (define result-str (last results))
  (check-true (string? result-str)
              (format "Expected string result, got: ~a" result-str))
  (check-true (string-contains? result-str "3")
              (format "Expected 3 in output, got: ~a" result-str)))
