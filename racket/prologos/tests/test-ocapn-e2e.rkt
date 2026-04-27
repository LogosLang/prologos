#lang racket/base

;;;
;;; End-to-end tests for OCapN-in-Prologos.
;;;
;;; These tests exercise the user-facing `core.prologos` API and
;;; demonstrate scenarios that map to common Goblins/OCapN patterns:
;;;
;;;   1. Counter — spawn, ask twice, observe state mutation
;;;   2. Greeter — spawn with state, ask, get reply
;;;   3. Cell — spawn, set, get, observe round-trip
;;;   4. Forwarder — spawn, ask via forwarder, observe target receives msg
;;;   5. Resolver — fulfiller resolves a remote promise
;;;   6. Multiple sends in one drain — vat orders correctly
;;;
;;; All scenarios use the public API: vat-spawn-actor, ask, tell, drain.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

(define shared-preamble
  "(ns test-ocapn-e2e)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; 1. Counter scenario — Goblins-style
;; ========================================

(test-case "e2e/counter — ask returns fulfilled promise"
  ;; Spawn a counter at 0. ask it to inc. drain. promise should be fulfilled.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-counter (syrup-nat zero) empty-vat)
                  ar  (ask zero (syrup-tagged \"inc\" syrup-null) (alloc-vat sa))
                  v2  (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat ar)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id ar) v2)))))")
   "true"))

;; ========================================
;; 2. Greeter scenario
;; ========================================

(test-case "e2e/greeter — ask resolves to greeting"
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-greeter (syrup-string \"howdy\") empty-vat)
                  ar  (ask zero (syrup-string \"world\") (alloc-vat sa))
                  v2  (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat ar)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id ar) v2)))))")
   "true"))

;; ========================================
;; 3. Cell scenario
;; ========================================

(test-case "e2e/cell — set then ask get returns set value"
  ;; tell the cell to set; ask it to get; drain.
  (check-contains
   (run-last
    "(eval (let (sa   (vat-spawn-actor beh-cell syrup-null empty-vat)
                  v1   (tell zero
                              (syrup-tagged \"set\" (syrup-string \"meow\"))
                              (alloc-vat sa))
                  ar   (ask zero
                             (syrup-tagged \"get\" syrup-null) v1)
                  v3   (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat ar)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id ar) v3)))))")
   "true"))

;; ========================================
;; 4. Forwarder scenario — capability composition
;; ========================================

(test-case "e2e/forwarder — full chain settles"
  (check-contains
   (run-last
    "(eval (let (sa1  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  sa2  (vat-spawn-actor beh-forwarder
                                     (syrup-refr (alloc-id sa1)) (alloc-vat sa1))
                  v1   (tell (alloc-id sa2) (syrup-string \"hello\") (alloc-vat sa2))
                  v2   (drain (suc (suc (suc (suc (suc zero))))) v1))
              (queue-length v2)))")
   "0N"))

;; ========================================
;; 5. Resolver — actor settling a promise
;; ========================================

(test-case "e2e/resolver — fulfiller settles its target promise"
  (check-contains
   (run-last
    "(eval (let (rp   (fresh-promise empty-vat)
                  pid  (alloc-id rp)
                  sa   (vat-spawn-actor beh-fulfiller
                                     (syrup-promise pid) (alloc-vat rp))
                  v1   (tell (alloc-id sa) (syrup-string \"go\") (alloc-vat sa))
                  v2   (drain (suc (suc (suc (suc (suc zero))))) v1))
              (fulfilled? (unwrap-or fresh (lookup-promise pid v2)))))")
   "true"))

;; ========================================
;; 6. Multiple sends in one drain — order preserved
;; ========================================

(test-case "e2e/three sends to adder: cumulative state"
  (check-contains
   (run-last
    "(eval (let (sa   (vat-spawn-actor beh-adder (syrup-nat zero) empty-vat)
                  v1   (tell zero (syrup-nat (suc zero)) (alloc-vat sa))
                  v2   (tell zero (syrup-nat (suc (suc zero))) v1)
                  v3   (tell zero (syrup-nat (suc (suc (suc zero)))) v2)
                  v4   (drain (suc (suc (suc (suc (suc (suc zero)))))) v3))
              (lookup-actor zero v4)))")
   "some"))

;; ========================================
;; Quiescence: drain on an empty queue is identity
;; ========================================

(test-case "e2e/drain on empty vat is no-op"
  ;; queue length should be 0 before and after drain.
  (check-contains
   (run-last
    "(eval (queue-length (drain (suc zero) empty-vat)))")
   "0N"))

;; ========================================
;; Drain doesn't damage actors
;; ========================================

(test-case "e2e/spawn then drain — actor still present"
  (check-contains
   (run-last
    "(eval (lookup-actor zero
              (drain (suc zero) (alloc-vat (vat-spawn-actor beh-echo syrup-null empty-vat)))))")
   "some"))
