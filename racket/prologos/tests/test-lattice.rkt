#lang racket/base

;;;
;;; Tests for Phase 1: Lattice Trait + Standard Instances
;;; Tests: lattice-trait.prologos (3-method trait) and
;;; lattice-instances.prologos (FlatVal, Interval data types,
;;; Bool/FlatVal/Set/Map/Interval lattice instances).
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (check-contains actual substr [msg #f])
  ;; Convert error structs to strings so we get a useful failure message
  ;; instead of a contract violation on string-contains?.
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

(define (ensure-string v)
  (if (string? v) v (format "~a" v)))

;; ========================================
;; 1. Trait Registration
;; ========================================

(test-case "Lattice-bot accessor type-checks with Bool dict"
  (check-contains
    (run-ns-last "(ns test)\n(def b : Bool (Lattice-bot Bool--Lattice--dict))")
    "defined"))

(test-case "Lattice-join accessor works with Bool dict"
  ;; Accessor returns a function; verify by calling it directly
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-join Bool--Lattice--dict true false))")
    "true : Bool"))

;; ========================================
;; 2. BoolLattice: join=or, bot=false, leq=implies
;; ========================================

(test-case "Bool: bot = false"
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-bot Bool--Lattice--dict))")
    "false : Bool"))

(test-case "Bool: join true false = true (or)"
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-join Bool--Lattice--dict false true))")
    "true : Bool"))

(test-case "Bool: join false false = false"
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-join Bool--Lattice--dict false false))")
    "false : Bool"))

(test-case "Bool: leq false true = true (implies)"
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-leq Bool--Lattice--dict false true))")
    "true : Bool"))

;; ========================================
;; 3. FlatLattice: flat-bot/flat-val/flat-top
;; ========================================

(test-case "FlatVal data: flat-bot type-checks"
  (check-contains
    (run-ns-last "(ns test)\n(def x : (FlatVal Int) flat-bot)")
    "defined"))

(test-case "FlatVal data: flat-val wraps a value"
  (check-contains
    (run-ns-last "(ns test)\n(def x : (FlatVal Int) (flat-val 42))")
    "defined"))

(test-case "FlatVal data: flat-top type-checks"
  (check-contains
    (run-ns-last "(ns test)\n(def x : (FlatVal Int) flat-top)")
    "defined"))

(test-case "FlatVal: join flat-bot x = x (bot identity)"
  (check-contains
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-join (FlatVal-A--Lattice--dict Int--Eq--dict) flat-bot (flat-val 5)))"))
    "flat-val"))

(test-case "FlatVal: join different values = flat-top"
  (check-contains
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-join (FlatVal-A--Lattice--dict Int--Eq--dict) (flat-val 1) (flat-val 2)))"))
    "flat-top"))

;; ========================================
;; 4. SetLattice: join=union, bot=empty, leq=subset
;; ========================================

(test-case "Set: bot = empty set"
  (check-contains
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-bot (Set-A--Lattice--dict Int--Eq--dict)))"))
    "#{}"))

(test-case "Set: join = union"
  (check-contains
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-join (Set-A--Lattice--dict Int--Eq--dict)"
        " (set-insert (set-empty Int) 1) (set-insert (set-empty Int) 2)))"))
    "#{"))

(test-case "Set: leq = subset (positive)"
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-leq (Set-A--Lattice--dict Int--Eq--dict)"
        " (set-insert (set-empty Int) 1)"
        " (set-insert (set-insert (set-empty Int) 1) 2)))"))
    "true : Bool"))

(test-case "Set: leq = subset (negative)"
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-leq (Set-A--Lattice--dict Int--Eq--dict)"
        " (set-insert (set-insert (set-empty Int) 1) 2)"
        " (set-insert (set-empty Int) 1)))"))
    "false : Bool"))

;; ========================================
;; 5. MapLattice: pointwise join, bot=empty, leq=pointwise
;; ========================================

