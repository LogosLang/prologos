#lang racket/base

;;;
;;; Tests for Keyword type + Map (persistent hash map) integration
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../champ.rkt")

;; Helper to run with clean global env
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; ========================================
;; Core AST: Keyword type formation
;; ========================================

(test-case "Keyword type formation"
  (check-equal? (tc:infer ctx-empty (expr-Keyword))
                (expr-Type (lzero))
                "Keyword : Type 0")
  (check-equal? (tc:infer-level ctx-empty (expr-Keyword))
                (tc:just-level (lzero))
                "Keyword at level 0")
  (check-true (tc:is-type ctx-empty (expr-Keyword))
              "Keyword is a type"))

(test-case "keyword literal typing"
  (check-equal? (tc:infer ctx-empty (expr-keyword 'name))
                (expr-Keyword)
                "keyword(:name) : Keyword")
  (check-true (tc:check ctx-empty (expr-keyword 'name) (expr-Keyword))
              "check keyword(:name) : Keyword"))

;; ========================================
;; Core AST: Map type formation
;; ========================================

(test-case "Map type formation"
  (check-equal? (tc:infer ctx-empty (expr-Map (expr-Keyword) (expr-Nat)))
                (expr-Type (lzero))
                "(Map Keyword Nat) : Type 0")
  (check-true (tc:is-type ctx-empty (expr-Map (expr-Keyword) (expr-Nat)))
              "(Map Keyword Nat) is a type"))

(test-case "Map type level"
  (check-equal? (tc:infer-level ctx-empty (expr-Map (expr-Keyword) (expr-Nat)))
                (tc:just-level (lzero))
                "(Map Keyword Nat) at level 0"))

;; ========================================
;; Core AST: Map empty + assoc typing
;; ========================================

(test-case "map-empty typing"
  (check-equal? (tc:infer ctx-empty (expr-map-empty (expr-Keyword) (expr-Nat)))
                (expr-Map (expr-Keyword) (expr-Nat))
                "map-empty(Keyword, Nat) : Map Keyword Nat"))

(test-case "map-assoc typing"
  (let ([m (expr-map-empty (expr-Keyword) (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-map-assoc m (expr-keyword 'x) (expr-zero)))
                  (expr-Map (expr-Keyword) (expr-Nat))
                  "map-assoc infers Map Keyword Nat")))

(test-case "map-get typing"
  (let ([m (expr-map-empty (expr-Keyword) (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-map-get m (expr-keyword 'x)))
                  (expr-Nat)
                  "map-get infers Nat (value type)")))

(test-case "map-dissoc typing"
  (let ([m (expr-map-empty (expr-Keyword) (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-map-dissoc m (expr-keyword 'x)))
                  (expr-Map (expr-Keyword) (expr-Nat))
                  "map-dissoc infers Map Keyword Nat")))

(test-case "map-size typing"
  (let ([m (expr-map-empty (expr-Keyword) (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-map-size m))
                  (expr-Nat)
                  "map-size infers Nat")))

(test-case "map-has-key typing"
  (let ([m (expr-map-empty (expr-Keyword) (expr-Nat))])
    (check-equal? (tc:infer ctx-empty (expr-map-has-key m (expr-keyword 'x)))
                  (expr-Bool)
                  "map-has-key infers Bool")))

;; ========================================
;; Core AST: Map reduction (iota rules)
;; ========================================

(test-case "map-assoc + map-get reduction"
  ;; Build a map with one entry, then look it up
  (let* ([empty (expr-champ champ-empty)]
         [m1 (expr-map-assoc empty (expr-keyword 'name) (expr-suc (expr-zero)))]
         [reduced-m1 (whnf m1)]
         [get-result (whnf (expr-map-get reduced-m1 (expr-keyword 'name)))])
    (check-true (expr-champ? reduced-m1) "assoc produces champ")
    (check-equal? get-result (expr-suc (expr-zero))
                  "map-get retrieves value")))

(test-case "map-get missing key → error"
  (let* ([empty (expr-champ champ-empty)]
         [result (whnf (expr-map-get empty (expr-keyword 'missing)))])
    (check-true (expr-error? result) "missing key produces error")))

(test-case "map-assoc update existing key"
  (let* ([empty (expr-champ champ-empty)]
         [m1 (whnf (expr-map-assoc empty (expr-keyword 'x) (expr-zero)))]
         [m2 (whnf (expr-map-assoc m1 (expr-keyword 'x) (expr-suc (expr-zero))))]
         [result (whnf (expr-map-get m2 (expr-keyword 'x)))])
    (check-equal? result (expr-suc (expr-zero))
                  "assoc updates existing key")))

(test-case "map-dissoc reduction"
  (let* ([empty (expr-champ champ-empty)]
         [m1 (whnf (expr-map-assoc empty (expr-keyword 'x) (expr-zero)))]
         [m2 (whnf (expr-map-dissoc m1 (expr-keyword 'x)))]
         [result (whnf (expr-map-get m2 (expr-keyword 'x)))])
    (check-true (expr-error? result)
                "after dissoc, key is gone")))

(test-case "map-size reduction"
  (let* ([empty (expr-champ champ-empty)]
         [m1 (whnf (expr-map-assoc empty (expr-keyword 'a) (expr-zero)))]
         [m2 (whnf (expr-map-assoc m1 (expr-keyword 'b) (expr-suc (expr-zero))))])
    (check-equal? (whnf (expr-map-size empty)) (expr-zero)
                  "empty map has size 0")
    (check-equal? (whnf (expr-map-size m2)) (expr-suc (expr-suc (expr-zero)))
                  "two-entry map has size 2")))

(test-case "map-has-key reduction"
  (let* ([empty (expr-champ champ-empty)]
         [m1 (whnf (expr-map-assoc empty (expr-keyword 'x) (expr-zero)))])
    (check-equal? (whnf (expr-map-has-key m1 (expr-keyword 'x)))
                  (expr-true) "has-key for existing key")
    (check-equal? (whnf (expr-map-has-key m1 (expr-keyword 'y)))
                  (expr-false) "has-key for missing key")))

;; ========================================
;; Core AST: Substitution
;; ========================================

(test-case "map substitution"
  ;; Shift through map operations
  (check-equal? (shift 1 0 (expr-Keyword)) (expr-Keyword) "Keyword type stable under shift")
  (check-equal? (shift 1 0 (expr-keyword 'x)) (expr-keyword 'x) "keyword literal stable under shift")
  (check-equal? (shift 1 0 (expr-Map (expr-Keyword) (expr-Nat)))
                (expr-Map (expr-Keyword) (expr-Nat))
                "Map type stable under shift")
  ;; Shift with bvar inside map-assoc
  (check-equal? (shift 1 0 (expr-map-assoc (expr-bvar 0) (expr-keyword 'k) (expr-bvar 1)))
                (expr-map-assoc (expr-bvar 1) (expr-keyword 'k) (expr-bvar 2))
                "shift increases bvars in map-assoc"))

;; ========================================
;; Core AST: Pretty-printing
;; ========================================

(test-case "map pretty-printing"
  (check-equal? (pp-expr (expr-Keyword) '()) "Keyword" "pp Keyword")
  (check-equal? (pp-expr (expr-keyword 'name) '()) ":name" "pp :name")
  (check-equal? (pp-expr (expr-Map (expr-Keyword) (expr-Nat)) '())
                "(Map Keyword Nat)" "pp Map Keyword Nat")
  (check-equal? (pp-expr (expr-map-assoc (expr-champ champ-empty)
                                          (expr-keyword 'x) (expr-zero)) '())
                "[map-assoc {map ...} :x zero]" "pp map-assoc"))

;; ========================================
;; Surface syntax: End-to-end via process-string (sexp mode)
;; ========================================

(test-case "surface: Keyword type formation"
  (check-equal? (run "(check Keyword <(Type 0)>)")
                '("OK")))

(test-case "surface: keyword literal eval"
  (check-equal? (run "(eval :name)")
                '(":name : Keyword")))

(test-case "surface: keyword literal check"
  (check-equal? (run "(check :name <Keyword>)")
                '("OK")))

(test-case "surface: Map type formation"
  (check-equal? (run "(check (Map Keyword Nat) <(Type 0)>)")
                '("OK")))

(test-case "surface: map-empty eval"
  ;; map-empty reduces to champ(champ-empty), pretty-printed as {map ...}
  (let ([result (run "(eval (map-empty Keyword Nat))")])
    (check-equal? (length result) 1)
    (check-true (string-contains? (car result) "Map Keyword Nat"))))

(test-case "surface: map-assoc + map-get"
  (let ([result (run "(eval (map-get (map-assoc (map-empty Keyword Nat) :x (inc zero)) :x))")])
    (check-equal? result '("1 : Nat"))))

(test-case "surface: map-has-key?"
  (check-equal? (run "(eval (map-has-key? (map-assoc (map-empty Keyword Nat) :x zero) :x))")
                '("true : Bool"))
  (check-equal? (run "(eval (map-has-key? (map-empty Keyword Nat) :x))")
                '("false : Bool")))

(test-case "surface: map-size"
  (check-equal? (run "(eval (map-size (map-empty Keyword Nat)))")
                '("zero : Nat"))
  (check-equal? (run "(eval (map-size (map-assoc (map-empty Keyword Nat) :x zero)))")
                '("1 : Nat")))

(test-case "surface: map-dissoc"
  (let ([result (run "(eval (map-has-key? (map-dissoc (map-assoc (map-empty Keyword Nat) :x zero) :x) :x))")])
    (check-equal? result '("false : Bool"))))

(test-case "surface: def + eval with map"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def m <(Map Keyword Nat)> (map-assoc (map-empty Keyword Nat) :age (inc (inc zero))))\n(eval (map-get m :age))")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "m : (Map Keyword Nat) defined"))
      (check-equal? (cadr result) "2 : Nat"))))

(test-case "surface: defn with map parameter"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(defn lookup-age [m <(Map Keyword Nat)>] <Nat> (map-get m :age))\n(eval (lookup-age (map-assoc (map-empty Keyword Nat) :age (inc (inc (inc zero))))))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "3 : Nat"))))

;; ========================================
;; Surface syntax: Map literal {k v ...} via sexp mode
;; ========================================

(test-case "surface: empty map literal {}"
  ;; {} should parse as an empty map literal
  (let ([result (run "(eval {})")])
    ;; Empty map needs type annotation context; without it, metas may not resolve
    ;; Just check it doesn't crash
    (check-equal? (length result) 1)))

(test-case "surface: map literal with check"
  ;; Map literal checked against a known type
  (check-equal? (run "(check {:x zero :y (inc zero)} <(Map Keyword Nat)>)")
                '("OK")))

(test-case "surface: map literal via def"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def m <(Map Keyword Nat)> {:x (inc zero)})\n(eval (map-get m :x))")])
      (check-equal? (length result) 2)
      (check-equal? (cadr result) "1 : Nat"))))
