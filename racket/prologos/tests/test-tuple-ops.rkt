#lang racket/base

;;;
;;; TUPLE OPS — CIU T6 F1a-col-3: Record ('nat row) arms across the pvec ops.
;;;
;;; WS-mode (:no-prelude — pvec-* are parser keywords) coverage for the col-3
;;; dispositions: EXACT where the position structure is static (nth/push/update/
;;; pop/concat/slice with literal indices/bounds — closed tuples have static
;;; length), uniform-view/⋃-degrade where it is not (to-list/fold/map/filter,
;;; dynamic indices), the check-mode arms (annotated defs), the qtt co-migration
;;; (§6 divergence class: type-changing ops delegate to infer), and the Nat-only
;;; index discipline (pvec-* runtime is nat-value-only; Int literal indices are
;;; v[i]/expr-get territory, not pvec-*).
;;;

(require rackunit
         racket/list
         racket/string
         racket/file
         racket/runtime-path
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
         "../reduction.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt")

(define-runtime-path lib-dir "../lib")

;; ---- Shared fixture (loaded once; :no-prelude) ----
(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns tuple-ops-test :no-prelude)")
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; ---- Run WS code via temp file against the shared env ----
(define (run-ws s)
  (define tmp (make-temporary-file "prologos-tupleops-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace
    (lambda (out) (display s out)))
  (define result
    (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                   [current-ns-context shared-ns-context]
                   [current-module-registry shared-module-reg]
                   [current-lib-paths (list lib-dir)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry shared-trait-reg]
                   [current-impl-registry shared-impl-reg]
                   [current-param-impl-registry shared-param-impl-reg]
                   [current-bundle-registry shared-bundle-reg])
      (process-file tmp)))
  (delete-file tmp)
  result)

;; One WS program: the tuple fixture, then every success-path op. Run once;
;; drop the leading `def` result and assert on the evals by index.
(define evals
  (list-tail
   (run-ws
    (string-append
     "def tr := @[1 \"a\" true]\n"
     "[pvec-nth tr 1N]\n"                                       ; 0 — EXACT position type
     "[pvec-push tr 2]\n"                                       ; 1 — EXACT: row grows
     "[pvec-length tr]\n"                                       ; 2 — Nat
     "[pvec-pop tr]\n"                                          ; 3 — EXACT: last position dropped
     "[pvec-concat tr tr]\n"                                    ; 4 — EXACT: renumbered append
     "[pvec-slice tr 1N 3N]\n"                                  ; 5 — EXACT sub-row, renumbered
     "[pvec-slice tr 1N 99N]\n"                                 ; 6 — clamped (rrb-slice semantics)
     "[pvec-slice tr 2N 1N]\n"                                  ; 7 — empty range → the empty tuple
     "[pvec-to-list tr]\n"                                      ; 8 — uniform view (List ⋃)
     "[pvec-update tr 0N \"x\"]\n"                              ; 9 — EXACT type-CHANGING replace
     "[pvec-fold [fn [acc : Int] [fn [x : <Int | String | Bool>] acc]] 0 tr]\n" ; 10 — uniform fold
     "[pvec-map [fn [x : <Int | String | Bool>] 1] tr]\n"       ; 11 — position-preserving map
     "[pvec-filter [fn [x : <Int | String | Bool>] true] tr]\n" ; 12 — (PVec ⋃) degrade
     "def idx : Nat := 1N\n"
     "[pvec-nth tr idx]\n"                                      ; 14 — dynamic index → ⋃ degrade
     "def folded : Int := [pvec-fold [fn [acc : Int] [fn [x : <Int | String | Bool>] acc]] 0 tr]\n" ; 15 — CHECK-mode fold
     "def mapped : (PVec Int) := [pvec-map [fn [x : <Int | String | Bool>] 7] tr]\n" ; 16 — CHECK-mode map
     "def pushed : (PVec <Int | String | Bool>) := [pvec-push tr 2]\n" ; 17 — checkQ push via the α
     "[transient tr]\n"                                         ; 18 — uniform transient view
     "def hv := @[1 2 3]\n"
     "[pvec-nth hv 1N]\n"                                       ; 20 — PVec control: unchanged
     "[pvec-concat hv hv]\n"))                                  ; 21 — PVec control: unchanged
   1))
(define (R i) (list-ref evals i))

;; ---- EXACT arms (static position structure) ----

(test-case "ws: pvec-nth literal index → exact position type"
  (check-equal? (R 0) "\"a\" : String"))

(test-case "ws: pvec-push → row grows (type-changing)"
  (check-equal? (R 1) "@[1 \"a\" true 2] : ⟨Int String Bool Int⟩"))

(test-case "ws: pvec-length on a tuple → Nat"
  (check-equal? (R 2) "3N : Nat"))

(test-case "ws: pvec-pop → last position dropped (rrb-pop semantics)"
  (check-equal? (R 3) "@[1 \"a\"] : ⟨Int String⟩"))

(test-case "ws: pvec-concat of two tuples → renumbered append"
  (check-equal? (R 4) "@[1 \"a\" true 1 \"a\" true] : ⟨Int String Bool Int String Bool⟩"))

(test-case "ws: pvec-slice literal bounds → exact renumbered sub-row"
  (check-equal? (R 5) "@[\"a\" true] : ⟨String Bool⟩"))

(test-case "ws: pvec-slice clamps hi to length (rrb-slice semantics)"
  (check-equal? (R 6) "@[\"a\" true] : ⟨String Bool⟩"))

(test-case "ws: pvec-slice empty range → the empty tuple"
  (check-equal? (R 7) "@[] : ⟨⟩"))

(test-case "ws: pvec-update literal in-bounds index → exact type-CHANGING replace"
  (check-equal? (R 9) "@[\"x\" \"a\" true] : ⟨String String Bool⟩"))

;; ---- Uniform-view / degrade arms ----

(test-case "ws: pvec-to-list → (List ⋃positions), the escape-hatch view"
  (check-equal? (R 8) "'[1 \"a\" true] : [List Bool | Int | String]"))

(test-case "ws: pvec-fold consumes the uniform view"
  (check-equal? (R 10) "0 : Int"))

(test-case "ws: pvec-map is position-preserving (constant-W row)"
  (check-equal? (R 11) "@[1 1 1] : ⟨Int Int Int⟩"))

(test-case "ws: pvec-filter degrades to (PVec ⋃) — surviving positions not static"
  (check-equal? (R 12) "@[1 \"a\" true] : [PVec Bool | Int | String]"))

(test-case "ws: dynamic index → ⋃-positions degrade"
  (check-equal? (R 14) "\"a\" : Bool | Int | String"))

(test-case "ws: transient on a tuple → uniform TVec view"
  (check-true (string-contains? (R 18) "[TVec Bool | Int | String]")))

;; ---- Check-mode paths (annotated defs; the issue-#76 class) ----

(test-case "ws: CHECK-mode fold over a tuple (typing-core + qtt checkQ arms)"
  (check-true (string-contains? (R 15) "folded")))

(test-case "ws: CHECK-mode map against (PVec Int)"
  (check-true (string-contains? (R 16) "mapped")))

(test-case "ws: checkQ push against (PVec ⋃) routes through the Tuple→PVec α"
  (check-true (string-contains? (R 17) "pushed")))

;; ---- PVec controls (byte-identical behavior) ----

(test-case "ws: homogeneous PVec nth unchanged"
  (check-equal? (R 20) "2 : Int"))

(test-case "ws: homogeneous PVec concat unchanged"
  (check-equal? (R 21) "@[1 2 3 1 2 3] : [PVec Int]"))

;; ---- Static misses + index discipline (each must ERROR) ----

(define errors-run
  (run-ws
   (string-append
    "def tr := @[1 \"a\" true]\n"
    "[pvec-nth tr 5N]\n"                 ; 1 — static out-of-bounds (closed-row miss)
    "[pvec-update tr 9N 0]\n"            ; 2 — static bounds miss on update
    "[pvec-nth tr 1]\n"                  ; 3 — Int literal index: pvec-* is Nat-only
    "[pvec-map [fn [x : Int] x] tr]\n"   ; 4 — f cannot consume every position
    "[pvec-pop [pvec-slice tr 0N 0N]]\n"))) ; 5 — pop on the (statically) empty tuple

(test-case "ws: static misses and index-discipline violations all error"
  (for ([i (in-list '(1 2 3 4 5))])
    (check-true (prologos-error? (list-ref errors-run i))
                (format "form ~a should be a static error" i))))