(test-case "Map: bot is an empty map"
  (check-contains
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(def empty-map : (Map Int Bool) (Lattice-bot (Map-K-V--Lattice--dict Bool--Lattice--dict)))"))
    "defined"))

(test-case "Map: join merges pointwise (Bool or)"
  ;; Join two maps with same key: {1→false} ⊔ {1→true} → {1→true}
  ;; Use intermediate bindings because inference can't compose accessor + map-get.
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(def m1 : (Map Int Bool) (map-assoc (map-empty Int Bool) 1 false))\n"
        "(def m2 : (Map Int Bool) (map-assoc (map-empty Int Bool) 1 true))\n"
        "(def j : (Map Int Bool) (Lattice-join (Map-K-V--Lattice--dict Bool--Lattice--dict) m1 m2))\n"
        "(eval (map-get j 1))"))
    "true : Bool"))

(test-case "Map: leq on empty map is true"
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(def em : (Map Int Bool) (Lattice-bot (Map-K-V--Lattice--dict Bool--Lattice--dict)))\n"
        "(def m1 : (Map Int Bool) (map-assoc (map-empty Int Bool) 1 true))\n"
        "(eval (Lattice-leq (Map-K-V--Lattice--dict Bool--Lattice--dict) em m1))"))
    "true : Bool"))

(test-case "Map: join of disjoint maps merges both"
  ;; {1→false} ⊔ {2→true} should contain both keys
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(def m1 : (Map Int Bool) (map-assoc (map-empty Int Bool) 1 false))\n"
        "(def m3 : (Map Int Bool) (map-assoc (map-empty Int Bool) 2 true))\n"
        "(def j : (Map Int Bool) (Lattice-join (Map-K-V--Lattice--dict Bool--Lattice--dict) m1 m3))\n"
        "(eval (map-has-key? j 2))"))
    "true : Bool"))

;; ========================================
;; 6. IntervalLattice: join=intersection, bot=unconstrained, leq=subsumes
;; ========================================

(test-case "Interval: bot type-checks"
  (check-contains
    (run-ns-last "(ns test)\n(def x : Interval interval-bot)")
    "defined"))

(test-case "Interval: mk-interval type-checks"
  (check-contains
    (run-ns-last "(ns test)\n(def x : Interval (mk-interval (the Rat 1) (the Rat 10)))")
    "defined"))

(test-case "Interval: join of bot and interval = interval"
  (check-contains
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-join Interval--Lattice--dict interval-bot (mk-interval (the Rat 1) (the Rat 5))))"))
    "mk-interval"))

(test-case "Interval: leq bot _ = true"
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-leq Interval--Lattice--dict interval-bot (mk-interval (the Rat 1) (the Rat 5))))"))
    "true : Bool"))

;; ========================================
;; 7. Laws
;; ========================================

(test-case "Bool: join is commutative"
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-join Bool--Lattice--dict true false))")
    (run-ns-last "(ns test)\n(eval (Lattice-join Bool--Lattice--dict false true))")))

(test-case "Bool: bot is identity for join"
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(eval (Lattice-join Bool--Lattice--dict (Lattice-bot Bool--Lattice--dict) true))"))
    "true : Bool"))

;; ========================================
;; 8. Zero-arg defn (Phase 1b regression tests)
;; ========================================

(test-case "Zero-arg defn with inline return type"
  (check-equal?
    (run-ns-last "(ns test)\n(defn my-nat [] <Nat> 42N)\n(eval [my-nat])")
    "42N : Nat"))

(test-case "Zero-arg defn with spec"
  (check-equal?
    (run-ns-last
      (string-append
        "(ns test)\n"
        "(spec my-bool -> Bool)\n"
        "(defn my-bool [] true)\n"
        "(eval [my-bool])"))
    "true : Bool"))

(test-case "Zero-arg defn: impl Lattice Bool bot via accessor"
  ;; Verifies that monomorphic impl with zero-arg bot works
  (check-equal?
    (run-ns-last "(ns test)\n(eval (Lattice-bot Bool--Lattice--dict))")
    "false : Bool"))
