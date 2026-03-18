#lang racket/base

;;;
;;; Tests for Phase 4: LSeq — Lazy Sequence Data Type
;;; Tests lseq.prologos (data type + accessors) and
;;; lseq-ops.prologos (list-to-lseq, lseq-to-list, lseq-map, etc.)
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
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s)
  (last (run-ns s)))

;; Standard preamble for tests: load lseq + lseq-ops + list + option + nat
(define preamble
  "(ns test)
(imports (prologos::data::lseq :refer (LSeq lseq-nil lseq-cell lseq-head lseq-rest lseq-empty?))
         (prologos::data::lseq-ops :refer (list-to-lseq lseq-to-list lseq-map lseq-filter lseq-take lseq-drop lseq-append lseq-fold lseq-length))
         (prologos::data::list :refer (List nil cons))
         (prologos::data::option :refer (Option some none))
         (prologos::data::nat :refer (add mult)))
")

;; Helper: check that a result string contains a substring
(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))


;; ========================================
;; LSeq-Ops — Map
;; ========================================

(test-case "lseq-ops/map-suc"
  ;; Map (x + 1) over [1,2,3] → [2,3,4]
  (define result (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (def suc-fn : (-> Nat Nat) (fn (x : Nat) (suc x)))
      (eval (lseq-to-list Nat (lseq-map Nat Nat suc-fn (list-to-lseq Nat list123))))")))
  (check-contains result "'[2N 3N 4N]")
  (check-contains result "List Nat"))


(test-case "lseq-ops/map-empty"
  ;; Map over empty → empty
  (define result (run-ns-last (string-append preamble
     "(def suc-fn : (-> Nat Nat) (fn (x : Nat) (suc x)))
      (eval (lseq-to-list Nat (lseq-map Nat Nat suc-fn (lseq-nil Nat))))")))
  (check-contains result "nil")
  (check-contains result "List Nat"))


;; ========================================
;; LSeq-Ops — Filter
;; ========================================

(test-case "lseq-ops/filter-zero?"
  ;; Filter keeps only zeros from [0, 1, 0, 2]
  (define result (run-ns-last (string-append preamble
     "(imports (prologos::data::nat :refer (zero?)))
      (def xs : (List Nat) (cons Nat zero (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat))))))
      (eval (lseq-to-list Nat (lseq-filter Nat zero? (list-to-lseq Nat xs))))")))
  (check-contains result "'[0N 0N]")
  (check-contains result "List Nat"))


(test-case "lseq-ops/filter-empty"
  ;; Filter on empty → empty
  (define result (run-ns-last (string-append preamble
     "(imports (prologos::data::nat :refer (zero?)))
      (eval (lseq-to-list Nat (lseq-filter Nat zero? (lseq-nil Nat))))")))
  (check-contains result "nil")
  (check-contains result "List Nat"))


;; ========================================
;; LSeq-Ops — Take / Drop
;; ========================================

(test-case "lseq-ops/take-2-from-3"
  ;; Take 2 from [1,2,3] → [1,2]
  (define result (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (eval (lseq-to-list Nat (lseq-take Nat (suc (suc zero)) (list-to-lseq Nat list123))))")))
  (check-contains result "'[1N 2N]")
  (check-contains result "List Nat"))


(test-case "lseq-ops/take-0"
  ;; Take 0 → empty
  (define result (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (nil Nat)))
      (eval (lseq-to-list Nat (lseq-take Nat zero (list-to-lseq Nat list123))))")))
  (check-contains result "nil")
  (check-contains result "List Nat"))


(test-case "lseq-ops/drop-1-from-3"
  ;; Drop 1 from [1,2,3] → [2,3]
  (define result (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (eval (lseq-to-list Nat (lseq-drop Nat (suc zero) (list-to-lseq Nat list123))))")))
  (check-contains result "'[2N 3N]")
  (check-contains result "List Nat"))


(test-case "lseq-ops/drop-0"
  ;; Drop 0 → unchanged
  (define result (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))
      (eval (lseq-to-list Nat (lseq-drop Nat zero (list-to-lseq Nat list123))))")))
  (check-contains result "'[1N 2N]")
  (check-contains result "List Nat"))


;; ========================================
;; LSeq-Ops — Append
;; ========================================

(test-case "lseq-ops/append"
  ;; Append [1] [2,3] → [1,2,3]
  (define result (run-ns-last (string-append preamble
     "(def xs : (LSeq Nat) (list-to-lseq Nat (cons Nat (suc zero) (nil Nat))))
      (def ys : (LSeq Nat) (list-to-lseq Nat (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (eval (lseq-to-list Nat (lseq-append Nat xs ys)))")))
  (check-contains result "'[1N 2N 3N]")
  (check-contains result "List Nat"))


(test-case "lseq-ops/append-empty-left"
  ;; Append [] [1] → [1]
  (define result (run-ns-last (string-append preamble
     "(def ys : (LSeq Nat) (list-to-lseq Nat (cons Nat (suc zero) (nil Nat))))
      (eval (lseq-to-list Nat (lseq-append Nat (lseq-nil Nat) ys)))")))
  (check-contains result "'[1N]")
  (check-contains result "List Nat"))


;; ========================================
;; LSeq-Ops — Fold / Length
;; ========================================

(test-case "lseq-ops/fold-sum"
  ;; Fold with add over [1,2,3], init 0 → 6
  (check-contains
   (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (eval (lseq-fold Nat Nat (fn (acc : Nat) (fn (b : Nat) (add acc b))) zero (list-to-lseq Nat list123)))"))
   "6N : Nat"))


(test-case "lseq-ops/fold-empty"
  ;; Fold over empty → initial value
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (lseq-fold Nat Nat (fn (acc : Nat) (fn (b : Nat) (add acc b))) zero (lseq-nil Nat)))"))
   "0N : Nat"))


(test-case "lseq-ops/length-3"
  ;; Length of [1,2,3] → 3
  (check-contains
   (run-ns-last (string-append preamble
     "(def list123 : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))
      (eval (lseq-length Nat (list-to-lseq Nat list123)))"))
   "3N : Nat"))


(test-case "lseq-ops/length-0"
  ;; Length of [] → 0
  (check-contains
   (run-ns-last (string-append preamble
     "(eval (lseq-length Nat (lseq-nil Nat)))"))
   "0N : Nat"))


;; ========================================
;; Laziness test — lseq-head doesn't force tail
;; ========================================

(test-case "lseq/laziness-head-doesnt-force-tail"
  ;; lseq-head on a cell returns head without forcing the thunk.
  (define result (run-ns-last (string-append preamble
     "(eval (lseq-head Nat (lseq-cell Nat (suc (suc zero)) (fn (_ : Unit) (lseq-nil Nat)))))")))
  (check-contains result "some")
  (check-contains result "2"))


;; ========================================
;; Module loading tests
;; ========================================

(test-case "lseq/module-load"
  ;; Verify that lseq module loads with all expected exports
  (define results (run-ns (string-append preamble
    "(infer (LSeq Nat))
     (infer lseq-head)
     (infer lseq-rest)
     (infer lseq-empty?)")))
  ;; Check that LSeq Nat is a type, and the others are function types
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 4)
              "Expected at least 4 type-string results"))


(test-case "lseq-ops/module-load"
  ;; Verify that lseq-ops module loads with all expected exports
  (define results (run-ns (string-append preamble
    "(infer list-to-lseq)
     (infer lseq-to-list)
     (infer lseq-map)
     (infer lseq-filter)
     (infer lseq-take)
     (infer lseq-drop)
     (infer lseq-append)
     (infer lseq-fold)
     (infer lseq-length)")))
  (define type-results (filter string? results))
  (check-true (>= (length type-results) 9)
              "Expected at least 9 type-string results for lseq-ops exports"))
