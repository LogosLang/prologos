#lang racket/base

;;;
;;; Tests for Phase 1 Extended Spec features:
;;; - spec metadata (from keyword-headed children)
;;; - :implicits key
;;; - property keyword
;;; - functor keyword
;;; - ?? typed holes
;;; - :laws on trait declarations
;;;

(require rackunit
         racket/string
         racket/list
         racket/hash
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../reader.rkt"
         "../source-location.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Run code and return result strings
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string s)))

;; Process spec and retrieve spec-entry from store
(define (spec-for name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string s)
    (lookup-spec name)))

;; Process code and retrieve property-entry from store
(define (property-for name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string s)
    (lookup-property name)))

;; Process code and retrieve functor-entry from store
(define (functor-for name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string s)
    (lookup-functor name)))

;; Process code and retrieve trait-meta from registry
(define (trait-for name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)])
    (process-string s)
    (lookup-trait name)))

;; ========================================
;; 1. Extended spec metadata
;; ========================================

(test-case "spec: metadata :doc extracted from keyword child"
  ;; In sexp mode, metadata comes as trailing ($brace-params ...)
  (define se (spec-for 'inc "(spec inc Nat -> Nat ($brace-params :doc \"Increment\"))"))
  (check-true (spec-entry? se))
  (check-equal? (spec-entry-docstring se) "Increment"))

(test-case "spec: metadata :doc wins over positional docstring"
  ;; When both positional and :doc exist, :doc in metadata wins
  (define se (spec-for 'inc "(spec inc \"Old doc\" Nat -> Nat ($brace-params :doc \"New doc\"))"))
  (check-true (spec-entry? se))
  (check-equal? (spec-entry-docstring se) "New doc"))

(test-case "spec: metadata hash stored on spec-entry"
  (define se (spec-for 'inc "(spec inc Nat -> Nat ($brace-params :doc \"Hi\" :see-also (bar baz)))"))
  (check-true (spec-entry? se))
  (define md (spec-entry-metadata se))
  (check-true (hash? md))
  (check-equal? (hash-ref md ':doc #f) "Hi"))

(test-case "spec: :where from metadata merges with positional where"
  ;; Sexp mode: process-spec handles metadata merge
  (define se (spec-for 'sort
    "(spec sort {A : (Type 0)} (List A) -> (List A) where (Eq A) ($brace-params :where (Ord A)))"))
  (check-true (spec-entry? se))
  ;; where-constraints should have BOTH Eq A and Ord A
  (define wcs (spec-entry-where-constraints se))
  (check-true (>= (length wcs) 2) "should have at least 2 where constraints"))

(test-case "spec: :implicits merges with inline implicit binders"
  ;; Sexp mode: explicit inline {A} plus :implicits {B}
  (define se (spec-for 'foo
    "(spec foo ($brace-params A : (Type 0)) A -> A ($brace-params :implicits ($brace-params B : (Type 0))))"))
  (check-true (spec-entry? se))
  (define ibs (spec-entry-implicit-binders se))
  ;; Should have both A and B
  (check-true (>= (length ibs) 2) "should have at least 2 implicit binders"))

(test-case "spec: no metadata yields #f"
  (define se (spec-for 'inc2 "(spec inc2 Nat -> Nat)"))
  (check-true (spec-entry? se))
  (check-false (spec-entry-metadata se)))

;; ========================================
;; 2. Metadata parsing via spec-entry (indirect tests of parse-spec-metadata)
;; ========================================

(test-case "spec metadata: :doc string stored in hash"
  (define se (spec-for 'test1 "(spec test1 Nat -> Nat ($brace-params :doc \"Hello world\"))"))
  (check-true (spec-entry? se))
  (check-equal? (spec-entry-docstring se) "Hello world")
  (check-equal? (hash-ref (spec-entry-metadata se) ':doc) "Hello world"))

(test-case "spec metadata: :where with constraints"
  (define se (spec-for 'test2
    "(spec test2 ($brace-params A : (Type 0)) A -> A ($brace-params :where (Ord A) (Eq A)))"))
  (check-true (spec-entry? se))
  ;; where-constraints should include both Ord A and Eq A
  (define wcs (spec-entry-where-constraints se))
  (check-true (>= (length wcs) 2) "should have at least 2 where constraints"))

(test-case "spec metadata: :properties ref stored"
  (define se (spec-for 'test3
    "(spec test3 Nat -> Nat ($brace-params :properties (sortable-laws Nat)))"))
  (check-true (spec-entry? se))
  (define md (spec-entry-metadata se))
  (check-true (hash? md))
  (define ps (hash-ref md ':properties '()))
  (check-equal? (length ps) 1))

(test-case "spec metadata: :implicits with brace groups"
  (define se (spec-for 'test4
    "(spec test4 A -> A ($brace-params :implicits ($brace-params A : (Type 0))))"))
  (check-true (spec-entry? se))
  (define ibs (spec-entry-implicit-binders se))
  (check-true (>= (length ibs) 1) "should have at least 1 implicit binder"))

(test-case "spec metadata: mixed keys"
  (define se (spec-for 'test5
    "(spec test5 ($brace-params A : (Type 0)) A -> A ($brace-params :doc \"Sort\" :where (Ord A) :see-also (bar)))"))
  (check-true (spec-entry? se))
  (define md (spec-entry-metadata se))
  (check-equal? (hash-ref md ':doc) "Sort")
  (check-true (pair? (hash-ref md ':see-also))))

;; ========================================
;; 3. Property keyword
;; ========================================

(test-case "process-property: basic property with clauses"
  (define pe
    (property-for 'eq-laws
      (string-append
        "(property eq-laws ($brace-params A : (Type 0))"
        "  (- :name \"reflexive\" :forall ($brace-params x : A) :holds (eq? x x))"
        "  ($brace-params :where (Eq A)))")))
  (check-true (property-entry? pe))
  (check-equal? (property-entry-name pe) 'eq-laws)
  ;; Should have params
  (check-true (>= (length (property-entry-params pe)) 1))
  ;; Should have where clauses
  (check-true (>= (length (property-entry-where-clauses pe)) 1)))

(test-case "process-property: clause parsing"
  (define pe
    (property-for 'my-laws
      (string-append
        "(property my-laws ($brace-params A : (Type 0))"
        "  (- :name \"law1\" :forall ($brace-params x : A) :holds (pred x))"
        "  (- :name \"law2\" :forall ($brace-params x : A) :holds (pred2 x))"
        "  ($brace-params :where (Eq A)))")))
  (check-true (property-entry? pe))
  (define clauses (property-entry-clauses pe))
  (check-equal? (length clauses) 2)
  ;; First clause
  (define c1 (car clauses))
  (check-true (property-clause? c1))
  (check-equal? (property-clause-name c1) "law1")
  (check-true (pair? (property-clause-forall-binders c1)))
  (check-equal? (property-clause-holds-expr c1) '(pred x))
  ;; Second clause
  (define c2 (cadr clauses))
  (check-equal? (property-clause-name c2) "law2"))

(test-case "process-property: :includes reference"
  (define pe
    (property-for 'combined-laws
      (string-append
        "(property combined-laws ($brace-params A : (Type 0))"
        "  ($brace-params :includes (eq-laws A) :where (Ord A)))")))
  (check-true (property-entry? pe))
  (define includes (property-entry-includes pe))
  (check-true (>= (length includes) 1)))

;; ========================================
;; 4. Functor keyword
;; ========================================

(test-case "process-functor: basic functor with :unfolds"
  (define fe
    (functor-for 'Xf
      (string-append
        "(functor Xf ($brace-params A B : (Type 0))"
        "  ($brace-params :unfolds (Pi (S :0 (Type 0)) (-> (-> S B S) (-> S (-> A S))))))")))
  (check-true (functor-entry? fe))
  (check-equal? (functor-entry-name fe) 'Xf)
  (check-true (>= (length (functor-entry-params fe)) 2))
  (check-true (pair? (functor-entry-unfolds fe))))

(test-case "process-functor: :doc and :compose stored in metadata"
  (define fe
    (functor-for 'Xf2
      (string-append
        "(functor Xf2 ($brace-params A B : (Type 0))"
        "  ($brace-params :doc \"A transducer\" :compose xf-compose"
        "    :unfolds (Pi (S :0 (Type 0)) (-> (-> S B S) (-> S (-> A S))))))")))
  (check-true (functor-entry? fe))
  (define md (functor-entry-metadata fe))
  (check-equal? (hash-ref md ':doc #f) "A transducer")
  (check-equal? (hash-ref md ':compose #f) 'xf-compose))

(test-case "process-functor: error when :unfolds missing"
  (check-exn
    exn:fail?
    (lambda ()
      (functor-for 'Bad
        "(functor Bad ($brace-params A : (Type 0)) ($brace-params :doc \"oops\"))"))))

;; ========================================
;; 5. ?? Typed holes — reader and parser
;; ========================================

(test-case "reader: ?? tokenizes as typed-hole"
  (define toks (tokenize-string "??"))
  (check-true (>= (length toks) 1))
  ;; Find the typed-hole token (skip any indent/dedent/newline tokens)
  (define hole-tok
    (findf (lambda (t) (eq? (token-type t) 'typed-hole)) toks))
  (check-true (and hole-tok #t) "should find typed-hole token")
  (check-false (token-value hole-tok) "unnamed hole has #f value"))

(test-case "reader: ??name tokenizes as named typed-hole"
  (define toks (tokenize-string "??goal"))
  (define hole-tok
    (findf (lambda (t) (eq? (token-type t) 'typed-hole)) toks))
  (check-true (and hole-tok #t) "should find typed-hole token")
  (check-equal? (token-value hole-tok) 'goal))

(test-case "parser: ?? produces surf-typed-hole"
  ;; parse in sexp mode: ($typed-hole) sentinel
  ;; datum->syntax requires: (list source line col pos span) where pos is exact-positive-integer?
  (define stx (datum->syntax #f '($typed-hole) (list "<t>" 1 0 1 1)))
  (define surf (parse-datum stx))
  (check-true (surf-typed-hole? surf))
  (check-false (surf-typed-hole-name surf)))

(test-case "parser: ??name produces named surf-typed-hole"
  (define stx (datum->syntax #f '($typed-hole goal) (list "<t>" 1 0 1 6)))
  (define surf (parse-datum stx))
  (check-true (surf-typed-hole? surf))
  (check-equal? (surf-typed-hole-name surf) 'goal))

(test-case "elaborator: surf-typed-hole → expr-typed-hole"
  (define surf (surf-typed-hole 'goal srcloc-unknown))
  (define expr (elaborate surf))
  (check-true (expr-typed-hole? expr))
  (check-equal? (expr-typed-hole-name expr) 'goal))

(test-case "elaborator: unnamed surf-typed-hole → expr-typed-hole"
  (define surf (surf-typed-hole #f srcloc-unknown))
  (define expr (elaborate surf))
  (check-true (expr-typed-hole? expr))
  (check-false (expr-typed-hole-name expr)))

(test-case "pretty-print: expr-typed-hole renders as ??"
  (define s (pp-expr (expr-typed-hole #f)))
  (check-equal? s "??"))

(test-case "pretty-print: named expr-typed-hole renders as ??name"
  (define s (pp-expr (expr-typed-hole 'goal)))
  (check-equal? s "??goal"))

;; ========================================
;; 6. ?? Typed holes — type checking
;; ========================================

(test-case "typed hole: ?? in defn emits diagnostic and type-checks"
  ;; A spec + defn where the body is ??  should succeed
  ;; (typed holes are always accepted with the expected type)
  (define output
    (parameterize ([current-error-port (open-output-string)])
      (define results
        (parameterize ([current-global-env (hasheq)]
                       [current-spec-store (hasheq)]
                       [current-property-store (hasheq)]
                       [current-functor-store (hasheq)]
                       [current-preparse-registry (current-preparse-registry)]
                       [current-trait-registry (hasheq)]
                       [current-trait-laws (hasheq)])
          (process-string
            (string-append
              "(spec myid Nat -> Nat)\n"
              "(defn myid [x] ($typed-hole))"))))
      (get-output-string (current-error-port))))
  ;; The diagnostic should mention "Hole ??"
  (check-true (string-contains? output "Hole ??")
              (format "Expected diagnostic containing 'Hole ??', got: ~a" output)))

;; ========================================
;; 7. :laws on trait declarations
;; ========================================

(test-case "trait: basic trait has empty laws"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string "(trait (Eq (A : (Type 0))) (eq? : A -> A -> Bool))")
    (define tm (lookup-trait 'Eq))
    (check-true (trait-meta? tm))
    (check-equal? (lookup-trait-laws 'Eq) '())))

(test-case "trait: :laws extracted from metadata"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    (process-string
      (string-append
        "(trait Functor ($brace-params F : (-> (Type 0) (Type 0)))"
        "  (fmap : (-> A B) -> (F A) -> (F B))"
        "  ($brace-params :laws (functor-laws F)))"))
    (define tm (lookup-trait 'Functor))
    (check-true (trait-meta? tm))
    (define laws (lookup-trait-laws 'Functor))
    (check-true (>= (length laws) 1) "should have at least 1 law reference")
    ;; The law reference should be '(functor-laws F)
    (check-equal? (car laws) '(functor-laws F))))

;; ========================================
;; 8. rewrite-implicit-map for spec/trait
;; ========================================

(test-case "rewrite-implicit-map: recognizes spec as trigger head"
  ;; Test that rewrite-implicit-map handles spec forms with keyword children
  (define datum
    '(spec sort ($brace-params A : (Type 0)) (List A) -> (List A)
           ($brace-params :where (Ord A) :doc "Sort")))
  ;; rewrite-implicit-map should pass this through (it's already in brace-params form)
  (define result (rewrite-implicit-map datum))
  ;; The datum should remain well-formed with $brace-params
  (check-true (list? result)))

(test-case "rewrite-implicit-map: recognizes trait as trigger head"
  (define datum
    '(trait MyTrait ($brace-params A)
           (foo : A -> A)
           ($brace-params :laws (my-laws A))))
  (define result (rewrite-implicit-map datum))
  (check-true (list? result)))

;; ========================================
;; 9. keyword-like-symbol? utility
;; ========================================

(test-case "keyword-like-symbol?: recognizes :doc"
  (check-true (keyword-like-symbol? ':doc)))

(test-case "keyword-like-symbol?: rejects non-keyword"
  (check-false (keyword-like-symbol? 'foo)))

(test-case "keyword-like-symbol?: rejects non-symbol"
  (check-false (keyword-like-symbol? 42)))

;; ========================================
;; 10. Integration: spec metadata end-to-end (sexp mode)
;; ========================================

(test-case "integration: spec with :doc works with defn"
  (define results
    (run (string-append
           "(spec add Nat Nat -> Nat ($brace-params :doc \"Addition\"))\n"
           "(defn add [x y]\n"
           "  (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
           "(eval (add (suc zero) (suc (suc zero))))")))
  (check-true (>= (length results) 2))
  (check-equal? (last results) "3N : Nat"))

(test-case "integration: spec with metadata stores correctly"
  (define se (spec-for 'add2
    "(spec add2 Nat Nat -> Nat ($brace-params :doc \"Add two\" :see-also (sub)))"))
  (check-true (spec-entry? se))
  (check-equal? (spec-entry-docstring se) "Add two")
  (define md (spec-entry-metadata se))
  (check-true (hash? md))
  (check-equal? (hash-ref md ':doc) "Add two"))

;; ========================================
;; 8. Phase 1b: Auto-introduce free type variables
;; ========================================

(test-case "capitalized-symbol?: uppercase vs lowercase"
  (check-true (capitalized-symbol? 'Foo))
  (check-true (capitalized-symbol? 'A))
  (check-true (capitalized-symbol? 'List))
  (check-false (capitalized-symbol? 'foo))
  (check-false (capitalized-symbol? '->))
  (check-false (capitalized-symbol? '$brace-params))
  (check-false (capitalized-symbol? ':doc)))

(test-case "collect-free-type-vars: collects capitalized symbols from datums"
  (check-equal? (collect-free-type-vars-from-datums '(Nat -> Nat)) '(Nat))
  (check-equal? (collect-free-type-vars-from-datums '((List A) -> Nat))
                '(List A Nat))
  (check-equal? (collect-free-type-vars-from-datums '((List A) -> (List B)))
                '(List A B)))

(test-case "collect-free-type-vars: deduplicates"
  (check-equal? (collect-free-type-vars-from-datums '(A -> A)) '(A)))

(test-case "collect-free-type-vars: ignores non-symbol datums"
  (check-equal? (collect-free-type-vars-from-datums '(42 "hello" A)) '(A)))

(test-case "spec: auto-introduces free type variable A"
  (define se (spec-for 'mylen "(spec mylen (List A) -> Nat)"))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  (check-true (pair? binders))
  ;; A should be auto-detected (List is known, Nat is known)
  (define a-binder (assq 'A binders))
  (check-true (pair? a-binder))
  (check-equal? (cdr a-binder) '(Type 0)))

(test-case "spec: auto-introduces multiple free type vars"
  (define se (spec-for 'myfoo "(spec myfoo A -> B -> A)"))
  (check-true (spec-entry? se))
  (define binders (spec-entry-implicit-binders se))
  ;; Both A and B should be auto-detected
  (check-true (pair? (assq 'A binders)))
  (check-true (pair? (assq 'B binders))))

(test-case "spec: doesn't auto-introduce known types like Nat, List"
  (define se (spec-for 'myid "(spec myid A -> A)"))
  (define binders (spec-entry-implicit-binders se))
  ;; Only A, not builtins
  (check-equal? (length binders) 1)
  (check-equal? (caar binders) 'A))

(test-case "spec: explicit binders not duplicated by auto-detection"
  (define se (spec-for 'myfoo2 "(spec myfoo2 ($brace-params A : Type) A -> A)"))
  (define binders (spec-entry-implicit-binders se))
  ;; Only one A, not duplicated
  (check-equal? (length binders) 1)
  (check-equal? (caar binders) 'A))

(test-case "spec: auto-introduced vars with explicit binder coexist"
  (define se (spec-for 'mypair "(spec mypair ($brace-params A : Type) A -> B -> (A B))"))
  (define binders (spec-entry-implicit-binders se))
  ;; A is explicit, B is auto-detected
  (check-equal? (length binders) 2)
  (check-true (pair? (assq 'A binders)))
  (check-true (pair? (assq 'B binders))))

;; ========================================
;; 9. Phase 1b: Kind inference from :where
;; ========================================

(test-case "spec: kind refined from :where constraint (HKT)"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    ;; Register a trait with Type -> Type param
    (process-string "(trait (MySeq (C : (-> (Type 0) (Type 0)))) (first : (C Nat) -> Nat))")
    ;; Now spec without explicit binder for C
    (process-string "(spec gmap (C A) -> (C A) where (MySeq C))")
    (define se (lookup-spec 'gmap))
    (check-true (spec-entry? se))
    (define binders (spec-entry-implicit-binders se))
    ;; C should be auto-detected and refined to (-> (Type 0) (Type 0))
    (define c-binder (assq 'C binders))
    (check-true (pair? c-binder))
    (check-equal? (cdr c-binder) '(-> (Type 0) (Type 0)))
    ;; A should remain at default kind (Type 0)
    (define a-binder (assq 'A binders))
    (check-true (pair? a-binder))
    (check-equal? (cdr a-binder) '(Type 0))))

(test-case "spec: auto-detect from where-only variable"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)])
    ;; Register trait
    (process-string "(trait (MyEq (A : (Type 0))) (eq? : A -> A -> Bool))")
    ;; B appears only in where clause, not in type signature
    (process-string "(spec mydefault Nat where (MyEq B))")
    (define se (lookup-spec 'mydefault))
    (check-true (spec-entry? se))
    (define binders (spec-entry-implicit-binders se))
    ;; B should be auto-detected from the constraint args
    (define b-binder (assq 'B binders))
    (check-true (pair? b-binder))))
