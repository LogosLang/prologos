#lang racket/base

;;;
;;; Tests for prologos trait and pattern matching features:
;;;   match, Eq trait, Ord trait, elem, recursive-defn,
;;;   native constructors, implicit arguments, structural PM.
;;;
;;; Split from test-stdlib.rkt (part 2 of 3)
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run two prologos module strings sequentially,
;; sharing the module registry so the second can require the first.
;; Returns the results from the second module.
(define (run-ns-pair s1 s2)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    ;; Process the first module (sets up ns-context, registers module)
    (process-string s1)
    ;; Capture the module info from the first module's namespace
    (let ([ctx (current-ns-context)])
      (when ctx
        (let* ([ns-sym (ns-context-current-ns ctx)]
               [exports (cond
                          [(not (null? (ns-context-exports ctx)))
                           (ns-context-exports ctx)]
                          [(not (null? (ns-context-auto-exports ctx)))
                           (reverse (ns-context-auto-exports ctx))]
                          [else '()])]
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq) (hasheq) #f)])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


;; --- filter ---

(test-case "filter/pred-true"
  ;; some with pred returning true → keeps value — use unwrap-or
  (check-equal?
   (last (run-ns "(ns of1)\n(imports [prologos::data::option :refer [Option none some filter unwrap-or]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (unwrap-or Nat (suc zero) (filter Nat zero? (some Nat zero))))"))
   "0N : Nat"))


(test-case "filter/pred-false"
  ;; some with pred returning false → none → gets default
  (check-equal?
   (last (run-ns "(ns of2)\n(imports [prologos::data::option :refer [Option none some filter unwrap-or]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (unwrap-or Nat (suc (suc zero)) (filter Nat zero? (some Nat (suc zero)))))"))
   "2N : Nat"))


(test-case "filter/none"
  ;; none stays none → gets default
  (check-equal?
   (last (run-ns "(ns of3)\n(imports [prologos::data::option :refer [Option none some filter unwrap-or]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (filter Nat zero? (none Nat))))"))
   "3N : Nat"))


;; --- zip-with ---

(test-case "zip-with/both-some"
  ;; zip two somes with add — use unwrap-or to extract result
  (check-equal?
   (last (run-ns "(ns ozw1)\n(imports [prologos::data::option :refer [Option none some zip-with unwrap-or]])\n(imports [prologos::data::nat :refer [add]])\n(eval (unwrap-or Nat zero (zip-with Nat Nat Nat add (some Nat (suc (suc zero))) (some Nat (suc (suc (suc zero)))))))"))
   "5N : Nat"))


(test-case "zip-with/first-none"
  (check-equal?
   (last (run-ns "(ns ozw2)\n(imports [prologos::data::option :refer [Option none some zip-with unwrap-or]])\n(imports [prologos::data::nat :refer [add]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (zip-with Nat Nat Nat add (none Nat) (some Nat (suc zero)))))"))
   "3N : Nat"))


(test-case "zip-with/second-none"
  (check-equal?
   (last (run-ns "(ns ozw3)\n(imports [prologos::data::option :refer [Option none some zip-with unwrap-or]])\n(imports [prologos::data::nat :refer [add]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (zip-with Nat Nat Nat add (some Nat (suc zero)) (none Nat))))"))
   "3N : Nat"))


(test-case "zip-with/both-none"
  (check-equal?
   (last (run-ns "(ns ozw4)\n(imports [prologos::data::option :refer [Option none some zip-with unwrap-or]])\n(imports [prologos::data::nat :refer [add]])\n(eval (unwrap-or Nat (suc (suc (suc zero))) (zip-with Nat Nat Nat add (none Nat) (none Nat))))"))
   "3N : Nat"))


;; --- zip ---

(test-case "zip/both-some"
  ;; zip into a pair, then extract via match
  (check-equal?
   (last (run-ns "(ns oz1)\n(imports [prologos::data::option :refer [Option none some zip]])\n(eval (the Nat (match (zip Nat Nat (some Nat (suc zero)) (some Nat (suc (suc zero)))) (none -> zero) (some p -> (fst p)))))"))
   "1N : Nat"))


(test-case "zip/one-none"
  (check-equal?
   (last (run-ns "(ns oz2)\n(imports [prologos::data::option :refer [Option none some zip]])\n(eval (the Nat (match (zip Nat Nat (none Nat) (some Nat (suc (suc zero)))) (none -> (suc (suc (suc zero)))) (some p -> (fst p)))))"))
   "3N : Nat"))


;; --- Type checking for Option combinators ---

(test-case "or-else/type-check"
  (check-equal?
   (last (run-ns "(ns ooetc)\n(imports [prologos::data::option :refer [Option or-else]])\n(check or-else : (Pi (A :0 (Type 0)) (-> (Option A) (-> (Option A) (Option A)))))"))
   "OK"))


(test-case "filter/type-check"
  (check-equal?
   (last (run-ns "(ns oftc)\n(imports [prologos::data::option :refer [Option filter]])\n(check filter : (Pi (A :0 (Type 0)) (-> (-> A Bool) (-> (Option A) (Option A)))))"))
   "OK"))


;; ========================================
;; Sprint 0.3 Combinators — Result
;; ========================================

;; --- and-then ---
;; Auto-implicit order: A B E (first-occurrence in spec [A -> Result B E] [Result A E] -> Result B E)

(test-case "and-then/ok-to-ok"
  ;; ok value → apply f → ok result — use unwrap-or to extract
  (check-equal?
   (last (run-ns "(ns rat1)\n(imports [prologos::data::result :refer [Result ok err and-then unwrap-or]])\n(imports [prologos::data::nat :refer [add]])\n(eval (unwrap-or Nat Bool zero (and-then Nat Nat Bool (fn (x : Nat) (ok Nat Bool (add x (suc zero)))) (ok Nat Bool (suc (suc zero))))))"))
   "3N : Nat"))


(test-case "and-then/ok-to-err"
  ;; ok value → apply f → err result — match to extract
  (check-equal?
   (last (run-ns "(ns rat2)\n(imports [prologos::data::result :refer [Result ok err and-then]])\n(eval (the Nat (match (and-then Nat Nat Bool (fn (x : Nat) (err Nat Bool true)) (ok Nat Bool (suc zero))) (ok x -> x) (err e -> (match e (true -> (suc (suc (suc (suc (suc zero)))))) (false -> zero))))))"))
   "5N : Nat"))


(test-case "and-then/err-passthrough"
  ;; err → f not called, err passes through
  (check-equal?
   (last (run-ns "(ns rat3)\n(imports [prologos::data::result :refer [Result ok err and-then]])\n(eval (the Nat (match (and-then Nat Nat Bool (fn (x : Nat) (ok Nat Bool (suc x))) (err Nat Bool true)) (ok x -> x) (err e -> (match e (true -> (suc (suc (suc (suc (suc (suc (suc zero)))))))) (false -> zero))))))"))
   "7N : Nat"))


;; --- or-else ---
;; Auto-implicit order: E A F (first-occurrence in spec [E -> Result A F] [Result A E] -> Result A F)

(test-case "or-else/ok-passthrough"
  ;; ok → f not called, ok passes through — use unwrap-or
  (check-equal?
   (last (run-ns "(ns roe1)\n(imports [prologos::data::result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Bool Nat Nat (fn (e : Bool) (ok Nat Nat zero)) (ok Nat Bool (suc (suc zero))))))"))
   "2N : Nat"))


(test-case "or-else/err-to-ok"
  ;; err → apply f → recovers to ok — use unwrap-or
  (check-equal?
   (last (run-ns "(ns roe2)\n(imports [prologos::data::result :refer [Result ok err or-else unwrap-or]])\n(eval (unwrap-or Nat Nat zero (or-else Bool Nat Nat (fn (e : Bool) (ok Nat Nat (match e (true -> (suc zero)) (false -> zero)))) (err Nat Bool true))))"))
   "1N : Nat"))


(test-case "or-else/err-to-err"
  ;; err → apply f → still err (with new error type) — match to extract
  (check-equal?
   (last (run-ns "(ns roe3)\n(imports [prologos::data::result :refer [Result ok err or-else]])\n(eval (the Nat (match (or-else Bool Nat Nat (fn (e : Bool) (err Nat Nat (the Nat (match e (true -> (suc (suc (suc zero)))) (false -> zero))))) (err Nat Bool true)) (ok x -> x) (err e -> e))))"))
   "3N : Nat"))


;; --- Type checking for Result combinators ---

(test-case "and-then/type-check"
  ;; Auto-implicit order: A B E (first-occurrence in spec)
  (check-equal?
   (last (run-ns "(ns rattc)\n(imports [prologos::data::result :refer [Result and-then]])\n(check and-then : (Pi (A :0 (Type 0)) (Pi (B :0 (Type 0)) (Pi (E :0 (Type 0)) (-> (-> A (Result B E)) (-> (Result A E) (Result B E)))))))"))
   "OK"))


(test-case "or-else/type-check"
  ;; Auto-implicit order: E A F (first-occurrence in spec)
  (check-equal?
   (last (run-ns "(ns roetc)\n(imports [prologos::data::result :refer [Result or-else]])\n(check or-else : (Pi (E :0 (Type 0)) (Pi (A :0 (Type 0)) (Pi (F :0 (Type 0)) (-> (-> E (Result A F)) (-> (Result A E) (Result A F)))))))"))
   "OK"))
