#lang racket/base

;;;
;;; Tests for Rel Track 1 Aspect C — typed logic vars (`?x:Int` = Curry-Howard Int(x) = type).
;;;
;;; C.a (representation substrate): the `type-pred` value + the `param-info` `type`
;;; field via the #:name-redirect smart-constructor. These are pure-substrate unit
;;; tests — they guard the subtle smart-constructor idiom (the one load-bearing edit,
;;; whose naive form fails to compile) against regression, and seed the Aspect-C
;;; test file that C.b/C.c/C.d grow. Direct struct tests, so relations.rkt is required
;;; by RELATIVE path (never the collection path — see testing.md).
;;;

(require rackunit
         racket/list
         racket/path
         racket/file
         "../relations.rkt"
         "../syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt")

;; ========================================
;; type-pred value (the predicate SET, list-of-type-EXPR)
;; ========================================

(test-case "type-pred: constructs from a list of type-EXPRs and round-trips"
  ;; `?x:Int` → (type-pred (list (expr-Int)))
  (define tp (type-pred (list (expr-Int))))
  (check-true (type-pred? tp))
  (check-equal? (length (type-pred-preds tp)) 1)
  (check-true (expr-Int? (car (type-pred-preds tp)))))

(test-case "type-pred: conjunction carries multiple predicates in the list slot"
  ;; `?x:Int:Even`-shaped conjunction → two type-EXPRs (Even elided here to Int twice)
  (define tp (type-pred (list (expr-Int) (expr-Int))))
  (check-equal? (length (type-pred-preds tp)) 2))

(test-case "type-pred: empty predicate set is representable (still a type-pred, not #f)"
  (define tp (type-pred '()))
  (check-true (type-pred? tp))
  (check-equal? (type-pred-preds tp) '()))

;; ========================================
;; param-info smart-constructor: 2-arg legacy vs 3-arg typed
;; ========================================

(test-case "param-info: 2-arg construction defaults type to #f (legacy sites untouched)"
  (define p (param-info 'x 'free))
  (check-equal? (param-info-name p) 'x)
  (check-equal? (param-info-mode p) 'free)
  (check-false (param-info-type p)))

(test-case "param-info: 3-arg construction carries a type-pred"
  (define tp (type-pred (list (expr-Int))))
  (define p (param-info 'x 'free tp))
  (check-equal? (param-info-name p) 'x)
  (check-equal? (param-info-mode p) 'free)
  (check-eq? (param-info-type p) tp)
  ;; the type-EXPR is reachable through the param
  (check-true (expr-Int? (car (type-pred-preds (param-info-type p))))))

(test-case "param-info: predicate + transparency preserved under the #:name-redirect"
  (define p (param-info 'y 'in))
  (check-true (param-info? p))
  (check-false (param-info? 'not-a-param))
  ;; #:transparent equal? holds for legacy 2-arg twins (both type=#f)
  (check-equal? (param-info 'z 'free) (param-info 'z 'free))
  ;; a typed param and its untyped twin are NOT equal? (the type field participates)
  (check-not-equal? (param-info 'z 'free (type-pred (list (expr-Int))))
                    (param-info 'z 'free)))

;; ========================================
;; C.b.1 — fused `?x:Int` end-to-end (WS reader via process-file): the type is
;; parsed and the type-pred is STORED on param-info (parse-and-store, no typing).
;; The sexp reader path is covered at parse level in test-parser-relational.rkt;
;; both readers converge on the same (name mode type-name) 3-list that flows
;; through the shared elaborate→param-info storage exercised here.
;; ========================================

(define cb1-here (path->string (path-only (syntax-source #'cb1-here))))
(define cb1-lib-dir (simplify-path (build-path cb1-here ".." "lib")))

;; Run a WS .prologos string; return (values result-strings relation-store).
(define (cb1-run-ws content)
  (define tmp (make-temporary-file "cb1-typed-~a.prologos"))
  (call-with-output-file tmp (lambda (o) (display content o)) #:exists 'truncate)
  (define store (make-relation-store))
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list cb1-lib-dir)]
                   [current-relation-store store])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  (values results store))

;; Direct pipeline (parse[sexp] → elaborate → expr-variant->variant-info): proves
;; the type-EXPR is STORED on param-info, scope-free. (The process-file relation
;; store is module-scoped and not readable post-hoc, so the store proof uses the
;; direct pipeline; the sexp reader is exercised here, the WS reader end-to-end by
;; the consume/name-clean test below.)
(define (cb1-defr-param-types sexp-str)
  (define surf (parse-string sexp-str))
  (define ex (elaborate surf))
  (define v (car (expr-defr-variants ex)))
  (define vi (expr-variant->variant-info v))
  (map param-info-type (variant-info-params vi)))

(test-case "C.b.1: defr `?x:Int` stores (type-pred (list (expr-Int))) on the param"
  (define tys (cb1-defr-param-types "(defr rr [?x:Int] || 5)"))
  (check-equal? (length tys) 1)
  (define tp (car tys))
  (check-true (type-pred? tp))
  (check-equal? (length (type-pred-preds tp)) 1)
  (check-true (expr-Int? (car (type-pred-preds tp)))))

(test-case "C.b.1: multi typed params store per-position types; untyped → #f"
  (define tys (cb1-defr-param-types "(defr ee [?f:String ?w:Int ?u] || \"a\" 3 9)"))
  (check-equal? (length tys) 3)
  (check-true (expr-String? (car (type-pred-preds (list-ref tys 0)))))
  (check-true (expr-Int? (car (type-pred-preds (list-ref tys 1)))))
  (check-false (list-ref tys 2)))   ;; untyped param → no type-pred

(test-case "C.b.1: mode prefix + fused type coexist (`+k:Int`)"
  (define tys (cb1-defr-param-types "(defr mm [+k:Int] || 1)"))
  (check-true (expr-Int? (car (type-pred-preds (car tys))))))

(test-case "C.b.1 WS: the type is consumed (not leaked) and the param name is clean"
  ;; head ?a connects to body (base ?a) → {:q 1}; would be nil pre-C.b.1 (the :Int
  ;; leaked as a spurious param / the name was polluted).
  (define-values (results _store)
    (cb1-run-ws (string-append
                 "ns t :no-prelude\n\n"
                 "defr base [?x]\n  || 1\n\n"
                 "defr s1 [?a:Int]\n  &> (base ?a)\n\n"
                 "solve (s1 q)\n")))
  (check-true (regexp-match? #rx"\\{:q 1\\}" (last results))))

(test-case "C.b.1 WS: chained `?x:Int:Even` is rejected at registration"
  ;; process-file reports the registration error to stdout/stderr (and/or as a
  ;; result struct); capture all channels so the error text does not pollute the
  ;; test's own stdout, then assert the diagnostic fired. (The parse-level reject
  ;; is covered cleanly in test-parser-relational.rkt.)
  (define out (open-output-string))
  (define err (open-output-string))
  (define results
    (parameterize ([current-output-port out] [current-error-port err])
      (with-handlers ([(lambda (e) #t)
                       (lambda (e) (list (if (exn? e) (exn-message e) (format "~a" e))))])
        (let-values ([(rs _s)
                      (cb1-run-ws "ns t :no-prelude\n\ndefr bad [?x:Int:Even]\n  || 5\n")])
          rs))))
  (define combined
    (string-append (get-output-string out) (get-output-string err)
                   (apply string-append
                          (map (lambda (r) (if (string? r) r (format "~a" r))) results))))
  (check-true (regexp-match? #rx"chained type annotation" combined)))
