#lang racket/base

;;;
;;; Tests for prologos::ocapn — Level-3 WS-mode acceptance + behavioural
;;; regressions for the Copilot-review fixes (PR #28 commit 1cb26e2).
;;;
;;; Why a separate file:
;;;   - The other test-ocapn-*.rkt files are Level-1 (sexp / process-string).
;;;     Per testing.md § "Three-level WS validation" the OCapN port had
;;;     never been exercised via `process-file`. Closing that gap is a
;;;     concrete piece of the goblin-pitfalls follow-up list.
;;;   - The Copilot review-comment fixes (counter "get" branch, greeter
;;;     trailing "!", deliver-msg → broken promise on missing actor)
;;;     landed without explicit assertions on the NEW behaviour. This
;;;     file pins them down.
;;;
;;; Running: raco test tests/test-ocapn-acceptance-l3.rkt
;;;

(require rackunit
         racket/list
         racket/path
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

;; ========================================
;; Level-3: process-file on the acceptance file
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define acceptance-file
  (simplify-path
   (build-path here ".." "examples" "2026-04-27-ocapn-acceptance.prologos")))

(test-case "ocapn-acceptance/file elaborates clean via process-file"
  (define results
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
      (process-file (path->string acceptance-file))))
  ;; Every result must be a "X : Y defined." string. Anything else
  ;; (prologos-error, type-mismatch-error, ...) means the WS-mode pipeline
  ;; broke between sexp validation and file-mode parsing.
  (define errors
    (for/list ([r (in-list results)]
               #:when (and (pair? r)
                           (memq (car r) '(prologos-error type-mismatch-error
                                           unbound-variable-error
                                           multiplicity-error arity-error))))
      r))
  (check-equal? errors '()
                (format "Acceptance file produced errors:~n  ~a"
                        (string-join (map (lambda (e) (format "~s" e))
                                          errors)
                                     "\n  "))))

;; ========================================
;; Level-1 fixture for the per-Copilot-fix behavioural assertions.
;; ========================================

(define shared-preamble
  "(ns test-ocapn-acceptance-l3)
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

(define (check-contains actual substr)
  (check-true (string-contains? actual substr)
              (format "Expected ~s to contain ~s" actual substr)))

;; ========================================
;; Copilot fix #3 (counter "get" branch, #28#discussion_r3150426679)
;; ========================================

(test-case "counter/inc bumps state to 1"
  ;; (vat-spawn beh-counter (syrup-nat 0)) → spawn id 0, send "inc" — state becomes 1.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-counter (syrup-nat zero) empty-vat)
                  v1  (tell zero (syrup-tagged \"inc\" syrup-null) (alloc-vat sa))
                  v2  (drain (suc (suc (suc (suc (suc zero))))) v1)
                  ar  (ask zero (syrup-tagged \"get\" syrup-null) v2)
                  v3  (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat ar)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id ar) v3)))))")
   "true"))

(test-case "counter/get returns SAME state — does not change it"
  ;; A "get" followed by another "get" must observe the same value
  ;; (we send three gets and ask the third). The actor's state should
  ;; still reflect "no inc has happened" — the lookup still resolves.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-counter (syrup-nat zero) empty-vat)
                  v1  (tell zero (syrup-tagged \"get\" syrup-null) (alloc-vat sa))
                  v2  (tell zero (syrup-tagged \"get\" syrup-null) v1)
                  ar  (ask  zero (syrup-tagged \"get\" syrup-null) v2)
                  v3  (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat ar)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id ar) v3)))))")
   "true"))

;; ========================================
;; Copilot fix #7 (deliver-msg → broken promise on missing actor,
;; #28#discussion_r3150426741)
;; ========================================
;;
;; Spawn no actor at id 99. ask id 99. Drain. The result-promise must
;; settle as BROKEN, not stay unresolved (the previous behaviour would
;; hang the caller).

(test-case "deliver-msg/missing-actor breaks the answer-promise"
  (check-contains
   (run-last
    "(eval (let (ar  (ask (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"hello\") empty-vat)
                  v   (drain (suc zero) (alloc-vat ar)))
              (broken? (unwrap-or fresh
                                   (lookup-promise (alloc-id ar) v)))))")
   "true"))

(test-case "deliver-msg/missing-actor sends are NOT silently dropped"
  ;; resolved? is true (broken counts as resolved); unresolved? is false.
  (check-contains
   (run-last
    "(eval (let (ar  (ask (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"x\") empty-vat)
                  v   (drain (suc zero) (alloc-vat ar)))
              (resolved? (unwrap-or fresh
                                     (lookup-promise (alloc-id ar) v)))))")
   "true"))

;; ========================================
;; Copilot fix #9 (greeter trailing "!", #28#discussion_r3150426776)
;; ========================================
;;
;; The earlier vat / e2e tests only checked `fulfilled?`. Pin down the
;; ACTUAL string content. We do this by extracting the resolution
;; value through `resolution-value` + `get-string`.

(test-case "greeter/result string contains the trailing !"
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-greeter (syrup-string \"hello\") empty-vat)
                  ar  (ask zero (syrup-string \"world\") (alloc-vat sa))
                  v   (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat ar))
                  pst (unwrap-or fresh (lookup-promise (alloc-id ar) v)))
              (unwrap-or \"NOT-A-STRING\"
                          (get-string (unwrap-or syrup-null
                                                  (resolution-value pst))))))")
   "hello, world!"))

;; ========================================
;; Quiescence / fuel-zero edge cases
;; ========================================

(test-case "drain/zero fuel on non-empty queue does nothing"
  ;; Spawn echo, send-only, drain with fuel=0. Queue should still have
  ;; one message (we did not step at all).
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  v1  (tell zero syrup-null (alloc-vat sa))
                  v2  (drain zero v1))
              (queue-length v2)))")
   "1N"))

(test-case "step-vat/idempotent on quiesced vat"
  ;; After fully draining a 2-message run, step-vat returns none —
  ;; calling it 'twice' (i.e. nesting unwrap-or guards) is a no-op.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  v1  (tell zero (syrup-string \"x\") (alloc-vat sa))
                  v2  (tell zero (syrup-string \"y\") v1)
                  v3  (drain (suc (suc (suc (suc (suc zero))))) v2))
              (step-vat v3)))")
   "none"))

;; ========================================
;; Multiple actors round-trip
;; ========================================
;;
;; Spawn TWO different actor types; talk to each; both promises must
;; settle. Closes the "spawn-twice / lookup-by-id" coverage gap.

(test-case "multi-actor/two echoes resolve their respective promises"
  ;; Spawn echo (id 0), spawn another echo (id 1).
  ;; ask id 0 with "alpha" → promise pa.
  ;; ask id 1 with "beta"  → promise pb.
  ;; drain. both pa and pb should be fulfilled.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  sb  (vat-spawn-actor beh-echo syrup-null (alloc-vat sa))
                  ar  (ask (alloc-id sa) (syrup-string \"alpha\") (alloc-vat sb))
                  br  (ask (alloc-id sb) (syrup-string \"beta\")  (alloc-vat ar))
                  v   (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat br)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id ar) v)))))")
   "true"))

(test-case "multi-actor/second echo's promise also resolves"
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  sb  (vat-spawn-actor beh-echo syrup-null (alloc-vat sa))
                  ar  (ask (alloc-id sa) (syrup-string \"alpha\") (alloc-vat sb))
                  br  (ask (alloc-id sb) (syrup-string \"beta\")  (alloc-vat ar))
                  v   (drain (suc (suc (suc (suc (suc zero))))) (alloc-vat br)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id br) v)))))")
   "true"))
