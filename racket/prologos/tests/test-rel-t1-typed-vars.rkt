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

;; ========================================
;; C.b.2 — fused `x:Int` FUNCTIONAL binder end-to-end (WS via process-file). The
;; functional side reuses the pre-existing binder-info.type typed-λ path (no
;; type-pred), so the fused form types IDENTICALLY to the spaced `[fn [x : Int] x]`.
;; ========================================

(test-case "C.b.2 WS: fused `[fn [x:Int] x]` types as Int -> Int (same as spaced)"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndef ff := [fn [x:Int] x]\n[ff 5]\n"))
  ;; the binder's declared type flows into the λ type
  (check-true (ormap (lambda (r) (regexp-match? #rx"Int -> Int" r)) results))
  ;; applied to the declared type → Int
  (check-true (ormap (lambda (r) (regexp-match? #rx"5 : Int" r)) results)))

;; ========================================
;; C.c — schema ⟹ facts-only well-formedness gate (BLOCKING). A schema is a checked
;; contract on ground fact rows; a schema on a RULE relation (`defr R : S &> …`) is a
;; category error, rejected at registration. This closes the shipped Aspect-B hole
;; (relation-column-typer's schema branch types by schema assuming rows conform) by
;; rejecting the ill-formed input — the bad relation never registers.
;; ========================================

(define (cc-result-strings results)
  (map (lambda (r) (if (prologos-error? r) (prologos-error-message r) (format "~a" r))) results))

(test-case "C.c: a schema-typed RULE relation (schema + &> clauses) is REJECTED at registration"
  (define-values (results _store)
    (cb1-run-ws (string-append
                 "ns t :no-prelude\n\n"
                 "schema S\n  :x Int\n\n"
                 "defr sr : S\n  &> (= x 5)\n")))
  (check-true (ormap (lambda (s) (regexp-match? #rx"facts-only" s))
                     (cc-result-strings results))))

(test-case "C.c: a schema-typed FACTS-ONLY relation still registers + schema-types its rows"
  (define-values (results _store)
    (cb1-run-ws (string-append
                 "ns t :no-prelude\n\n"
                 "schema S\n  :x Int\n\n"
                 "defr sf : S\n  || 5\n     7\n\n"
                 "solve (sf a)\n")))
  (define strs (cc-result-strings results))
  ;; solve returns the schema-typed rows; NO facts-only rejection for a facts relation
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:a 5\\}" s)) strs))
  (check-false (ormap (lambda (s) (regexp-match? #rx"facts-only" s)) strs)))

(test-case "C.c: an UN-schema'd rule relation is unaffected (gate only fires for schema'd)"
  (define-values (results _store)
    (cb1-run-ws (string-append
                 "ns t :no-prelude\n\n"
                 "defr base [?x]\n  || 1\n\n"
                 "defr r [?a]\n  &> (base ?a)\n\n"
                 "solve (r q)\n")))
  (define strs (cc-result-strings results))
  (check-false (ormap (lambda (s) (regexp-match? #rx"facts-only" s)) strs))
  (check-true (ormap (lambda (s) (regexp-match? #rx"\\{:q 1\\}" s)) strs)))

;; ========================================
;; POL.6 — fused `x:Int` in `defn` param lists (the C.b.2 last mile)
;; ========================================
;; C.b.2 wired fused binders through `parse-binder` (fn-binders, both readers),
;; but a `defn`'s param list never routes there: `parse-defn-bare-params` mapped
;; binder-info over the RAW elements. WS delivers `defn f [x:Int]` as the TWO
;; elements `x` and `:Int` (instrumented on the real process-file path, not
;; inferred), so the defn silently became a TWO-parameter function whose second
;; param was named `:Int` — both hole-typed. Owner symptom: "cannot infer the
;; type of an unannotated parameter". Fixed by folding the flat param list
;; through the SHARED fused primitives (`fused-type-annot?` /
;; `fused-annot->type-surf` / `split-fused-symbol`) that parse-binder now also
;; uses — one implementation, both paths.

(test-case "POL.6 WS: fused `defn my-square [x:Int]` types + computes (the owner repro)"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndefn my-square [x:Int] : Int\n  * x x\n[my-square 7]\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"my-square : Int -> Int" r)) results)
              "the fused annotation reaches the binder type")
  (check-true (ormap (lambda (r) (regexp-match? #rx"49 : Int" r)) results))
  (check-false (ormap (lambda (r) (regexp-match? #rx"cannot infer" r)) results)))

(test-case "POL.6 WS: fused types IDENTICALLY to the spaced defn form"
  (define-values (fused _s1)
    (cb1-run-ws "ns t\n\ndefn f [x:Int] : Int\n  x\n"))
  (define-values (spaced _s2)
    (cb1-run-ws "ns t\n\ndefn f [x : Int] : Int\n  x\n"))
  (define (sig rs) (filter (lambda (r) (regexp-match? #rx"f :" r)) rs))
  (check-equal? (sig fused) (sig spaced)
                "fused and spaced defn params must produce the same signature"))

(test-case "POL.6 WS: multi-param fused, and the arity is RIGHT (not silently +1)"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndefn add2 [a:Int b:Int] : Int\n  + a b\n[add2 3 4]\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"add2 : Int Int -> Int" r)) results)
              "two params, both Int — the pre-fix bug made this 3-ary with a `:Int` param")
  (check-true (ormap (lambda (r) (regexp-match? #rx"7 : Int" r)) results)))

(test-case "POL.6 WS: the declared type is ENFORCED, not merely parsed"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndefn sq [x:Int] : Int\n  * x x\n[sq \"nope\"]\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"(?i:error|mismatch|infer)" r))
                     (cc-result-strings results))
              "applying a String to an Int-declared param must fail"))

(test-case "POL.6 WS: MIXED fused + bare — bare infers where it can (strictly > spaced)"
  ;; the spaced form hard-errors on mixed ("defn: expected 'name <type>'");
  ;; the fused fold leaves the bare param hole-typed, so ordinary bidirectional
  ;; inference applies — here the return type supplies it.
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndefn m [a:Int b] : Int\n  b\n[m 1 9]\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"m : Int Int -> Int" r)) results)
              "the bare param is inferred from the return type")
  (check-true (ormap (lambda (r) (regexp-match? #rx"9 : Int" r)) results)))

(test-case "POL.6 WS: bare defn params still hole-type (no regression)"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\nspec idf Int -> Int\ndefn idf [x]\n  x\n[idf 4]\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"4 : Int" r)) results)))

(test-case "POL.6 WS: multiplicity annotations are UNTOUCHED by the fused fold"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndefn mf [x :0 <Int> y <Int>] : Int\n  y\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx":0" r)) results)
              "the :0 multiplicity survives (fused-type-annot? excludes :0/:1/:w/:m)"))

(test-case "POL.6 WS: chained `[x:Int:Even]` is REJECTED (reserve for UCS)"
  (define-values (results _store)
    (cb1-run-ws "ns t\n\ndefn ch [x:Int:Even] : Int\n  x\n"))
  (define strs (cc-result-strings results))
  (check-true (ormap (lambda (r) (regexp-match? #rx"chained type annotation" r)) strs)
              "same posture as C.b.1/C.b.2")
  (check-true (ormap (lambda (r) (regexp-match? #rx"UCS" r)) strs)))

(test-case "POL.6 sexp: glued `(defn sq (x:Int) ...)` splits and types"
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list cb1-lib-dir)]
                   [current-relation-store (make-relation-store)])
      (install-module-loader!)
      (map (lambda (r) (format "~a" r))
           (process-string "(ns p6s) (defn sq (x:Int) : Int (int* x x)) (sq 6)"))))
  (check-true (ormap (lambda (r) (regexp-match? #rx"sq : Int -> Int" r)) results))
  (check-true (ormap (lambda (r) (regexp-match? #rx"36 : Int" r)) results)))
