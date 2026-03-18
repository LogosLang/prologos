#lang racket/base

;;;
;;; Tests for native collection operation AST primitives (Stages C2-C8).
;;; Verifies that pvec-map, pvec-filter, set-fold, set-filter,
;;; map-fold-entries, map-filter-entries, and map-map-vals reduce natively.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-last s)
  (last (run-ns s)))


;; ========================================
;; C2. pvec-map
;; ========================================

(test-case "pvec-map/type: Nat -> Nat"
  (define result
    (run-last
      (string-append
        "(ns pm-t1)\n"
        "(check (pvec-map (fn [x : Nat] (suc x)) @[1N 2N]) : (PVec Nat))\n")))
  (check-equal? result "OK"))

(test-case "pvec-map/type: Nat -> Bool"
  (define result
    (run-last
      (string-append
        "(ns pm-t2)\n"
        "(check (pvec-map zero? @[1N 0N]) : (PVec Bool))\n")))
  (check-equal? result "OK"))

(test-case "pvec-map/eval: increment"
  (define result
    (run-last
      (string-append
        "(ns pm-e1)\n"
        "(eval (pvec-map (fn [x : Nat] (suc x)) @[0N 1N 2N]))\n")))
  (check-true (string-contains? result "@[1N 2N 3N]")))

(test-case "pvec-map/eval: empty"
  (define result
    (run-last
      (string-append
        "(ns pm-e2)\n"
        "(eval (pvec-map (fn [x : Nat] (suc x)) @[]))\n")))
  (check-true (string-contains? result "@[]")))

(test-case "pvec-map/eval: named function (suc)"
  (define result
    (run-last
      (string-append
        "(ns pm-e3)\n"
        "(spec inc Nat -> Nat)\n"
        "(defn inc [x] (suc x))\n"
        "(eval (pvec-map inc @[0N 1N 2N]))\n")))
  (check-true (string-contains? result "@[1N 2N 3N]")))


;; ========================================
;; C3. pvec-filter
;; ========================================

(test-case "pvec-filter/type: predicate check"
  (define result
    (run-last
      (string-append
        "(ns pf-t1)\n"
        "(check (pvec-filter zero? @[0N 1N]) : (PVec Nat))\n")))
  (check-equal? result "OK"))

(test-case "pvec-filter/eval: keep zeros"
  (define result
    (run-last
      (string-append
        "(ns pf-e1)\n"
        "(eval (pvec-filter zero? @[0N 1N 0N 2N]))\n")))
  (check-true (string-contains? result "@[0N 0N]")))

(test-case "pvec-filter/eval: keep none"
  (define result
    (run-last
      (string-append
        "(ns pf-e2)\n"
        "(eval (pvec-filter zero? @[1N 2N 3N]))\n")))
  (check-true (string-contains? result "@[]")))

(test-case "pvec-filter/eval: keep all"
  (define result
    (run-last
      (string-append
        "(ns pf-e3)\n"
        "(eval (pvec-filter (fn [x : Nat] true) @[1N 2N]))\n")))
  (check-true (string-contains? result "@[1N 2N]")))


;; ========================================
;; C4. set-fold
;; ========================================

(test-case "set-fold/type: count elements"
  (define result
    (run-last
      (string-append
        "(ns sf-t1)\n"
        "(check (set-fold (fn [acc : Nat] [x : Nat] (suc acc)) zero #{1N 2N 3N}) : Nat)\n")))
  (check-equal? result "OK"))

(test-case "set-fold/eval: count elements"
  (define result
    (run-last
      (string-append
        "(ns sf-e1)\n"
        "(eval (set-fold (fn [acc : Nat] [x : Nat] (suc acc)) zero #{1N 2N 3N}))\n")))
  (check-equal? result "3N : Nat"))

(test-case "set-fold/eval: empty set"
  (define result
    (run-last
      (string-append
        "(ns sf-e2)\n"
        "(eval (set-fold (fn [acc : Nat] [x : Nat] (suc acc)) zero (set-empty Nat)))\n")))
  (check-equal? result "0N : Nat"))

(test-case "set-fold/eval: any-true check"
  (define result
    (run-last
      (string-append
        "(ns sf-e3)\n"
        "(eval (set-fold (fn [acc : Bool] [x : Nat] (if (zero? x) true acc)) false #{0N 1N 2N}))\n")))
  (check-equal? result "true : Bool"))


;; ========================================
;; C5. set-filter
;; ========================================

(test-case "set-filter/type: predicate check"
  (define result
    (run-last
      (string-append
        "(ns sfl-t1)\n"
        "(check (set-filter zero? #{0N 1N}) : (Set Nat))\n")))
  (check-equal? result "OK"))

