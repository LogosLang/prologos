#lang racket/base

;;;
;;; Unit tests for rewrite-implicit-map
;;;
;;; Tests the rewrite-implicit-map preparse macro in isolation:
;;; keyword-headed tails on def/defn forms → $brace-params map literals.
;;;

(require rackunit
         "../macros.rkt")

;; ========================================
;; A. Unit tests: rewrite-implicit-map
;; ========================================

(test-case "rewrite-implicit-map: basic def with keyword children"
  (check-equal?
   (rewrite-implicit-map '(def m (:name "Alice") (:age 25)))
   '(def m ($brace-params :name "Alice" :age 25))))

(test-case "rewrite-implicit-map: nested keyword children"
  (check-equal?
   (rewrite-implicit-map '(def m (:server (:host "localhost") (:port 8080))))
   '(def m ($brace-params :server ($brace-params :host "localhost" :port 8080)))))

(test-case "rewrite-implicit-map: type-annotated def"
  (check-equal?
   (rewrite-implicit-map '(def m ($angle-type (Map Keyword Nat)) (:name 1N)))
   '(def m ($angle-type (Map Keyword Nat)) ($brace-params :name 1N))))

(test-case "rewrite-implicit-map: colon type-annotated def"
  (check-equal?
   (rewrite-implicit-map '(def m : (Map Keyword Nat) (:name 1N)))
   '(def m : (Map Keyword Nat) ($brace-params :name 1N))))

(test-case "rewrite-implicit-map: non-trigger function call"
  ;; f is not def/defn — should not rewrite
  (check-equal?
   (rewrite-implicit-map '(f (:x 1) (:y 2)))
   '(f (:x 1) (:y 2))))

(test-case "rewrite-implicit-map: no keyword children"
  (check-equal?
   (rewrite-implicit-map '(def m x))
   '(def m x)))

(test-case "rewrite-implicit-map: empty def"
  (check-equal?
   (rewrite-implicit-map '(def m))
   '(def m)))

(test-case "rewrite-implicit-map: non-list passthrough"
  (check-equal? (rewrite-implicit-map 'x) 'x)
  (check-equal? (rewrite-implicit-map 42) 42))

(test-case "rewrite-implicit-map: dash children → $vec-literal"
  (check-equal?
   (rewrite-implicit-map
    '(def m (:items (- (:name "Alice")) (- (:name "Bob")))))
   '(def m ($brace-params :items ($vec-literal ($brace-params :name "Alice")
                                               ($brace-params :name "Bob"))))))

(test-case "rewrite-implicit-map: defn with keyword tail"
  (check-equal?
   (rewrite-implicit-map '(defn config () (:host "localhost") (:port 8080)))
   '(defn config () ($brace-params :host "localhost" :port 8080))))

(test-case "rewrite-implicit-map: keyword value with inline vector"
  (check-equal?
   (rewrite-implicit-map '(def m (:tags ($vec-literal :admin :active))))
   '(def m ($brace-params :tags ($vec-literal :admin :active)))))

;; ========================================
;; C. Map-literal VALUE rewrites (CIU T6, 2026-07-18)
;; ========================================
;; A keyword-headed $brace-params is a MAP LITERAL; its VALUES need the
;; access / head-macro rewrites (denied by the blanket brace-params opacity,
;; which broke `{:x p.x}` / `{:x [+ p.x 1]}` etc.). A symbol-headed $brace-params
;; is a binder/kind param and stays opaque (its `->` is a kind arrow).

(test-case "map-literal-brace-params?: keyword-headed yes, symbol-headed no"
  (check-true  (map-literal-brace-params? '($brace-params :a 1)))
  (check-false (map-literal-brace-params? '($brace-params A B : Type)))
  (check-false (map-literal-brace-params? '($brace-params)))          ;; empty stays opaque
  (check-false (map-literal-brace-params? '(not-brace :a 1))))

(test-case "map value: dot-access folds to map-get"
  (check-equal?
   (preparse-expand-form '(def m ($brace-params :a pt ($dot-access x))))
   '(def m ($brace-params :a (map-get pt :x)))))

(test-case "map value: dot-access inside a bracketed app folds"
  (check-equal?
   (preparse-expand-form '(def m ($brace-params :a (+ p ($dot-access x) 1))))
   '(def m ($brace-params :a (+ (map-get p :x) 1)))))

(test-case "map value: nested map recurses"
  (check-equal?
   (preparse-expand-form '(def m ($brace-params :a ($brace-params :b p ($dot-access x)))))
   '(def m ($brace-params :a ($brace-params :b (map-get p :x))))))

(test-case "map value: multi-entry keeps even key/value alternation"
  (check-equal?
   (preparse-expand-form '(def m ($brace-params :a p ($dot-access x) :b q ($dot-access y))))
   '(def m ($brace-params :a (map-get p :x) :b (map-get q :y)))))

(test-case "binder brace-params stays OPAQUE (protects the -> kind arrow)"
  ;; symbol-headed → NOT a map literal → untouched; a value rewrite would corrupt
  ;; the kind annotation this opacity was introduced to protect.
  (check-equal?
   (preparse-expand-form '($brace-params A B : Type -> Type))
   '($brace-params A B : Type -> Type)))
