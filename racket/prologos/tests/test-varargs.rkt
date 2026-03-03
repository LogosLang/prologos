#lang racket/base

;;;
;;; PROLOGOS VARARGS TESTS
;;; Tests for homogeneous variable arguments: `...` in spec, `...name` in defn,
;;; and call-site argument collection.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
         "test-support.rkt"
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

;; Run sexp-mode Prologos code
(define (run s)
  (parameterize ([current-global-env (hasheq)]
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

;; Run WS-mode code via temp .prologos file
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-test-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-global-env (hasheq)]
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
      (process-file tmp)))
  (delete-file tmp)
  result)

(define (run-ws-last s) (last (run-ws s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; Token helpers
(define (tok-type tokens i)
  (vector-ref (struct->vector (list-ref tokens i)) 1))

(define (tok-val tokens i)
  (vector-ref (struct->vector (list-ref tokens i)) 2))

;; ========================================
;; A. Reader tokenization tests
;; ========================================

(test-case "varargs reader: bare ... produces $rest symbol"
  (define toks (tokenize-string "Nat ... -> Nat"))
  (define vals (map (lambda (t) (vector-ref (struct->vector t) 2)) toks))
  ;; Should contain $rest
  (check-not-false (member '$rest vals)))

(test-case "varargs reader: ...xs produces rest-param token"
  (define toks (tokenize-string "[a b ...xs]"))
  (define types (map (lambda (t) (vector-ref (struct->vector t) 1)) toks))
  (check-not-false (member 'rest-param types)))

(test-case "varargs reader: ...xs token value is xs"
  (define toks (tokenize-string "[a ...xs]"))
  (define rp-tok (findf (lambda (t) (eq? (vector-ref (struct->vector t) 1) 'rest-param)) toks))
  (check-not-false rp-tok)
  (check-equal? (vector-ref (struct->vector rp-tok) 2) 'xs))

(test-case "varargs reader: datum [a b ...xs] contains ($rest-param xs)"
  (define forms (read-all-forms-string "[a b ...xs]"))
  (define form (car forms))
  ;; form should be (a b ($rest-param xs))
  (check-equal? (length form) 3)
  (check-equal? (car (list-ref form 2)) '$rest-param)
  (check-equal? (cadr (list-ref form 2)) 'xs))

(test-case "varargs reader: datum spec tokens contain $rest"
  (define forms (read-all-forms-string "spec foo Nat ... -> Nat"))
  ;; (spec foo Nat $rest -> Nat)
  (define form (car forms))
  (check-not-false (member '$rest form)))

(test-case "varargs reader: single dot is error"
  (check-exn exn:fail?
    (lambda () (tokenize-string "foo . bar"))))

;; ========================================
;; B. Spec processing tests
;; ========================================

(test-case "varargs spec: desugar-rest-type basic"
  (parameterize ([current-spec-store (hasheq)]
                 [current-global-env (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec add-all Nat $rest -> Nat))
    (define entry (lookup-spec 'add-all))
    (check-not-false entry)
    ;; rest-type should be Nat
    (check-equal? (spec-entry-rest-type entry) 'Nat)
    ;; type-datums should have (List Nat) instead of Nat $rest
    (define tokens (car (spec-entry-type-datums entry)))
    (check-not-false (member '(List Nat) tokens))))

(test-case "varargs spec: mixed fixed + varargs"
  (parameterize ([current-spec-store (hasheq)]
                 [current-global-env (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec max-of Nat Nat $rest -> Nat))
    (define entry (lookup-spec 'max-of))
    (check-equal? (spec-entry-rest-type entry) 'Nat)
    (define tokens (car (spec-entry-type-datums entry)))
    ;; Should be (Nat (List Nat) -> Nat) — first Nat is fixed, (List Nat) is rest
    (check-equal? (car tokens) 'Nat)
    (check-not-false (member '(List Nat) tokens))))

(test-case "varargs spec: with implicit binders"
  (parameterize ([current-spec-store (hasheq)]
                 [current-global-env (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec list-of ($brace-params A) A $rest -> (List A)))
    (define entry (lookup-spec 'list-of))
    (check-equal? (spec-entry-rest-type entry) 'A)
    (check-not-false (spec-entry-implicit-binders entry))))

(test-case "varargs spec: non-variadic has rest-type #f"
  (parameterize ([current-spec-store (hasheq)]
                 [current-global-env (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (process-spec '(spec id Nat -> Nat))
    (define entry (lookup-spec 'id))
    (check-false (spec-entry-rest-type entry))))

(test-case "varargs spec: $rest at start is error"
  (parameterize ([current-spec-store (hasheq)]
                 [current-global-env (hasheq)]
                 [current-preparse-registry prelude-preparse-registry])
    (check-exn exn:fail?
      (lambda () (process-spec '(spec bad $rest -> Nat))))))

;; ========================================
;; C. Sexp-mode end-to-end tests
;; ========================================

(test-case "varargs sexp: basic varargs function — length of rest"
  ;; Define a function that takes varargs and returns the list length
  (define result
    (run (string-append
          "(ns t-va-1)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-args Nat $rest -> Nat)\n"
          "(defn count-args [xs] (length Nat xs))\n"
          "(eval (count-args 1N 2N 3N))")))
  (check-equal? (last result) "3N : Nat"))

(test-case "varargs sexp: zero varargs — empty list"
  (define result
    (run (string-append
          "(ns t-va-2)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-args Nat $rest -> Nat)\n"
          "(defn count-args [xs] (length Nat xs))\n"
          "(eval (count-args))")))
  (check-equal? (last result) "0N : Nat"))

(test-case "varargs sexp: one vararg"
  (define result
    (run (string-append
          "(ns t-va-3)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-args Nat $rest -> Nat)\n"
          "(defn count-args [xs] (length Nat xs))\n"
          "(eval (count-args 42N))")))
  (check-equal? (last result) "1N : Nat"))

(test-case "varargs sexp: single vararg treated as element, not list"
  ;; A single arg is wrapped in a list (not treated as pre-built list)
  (define result
    (run (string-append
          "(ns t-va-4)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-args Nat $rest -> Nat)\n"
          "(defn count-args [xs] (length Nat xs))\n"
          "(eval (count-args 42N))")))
  (check-equal? (last result) "1N : Nat"))

(test-case "varargs sexp: mixed fixed + varargs"
  (define result
    (run (string-append
          "(ns t-va-5)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-rest Nat Nat $rest -> Nat)\n"
          "(defn count-rest [first xs] (length Nat xs))\n"
          "(eval (count-rest 99N 1N 2N 3N))")))
  (check-equal? (last result) "3N : Nat"))

(test-case "varargs sexp: mixed fixed + zero varargs"
  (define result
    (run (string-append
          "(ns t-va-6)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-rest Nat Nat $rest -> Nat)\n"
          "(defn count-rest [first xs] (length Nat xs))\n"
          "(eval (count-rest 99N))")))
  (check-equal? (last result) "0N : Nat"))

(test-case "varargs sexp: with implicit binder {A}"
  (define result
    (run (string-append
          "(ns t-va-7)\n"
          "(imports [prologos::data::list :refer [List nil cons length]])\n"
          "(spec count-any ($brace-params A) A $rest -> Nat)\n"
          "(defn count-any [xs] (length A xs))\n"
          "(eval (count-any 1 2 3 4))")))
  (check-equal? (last result) "4N : Nat"))

;; ========================================
;; E. WS-mode end-to-end tests
;; ========================================

(test-case "varargs ws: basic varargs function"
  (define result
    (run-ws (string-append
             "ns t-va-ws-1\n"
             "require [prologos::data::list :refer [List nil cons length]]\n"
             "\n"
             "spec count-args Nat ... -> Nat\n"
             "defn count-args [...xs]\n"
             "  length Nat xs\n"
             "\n"
             "count-args 1N 2N 3N\n")))
  (check-equal? (last result) "3N : Nat"))

(test-case "varargs ws: mixed fixed + varargs"
  (define result
    (run-ws (string-append
             "ns t-va-ws-2\n"
             "require [prologos::data::list :refer [List nil cons length]]\n"
             "\n"
             "spec count-rest Nat Nat ... -> Nat\n"
             "defn count-rest [first ...rest]\n"
             "  length Nat rest\n"
             "\n"
             "count-rest 99N 1N 2N 3N\n")))
  (check-equal? (last result) "3N : Nat"))

(test-case "varargs ws: with implicit binder"
  (define result
    (run-ws (string-append
             "ns t-va-ws-3\n"
             "require [prologos::data::list :refer [List nil cons length]]\n"
             "\n"
             "spec count-any {A : Type} A ... -> Nat\n"
             "defn count-any [...xs]\n"
             "  length A xs\n"
             "\n"
             "count-any 1 2 3 4 5\n")))
  (check-equal? (last result) "5N : Nat"))

(test-case "varargs ws: zero varargs"
  (define result
    (run-ws (string-append
             "ns t-va-ws-4\n"
             "require [prologos::data::list :refer [List nil cons length]]\n"
             "\n"
             "spec count-args Nat ... -> Nat\n"
             "defn count-args [...xs]\n"
             "  length Nat xs\n"
             "\n"
             "count-args\n")))
  (check-equal? (last result) "0N : Nat"))

(test-case "varargs ws: identity on rest list"
  (define result
    (run-ws (string-append
             "ns t-va-ws-5\n"
             "require [prologos::data::list :refer [List nil cons]]\n"
             "\n"
             "spec list-of {A : Type} A ... -> [List A]\n"
             "defn list-of [...xs]\n"
             "  xs\n"
             "\n"
             "list-of 1N 2N 3N\n")))
  (define r (last result))
  (check-true (string? r))
  ;; Pretty printer renders list as '[1N 2N 3N]
  (check-contains r "'[1N 2N 3N]"))
