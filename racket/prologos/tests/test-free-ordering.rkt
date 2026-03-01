#lang racket/base

;;;
;;; Tests for free ordering of declarations within a module.
;;;
;;; Phase 5a (three-pass pre-registration) enables registries to be
;;; populated regardless of source order: data, trait, deftype, etc.
;;; in Pass 0; spec, impl in Pass 1.
;;;
;;; Phase 5b (declaration-first output ordering) ensures generated
;;; defs from data/trait/impl are hoisted before user defn/def,
;;; so constructor/accessor types enter global-env first.
;;;
;;; Together, these enable:
;;;   - defn before data (using constructors from a later data decl)
;;;   - spec after defn (Phase 5 original, inherited from spec pre-scan)
;;;   - Mixed orderings of all declaration forms
;;;
;;; Note: sexp-mode impl with inline defn has a pre-existing limitation
;;; (paren-shape loss makes generated defn forms unparseable). Those
;;; orderings are tested via .prologos files in the stdlib book.
;;;

(require rackunit
         racket/list
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt")

;; ========================================
;; Helper
;; ========================================
;; Reset global-env and spec-store per test for isolation.
;; Keep prelude registries (ctor-registry, type-meta, trait-registry, etc.)
;; so that Nat/Bool/etc. constructors and types are available.
(define (run s)
  (parameterize ([current-global-env (hasheq)]
                 [current-spec-store (hasheq)])
    (process-string s)))

(define (run-last s)
  (last (run s)))

;; ========================================
;; 1. Baseline: data before defn (normal order)
;; ========================================

(test-case "free-ordering: data before defn (baseline)"
  (check-equal?
   (run-last
    (string-append
     "(data Box (mk-box : Nat))\n"
     "(spec wrap Nat -> Box)\n"
     "(defn wrap [x] (mk-box x))\n"
     "(eval (wrap (suc (suc zero))))"))
   "[mk-box 2N] : Box"))

;; ========================================
;; 2. Defn before data (Phase 5b forward reference)
;; ========================================

(test-case "free-ordering: defn before data — constructor in defn body"
  ;; defn and spec before data — the key Phase 5b test.
  ;; Pass 0 registers mk-box in ctor-registry.
  ;; Phase 5b hoists (def mk-box : ...) before (defn wrap ...).
  (check-equal?
   (run-last
    (string-append
     "(spec wrap Nat -> Box)\n"
     "(defn wrap [x] (mk-box x))\n"
     "(data Box (mk-box : Nat))\n"
     "(eval (wrap (suc zero)))"))
   "[mk-box 1N] : Box"))

(test-case "free-ordering: defn before data — pattern match on later data"
  (check-equal?
   (run-last
    (string-append
     "(spec unbox Box -> Nat)\n"
     "(defn unbox [b] (match b (mk-box n -> n)))\n"
     "(data Box (mk-box : Nat))\n"
     "(eval (unbox (mk-box (suc (suc (suc zero))))))"))
   "3N : Nat"))

;; ========================================
;; 3. Multi-constructor data after defn
;; ========================================

(test-case "free-ordering: defn before data — multi-constructor match"
  (check-equal?
   (run-last
    (string-append
     "(spec get-value Shape -> Nat)\n"
     "(defn get-value [s] (match s (circle r -> r) (square w -> w)))\n"
     "(data Shape (circle : Nat) (square : Nat))\n"
     "(eval (get-value (circle (suc (suc (suc zero))))))"))
   "3N : Nat"))

;; ========================================
;; 4. Data at the very end of module
;; ========================================

(test-case "free-ordering: data at the very end"
  ;; spec, defn all before data definition
  (check-equal?
   (run-last
    (string-append
     "(spec id-tag Tag -> Tag)\n"
     "(defn id-tag [t] (match t (mk-tag n -> (mk-tag n))))\n"
     "(data Tag (mk-tag : Nat))\n"
     "(eval (id-tag (mk-tag (suc (suc zero)))))"))
   "[mk-tag 2N] : Tag"))

;; ========================================
;; 5. Multi-field constructor from later data
;; ========================================

(test-case "free-ordering: defn uses multi-field constructor from later data"
  (check-equal?
   (run-last
    (string-append
     "(spec make-pair Nat -> Bool -> MyPair)\n"
     "(defn make-pair [n b] (mk-pair n b))\n"
     "(data MyPair (mk-pair : Nat -> Bool))\n"
     "(eval (make-pair (suc zero) true))"))
   "[mk-pair 1N true] : MyPair"))

;; ========================================
;; 6. Defn-before-spec + defn-before-data combined
;; ========================================

(test-case "free-ordering: combined spec-after and data-after"
  ;; Both spec and data appear after defn — tests Phase 5 (spec pre-scan)
  ;; and Phase 5b (declaration-first output) working together.
  (check-equal?
   (run-last
    (string-append
     "(defn get-len [v] (match v (mk-val n -> n)))\n"
     "(spec get-len Val -> Nat)\n"
     "(data Val (mk-val : Nat))\n"
     "(eval (get-len (mk-val (suc (suc (suc (suc zero)))))))"))
   "4N : Nat"))

;; ========================================
;; 7. Two data types, both after defns
;; ========================================

(test-case "free-ordering: two data types both after defn that uses them"
  ;; defn references constructors from TWO different data types,
  ;; both of which appear later in source order.
  (check-equal?
   (run-last
    (string-append
     "(spec convert-ab Atype -> Btype)\n"
     "(defn convert-ab [a] (match a (mk-a n -> (mk-b n))))\n"
     "(data Atype (mk-a : Nat))\n"
     "(data Btype (mk-b : Nat))\n"
     "(eval (convert-ab (mk-a (suc (suc zero)))))"))
   "[mk-b 2N] : Btype"))

;; ========================================
;; 8. Spec between defn and data
;; ========================================

(test-case "free-ordering: spec sandwiched between defn and data"
  ;; defn first, then spec, then data — tests that spec pre-scan
  ;; and declaration-first output interact correctly.
  (check-equal?
   (run-last
    (string-append
     "(defn wrap-it [x] (mk-wrap x))\n"
     "(spec wrap-it Nat -> Wrap)\n"
     "(data Wrap (mk-wrap : Nat))\n"
     "(eval (wrap-it (suc (suc zero))))"))
   "[mk-wrap 2N] : Wrap"))

;; ========================================
;; 9. Nullary constructors from later data
;; ========================================

(test-case "free-ordering: defn uses nullary constructor from later data"
  (check-equal?
   (run-last
    (string-append
     "(spec make-red Unit -> RGB)\n"
     "(defn make-red [u] r)\n"
     "(data RGB (r) (g) (b))\n"
     "(eval (make-red unit))"))
   "r : RGB"))

;; ========================================
;; 10. Spec after data after defn (all reversed)
;; ========================================

(test-case "free-ordering: fully reversed — defn, then data, then spec"
  ;; Complete reversal of "natural" order. Spec is last.
  (check-equal?
   (run-last
    (string-append
     "(defn make-w [x] (mk-widget x))\n"
     "(data Widget (mk-widget : Nat))\n"
     "(spec make-w Nat -> Widget)\n"
     "(eval (make-w (suc (suc (suc (suc (suc zero)))))))"))
   "[mk-widget 5N] : Widget"))
