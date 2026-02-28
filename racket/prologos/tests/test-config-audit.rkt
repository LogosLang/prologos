#lang racket/base

;;;
;;; Tests for Configuration Language Hardening (Spec/Functor/Trait/Property audit)
;;; Covers: G1-G9 gaps, O4-O7/O11 opportunities
;;; Reference: docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md
;;;

(require rackunit
         racket/list
         racket/string
         "../macros.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../reader.rkt"
         "../source-location.rkt"
         "../warnings.rkt"
         "../metavar-store.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Process WS-mode string through the full pipeline
(define (process-string-ws s)
  (define port (open-input-string s))
  (port-count-lines! port)
  (define raw-stxs (prologos-read-syntax-all "<ws-test>" port))
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; Process WS-mode string and return trait from store
(define (trait-for-ws name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-bundle-registry (hasheq)])
    (process-string-ws s)
    (lookup-trait name)))

;; Process WS-mode string and return functor from store
(define (functor-for-ws name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-bundle-registry (hasheq)])
    (process-string-ws s)
    (lookup-functor name)))

;; Process WS-mode string and return property from store
(define (property-for-ws name s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-bundle-registry (hasheq)])
    (process-string-ws s)
    (lookup-property name)))

;; ========================================
;; Section 1: trait-meta metadata field (G5)
;; ========================================