(test-case "set-filter/eval: keep zeros"
  (define result
    (run-last
      (string-append
        "(ns sfl-e1)\n"
        "(eval (set-size (set-filter zero? #{0N 1N 2N})))\n")))
  (check-equal? result "1N : Nat"))

(test-case "set-filter/eval: keep all"
  (define result
    (run-last
      (string-append
        "(ns sfl-e2)\n"
        "(eval (set-size (set-filter (fn [x : Nat] true) #{1N 2N 3N})))\n")))
  (check-equal? result "3N : Nat"))


;; ========================================
;; C6. map-fold-entries
;; ========================================

;; Helper: build Keyword→Nat map inline
(define mk-kw-map
  (string-append
    "(def m2 (map-assoc (map-assoc (map-empty Keyword Nat) :a (suc zero)) :b (suc (suc zero))))\n"))

(test-case "map-fold-entries/type: count entries"
  (define result
    (run-last
      (string-append
        "(ns mfe-t1)\n"
        mk-kw-map
        "(check (map-fold-entries (fn [acc : Nat] [k : Keyword] [v : Nat] (suc acc)) zero m2) : Nat)\n")))
  (check-equal? result "OK"))

(test-case "map-fold-entries/eval: count entries"
  (define result
    (run-last
      (string-append
        "(ns mfe-e1)\n"
        mk-kw-map
        "(eval (map-fold-entries (fn [acc : Nat] [k : Keyword] [v : Nat] (suc acc)) zero m2))\n")))
  (check-equal? result "2N : Nat"))

(test-case "map-fold-entries/eval: sum values"
  (define result
    (run-last
      (string-append
        "(ns mfe-e2)\n"
        mk-kw-map
        "(eval (map-fold-entries (fn [acc : Nat] [k : Keyword] [v : Nat] (add acc v)) zero m2))\n")))
  (check-equal? result "3N : Nat"))

(test-case "map-fold-entries/eval: empty map"
  (define result
    (run-last
      (string-append
        "(ns mfe-e3)\n"
        "(eval (map-fold-entries (fn [acc : Nat] [k : Keyword] [v : Nat] (suc acc)) zero (map-empty Keyword Nat)))\n")))
  (check-equal? result "0N : Nat"))


;; ========================================
;; C7. map-filter-entries
;; ========================================

(test-case "map-filter-entries/type: predicate check"
  (define result
    (run-last
      (string-append
        "(ns mfl-t1)\n"
        mk-kw-map
        "(check (map-filter-entries (fn [k : Keyword] [v : Nat] (zero? v)) m2) : (Map Keyword Nat))\n")))
  (check-equal? result "OK"))

(test-case "map-filter-entries/eval: filter by value"
  (define result
    (run-last
      (string-append
        "(ns mfl-e1)\n"
        "(def m3 (map-assoc (map-assoc (map-empty Keyword Nat) :x zero) :y (suc zero)))\n"
        "(eval (map-size (map-filter-entries (fn [k : Keyword] [v : Nat] (zero? v)) m3)))\n")))
  (check-equal? result "1N : Nat"))

(test-case "map-filter-entries/eval: keep all"
  (define result
    (run-last
      (string-append
        "(ns mfl-e2)\n"
        mk-kw-map
        "(eval (map-size (map-filter-entries (fn [k : Keyword] [v : Nat] true) m2)))\n")))
  (check-equal? result "2N : Nat"))


;; ========================================
;; C8. map-map-vals
;; ========================================

(test-case "map-map-vals/type: Nat -> Nat"
  (define result
    (run-last
      (string-append
        "(ns mmv-t1)\n"
        mk-kw-map
        "(check (map-map-vals (fn [v : Nat] (suc v)) m2) : (Map Keyword Nat))\n")))
  (check-equal? result "OK"))

(test-case "map-map-vals/eval: increment values"
  (define result
    (run-last
      (string-append
        "(ns mmv-e1)\n"
        "(def m4 (map-assoc (map-empty Keyword Nat) :x (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))))) ;; :x = 10N\n"
        "(eval (map-get (map-map-vals (fn [v : Nat] (suc v)) m4) :x))\n")))
  (check-true (string-contains? result "11N")))

(test-case "map-map-vals/eval: empty map"
  (define result
    (run-last
      (string-append
        "(ns mmv-e2)\n"
        "(eval (map-size (map-map-vals (fn [v : Nat] (suc v)) (map-empty Keyword Nat))))\n")))
  (check-equal? result "0N : Nat"))

(test-case "map-map-vals/eval: preserve keys"
  (define result
    (run-last
      (string-append
        "(ns mmv-e3)\n"
        mk-kw-map
        "(eval (map-has-key? (map-map-vals (fn [v : Nat] (suc v)) m2) :a))\n")))
  (check-equal? result "true : Bool"))