(test-case "G5: trait-meta has metadata field"
  (define tm (trait-meta 'Foo '((A . (Type 0))) '() (hasheq ':doc "A test trait")))
  (check-equal? (trait-meta-metadata tm) (hasheq ':doc "A test trait")))

(test-case "G5: trait-meta backward compat with empty metadata"
  (define tm (trait-meta 'Foo '((A . (Type 0))) '() (hasheq)))
  (check-equal? (trait-meta-metadata tm) (hasheq)))

(test-case "G5: process-trait stores :doc in metadata"
  (define tm
    (trait-for-ws 'MyTrait
      (string-append
       "trait MyTrait {A}\n"
       "  method : A -> A\n"
       "  :doc \"A documented trait\"\n")))
  (check-not-false tm)
  (check-equal? (hash-ref (trait-meta-metadata tm) ':doc #f) "A documented trait"))

(test-case "G5: process-trait stores :deprecated in metadata"
  (define tm
    (trait-for-ws 'OldTrait
      (string-append
       "trait OldTrait {A}\n"
       "  method : A -> Bool\n"
       "  :deprecated \"use NewTrait instead\"\n")))
  (check-not-false tm)
  (check-equal? (hash-ref (trait-meta-metadata tm) ':deprecated #f) "use NewTrait instead"))

(test-case "G5: trait :laws still registers in trait-laws store"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-bundle-registry (hasheq)])
    ;; Register a property first
    (register-property! 'my-laws
      (property-entry 'my-laws '() '() '()
        (list (property-clause "test" #f '(eq? a b)))
        (hasheq)))
    (process-string-ws
      (string-append
       "trait TestLaws {A}\n"
       "  op : A -> A\n"
       "  :laws (my-laws A)\n"))
    (check-not-false (lookup-trait-laws 'TestLaws))
    (check-equal? (length (lookup-trait-laws 'TestLaws)) 1)))

(test-case "G5: trait-doc accessor function"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'DocTrait
      (trait-meta 'DocTrait '((A . (Type 0))) '()
                  (hasheq ':doc "documented")))
    (check-equal? (trait-doc 'DocTrait) "documented")
    (check-false (trait-doc 'NonExistent))))

(test-case "G5: trait-deprecated accessor function"
  (parameterize ([current-trait-registry (hasheq)])
    (register-trait! 'OldTrait
      (trait-meta 'OldTrait '((A . (Type 0))) '()
                  (hasheq ':deprecated "use NewTrait")))
    (check-equal? (trait-deprecated 'OldTrait) "use NewTrait")
    (check-false (trait-deprecated 'NonExistent))))

;; ========================================
;; Section 2: bundle-entry metadata field (G6)
;; ========================================

(test-case "G6: bundle-entry has metadata field"
  (define be (bundle-entry 'Foo '(A) '((Eq A)) (hasheq ':doc "test")))
  (check-equal? (bundle-entry-metadata be) (hasheq ':doc "test")))

(test-case "G6: process-bundle stores empty metadata"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) '() (hasheq)))
    (register-trait! 'Ord (trait-meta 'Ord '(A) '() (hasheq)))
    (process-bundle '(bundle Cmp := (Eq Ord)))
    (define b (lookup-bundle 'Cmp))
    (check-not-false b)
    (check-equal? (bundle-entry-metadata b) (hasheq))))

(test-case "G6: bundle-doc accessor function"
  (parameterize ([current-bundle-registry (hasheq)])
    ;; bundle-doc returns #f when no :doc in metadata
    (register-bundle! 'TestBundle
      (bundle-entry 'TestBundle '(A) '((Eq A)) (hasheq)))
    (check-false (bundle-doc 'TestBundle))
    (check-false (bundle-doc 'NonExistent))))

(test-case "G6: bundle backward compat — existing bundles parse correctly"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A) '() (hasheq)))
    (register-trait! 'Ord (trait-meta 'Ord '(A) '() (hasheq)))
    (process-bundle '(bundle Comparable := (Eq Ord)))
    (define b (lookup-bundle 'Comparable))
    (check-equal? (bundle-entry-name b) 'Comparable)
    (check-equal? (bundle-entry-params b) '(A))
    (check-equal? (bundle-entry-constraints b) '((Eq A) (Ord A)))))

;; ========================================
;; Section 3: Implicits kind conflict (G2)
;; ========================================

(test-case "G2: dedup binders — same kind → OK, uses inline"
  (define result
    (deduplicate-binders
     '((A . (Type 0)))      ;; inline
     '((A . (Type 0)))))    ;; metadata — same kind
  (check-equal? (length result) 1)
  (check-equal? (cdar result) '(Type 0)))

(test-case "G2: dedup binders — different kinds → error"
  (check-exn
   #rx"implicit binder `A`.*declared as.*inline but"
   (lambda ()
     (deduplicate-binders
      '((A . (Type 0)))              ;; inline: A : Type
      '((A . (-> (Type 0) (Type 0))))))))  ;; metadata: A : Type -> Type

(test-case "G2: dedup binders — no overlap → both kept"
  (define result
    (deduplicate-binders
     '((A . (Type 0)))       ;; inline
     '((B . (Type 0)))))     ;; metadata — different name
  (check-equal? (length result) 2))

(test-case "G2: dedup binders — partial overlap"
  (define result
    (deduplicate-binders
     '((A . (Type 0)) (B . (Type 0)))
     '((B . (Type 0)) (C . (Type 0)))))
  ;; A from inline, B from inline (dedup), C from metadata
  (check-equal? (length result) 3)
  (check-equal? (map car result) '(A B C)))

;; ========================================
;; Section 4: Functor/data collision (G4)
;; ========================================

(test-case "G4: functor with unique name → OK"
  (define fe
    (functor-for-ws 'MyAlias
      "functor MyAlias {A : Type}\n  :unfolds A\n"))
  (check-not-false fe)
  (check-equal? (functor-entry-name fe) 'MyAlias))

(test-case "G4: functor conflicting with data type → error"
  (check-exn
   #rx"functor `Result` conflicts with existing data type"
   (lambda ()
     (parameterize ([current-global-env (hasheq)]
                    [current-spec-store (hasheq)]
                    [current-property-store (hasheq)]
                    [current-functor-store (hasheq)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-trait-registry (hasheq)]
                    [current-trait-laws (hasheq)]
                    [current-ctor-registry (hasheq)]
                    [current-type-meta (hasheq)]
                    [current-bundle-registry (hasheq)])
       ;; Register a data type constructor
       (register-ctor! 'Result (ctor-meta 'Result '() '() #f 0))
       ;; Now try to register functor with same name — should error
       (process-string-ws "functor Result {A : Type}\n  :unfolds A\n")))))

(test-case "G4: functor conflicting with type name → error"
  (check-exn
   #rx"functor `MyData` conflicts with existing data type"
   (lambda ()
     (parameterize ([current-global-env (hasheq)]
                    [current-spec-store (hasheq)]
                    [current-property-store (hasheq)]
                    [current-functor-store (hasheq)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-trait-registry (hasheq)]
                    [current-trait-laws (hasheq)]
                    [current-ctor-registry (hasheq)]
                    [current-type-meta (hasheq 'MyData '())]
                    [current-bundle-registry (hasheq)])
       (process-string-ws "functor MyData {A : Type}\n  :unfolds A\n")))))

;; ========================================
;; Section 5: :pre/:post/:invariant parsing + mutual exclusion (G1 + O6)
;; ========================================

(test-case "O6: :pre parsed and stored in metadata"
  (define md (parse-spec-metadata '($brace-params :pre (fn (a) (positive? a)))))
  (check-not-false (hash-ref md ':pre #f))
  (check-equal? (hash-ref md ':pre) '(fn (a) (positive? a))))

(test-case "O6: :post parsed and stored in metadata"
  (define md (parse-spec-metadata '($brace-params :post (fn (a b) (> b a)))))
  (check-not-false (hash-ref md ':post #f)))

(test-case "O6: :invariant parsed and stored in metadata"
  (define md (parse-spec-metadata '($brace-params :invariant (fn (a b) (> b 0)))))
  (check-not-false (hash-ref md ':invariant #f)))

(test-case "O6: :pre with no value → error"
  (check-exn
   #rx":pre requires a predicate expression"
   (lambda () (parse-spec-metadata '($brace-params :pre)))))

(test-case "O6: :post with no value → error"
  (check-exn
   #rx":post requires a predicate expression"
   (lambda () (parse-spec-metadata '($brace-params :post)))))

(test-case "G1: :pre + :post together → OK"
  ;; No error — these have compatible semantics (split obligations)
  (define md (parse-spec-metadata
    '($brace-params :pre (fn (a) #t) :post (fn (a b) #t))))
  (check-not-false (hash-ref md ':pre #f))
  (check-not-false (hash-ref md ':post #f)))

(test-case "G1: :invariant + :pre → error at process-spec level"
  ;; The mutual exclusion check is in process-spec — test via sexp-mode
  (check-exn
   #rx"`:invariant` and `:pre`/`:post` have different proof obligation semantics"
   (lambda ()
     (parameterize ([current-global-env (hasheq)]
                    [current-spec-store (hasheq)]
                    [current-property-store (hasheq)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-trait-registry (hasheq)]
                    [current-trait-laws (hasheq)]
                    [current-bundle-registry (hasheq)])
       (process-spec
         '(spec bad-spec Nat -> Nat
           ($brace-params :pre (fn (a) #t) :invariant (fn (a b) #t))))))))

(test-case "G1: :invariant + :post → error"
  (check-exn
   #rx"`:invariant` and `:pre`/`:post` have different proof obligation semantics"
   (lambda ()
     (parameterize ([current-global-env (hasheq)]
                    [current-spec-store (hasheq)]
                    [current-property-store (hasheq)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-trait-registry (hasheq)]
                    [current-trait-laws (hasheq)]
                    [current-bundle-registry (hasheq)])
       (process-spec
         '(spec bad-spec Nat -> Nat
           ($brace-params :post (fn (a b) #t) :invariant (fn (a b) #t))))))))

;; ========================================
;; Section 6: Functor Phase 2 keys (O4, O5)
;; ========================================

(test-case "O4: :variance :covariant stored in functor metadata"
  (define fe
    (functor-for-ws 'Pred
      "functor Pred {A : Type}\n  :unfolds [A -> Bool]\n  :variance :contravariant\n"))
  (check-not-false fe)
  (check-equal? (hash-ref (functor-entry-metadata fe) ':variance #f) ':contravariant))

(test-case "O4: :variance :covariant stored"
  (define md (parse-spec-metadata '($brace-params :variance :covariant)))
  (check-equal? (hash-ref md ':variance) ':covariant))

(test-case "O4: :variance :phantom stored"
  (define md (parse-spec-metadata '($brace-params :variance :phantom)))
  (check-equal? (hash-ref md ':variance) ':phantom))

(test-case "O4: :variance with invalid value → error"
  (check-exn
   #rx":variance must be :covariant, :contravariant, :invariant, or :phantom"
   (lambda () (parse-spec-metadata '($brace-params :variance :bogus)))))

(test-case "O5: :fold stored in metadata"
  (define md (parse-spec-metadata '($brace-params :fold fold-list)))
  (check-equal? (hash-ref md ':fold) 'fold-list))

(test-case "O5: :unfold stored in metadata"
  (define md (parse-spec-metadata '($brace-params :unfold unfold-list)))
  (check-equal? (hash-ref md ':unfold) 'unfold-list))

(test-case "O5: :fold requires an identifier"
  (check-exn
   #rx":fold requires an identifier"
   (lambda () (parse-spec-metadata '($brace-params :fold (not a symbol))))))

(test-case "O5: :unfold requires an identifier"
  (check-exn
   #rx":unfold requires an identifier"
   (lambda () (parse-spec-metadata '($brace-params :unfold)))))

;; ========================================
;; Section 7: Property :exists (O7)
;; ========================================

(test-case "O7: :exists clause parsed with binders"
  (define pe
    (property-for-ws 'has-fp
      (string-append
       "(property has-fp ($brace-params A : (Type 0))\n"
       "  (- :name \"fixed-point\"\n"
       "     :exists ($brace-params x : A)\n"
       "     :holds (eq? (f x) x))\n"
       "  ($brace-params :where (Eq A)))\n")))
  (check-not-false pe)
  (define clause (car (property-entry-clauses pe)))
  ;; forall-binders field should be tagged with :exists
  (check-equal? (car (property-clause-forall-binders clause)) ':exists))

(test-case "O7: :forall clause still works (backward compat)"
  (define pe
    (property-for-ws 'assoc-law
      (string-append
       "(property assoc-law ($brace-params A : (Type 0))\n"
       "  (- :name \"assoc\"\n"
       "     :forall ($brace-params x : A) ($brace-params y : A) ($brace-params z : A)\n"
       "     :holds (eq? (add (add x y) z) (add x (add y z))))\n"
       "  ($brace-params :where (Add A) (Eq A)))\n")))
  (check-not-false pe)
  (define clause (car (property-entry-clauses pe)))
  ;; forall-binders is a plain list (not tagged with :exists)
  (check-true (pair? (property-clause-forall-binders clause)))
  (check-false (eq? (car (property-clause-forall-binders clause)) ':exists)))

;; ========================================
;; Section 8: Backward compatibility
;; ========================================

(test-case "backward-compat: trait with :laws still works"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-bundle-registry (hasheq)])
    ;; Register a property first
    (register-property! 'eq-laws
      (property-entry 'eq-laws '() '() '()
        (list (property-clause "reflexivity" #f '(eq? x x)))
        (hasheq)))
    (process-string-ws
      (string-append
       "trait Eq {A}\n"
       "  eq? : A -> A -> Bool\n"
       "  :laws (eq-laws A)\n"))
    (define tm (lookup-trait 'Eq))
    (check-not-false tm)
    (check-equal? (trait-meta-name tm) 'Eq)
    (check-equal? (length (trait-meta-methods tm)) 1)
    ;; Laws are stored separately
    (check-equal? (length (lookup-trait-laws 'Eq)) 1)
    ;; Metadata hash exists
    (check-true (hash? (trait-meta-metadata tm)))))

(test-case "backward-compat: bundle expansion still works"
  (parameterize ([current-trait-registry (hasheq)]
                 [current-bundle-registry (hasheq)])
    (register-trait! 'Eq (trait-meta 'Eq '(A)
                           (list (trait-method 'eq? '(A -> A -> Bool))) (hasheq)))
    (register-trait! 'Ord (trait-meta 'Ord '(A)
                            (list (trait-method 'compare '(A -> A -> Nat))) (hasheq)))
    (process-bundle '(bundle Comparable := (Eq Ord)))
    (define expanded (expand-bundle-constraints '((Comparable X))))
    (check-equal? expanded '((Eq X) (Ord X)))))

(test-case "backward-compat: functor still registers as deftype"
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-property-store (hasheq)]
                 [current-functor-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (hasheq)]
                 [current-trait-laws (hasheq)]
                 [current-bundle-registry (hasheq)])
    (process-string-ws "functor AppResult {A : Type}\n  :unfolds (Either String A)\n")
    (define fe (lookup-functor 'AppResult))
    (check-not-false fe)
    (check-equal? (functor-entry-name fe) 'AppResult)))
