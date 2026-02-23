#lang racket/base

;;;
;;; Tests for Phase 1c: ~[...] LSeq Literal Syntax
;;; Tests reader tokenization (WS + sexp), preparse macro expansion,
;;; type-checking, evaluation, and pretty-printing of ~[...] literals.
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
         "../multi-dispatch.rkt"
         "../reader.rkt"
         "../sexp-readtable.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
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

;; Standard preamble for tests: load lseq + lseq-ops + list + nat
(define preamble
  "(ns test)
(require (prologos::data::lseq :refer (LSeq lseq-nil lseq-cell lseq-head lseq-rest lseq-empty?))
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
;; Reader tests: WS reader ~[] tokenization
;; ========================================

(test-case "reader: WS ~[] produces empty $lseq-literal"
  (define forms (read-all-forms-string "~[]"))
  (check-equal? forms '(($lseq-literal))))

(test-case "reader: WS ~[1 2 3] produces $lseq-literal with elements"
  (define forms (read-all-forms-string "~[1 2 3]"))
  (check-equal? forms '(($lseq-literal 1 2 3))))

(test-case "reader: WS ~[1, 2, 3] commas stripped"
  (define forms (read-all-forms-string "~[1, 2, 3]"))
  (check-equal? forms '(($lseq-literal 1 2 3))))

(test-case "reader: WS ~42 still produces approx-literal"
  ;; Ensure ~N approx literals still work after adding ~[ support
  (define forms (read-all-forms-string "~42"))
  (check-equal? forms '(($approx-literal 42))))

;; ========================================
;; Reader tests: sexp reader ~[] support
;; ========================================

(test-case "sexp: ~[1 2 3] produces $lseq-literal"
  (define in (open-input-string "~[1 2 3]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($lseq-literal 1 2 3)))

(test-case "sexp: ~[] produces empty $lseq-literal"
  (define in (open-input-string "~[]"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($lseq-literal)))

(test-case "sexp: ~42 still produces approx-literal"
  (define in (open-input-string "~42"))
  (define result (prologos-sexp-read in))
  (check-equal? result '($approx-literal 42)))

;; ========================================
;; Preparse macro expansion tests
;; ========================================

(test-case "macro: $lseq-literal empty → lseq-nil"
  (define result (expand-lseq-literal '($lseq-literal)))
  (check-equal? result 'lseq-nil))

(test-case "macro: $lseq-literal singleton → nested lseq-cell"
  (define result (expand-lseq-literal '($lseq-literal 1)))
  (check-equal? result '(lseq-cell 1 (fn (_ : Unit) lseq-nil))))

(test-case "macro: $lseq-literal multi → nested lseq-cell chain"
  (define result (expand-lseq-literal '($lseq-literal 1 2 3)))
  (check-equal? result
    '(lseq-cell 1 (fn (_ : Unit)
       (lseq-cell 2 (fn (_ : Unit)
         (lseq-cell 3 (fn (_ : Unit) lseq-nil))))))))

;; ========================================
;; Type-checking: ~[] with type annotation
;; ========================================

(test-case "lseq-literal/check-empty"
  ;; (check ~[] <LSeq Nat>) should type-check → "OK"
  (define result (run-ns-last (string-append preamble
    "(check ~[] <LSeq Nat>)")))
  (check-contains result "OK"))

(test-case "lseq-literal/check-singleton"
  ;; (check ~[(suc zero)] <LSeq Nat>) should type-check → "OK"
  (define result (run-ns-last (string-append preamble
    "(check ~[(suc zero)] <LSeq Nat>)")))
  (check-contains result "OK"))

(test-case "lseq-literal/check-multi"
  ;; (check ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))] <LSeq Nat>)
  (define result (run-ns-last (string-append preamble
    "(check ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))] <LSeq Nat>)")))
  (check-contains result "OK"))

;; ========================================
;; Def + eval: ~[] literals through pipeline
;; ========================================

(test-case "lseq-literal/def-empty"
  ;; Define an empty LSeq via literal
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[])
     (eval (lseq-empty? Nat xs))")))
  (check-contains result "true"))

(test-case "lseq-literal/def-multi"
  ;; Define a 3-element LSeq via literal, convert to list to verify
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))])
     (eval (lseq-to-list Nat xs))")))
  (check-contains result "'[1N 2N 3N]"))

(test-case "lseq-literal/head"
  ;; Head of ~[1 2 3] should be some 1
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero) (suc (suc zero))])
     (eval (lseq-head Nat xs))")))
  (check-contains result "some")
  (check-contains result "1"))

(test-case "lseq-literal/empty?-nonempty"
  ;; lseq-empty? on non-empty ~[...] → false
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[zero])
     (eval (lseq-empty? Nat xs))")))
  (check-contains result "false"))

(test-case "lseq-literal/length"
  ;; Length of ~[0 1 2] should be 3
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[zero (suc zero) (suc (suc zero))])
     (eval (lseq-length Nat xs))")))
  (check-contains result "3"))

;; ========================================
;; Round-trip: ~[...] → lseq-to-list → '[...]
;; ========================================

(test-case "lseq-literal/round-trip-singleton"
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero)])
     (eval (lseq-to-list Nat xs))")))
  (check-contains result "'[1N]"))

(test-case "lseq-literal/round-trip-5-elements"
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero))) (suc (suc (suc (suc zero)))) (suc (suc (suc (suc (suc zero)))))])
     (eval (lseq-to-list Nat xs))")))
  (check-contains result "'[1N 2N 3N 4N 5N]"))

;; ========================================
;; Operations on ~[...] literals
;; ========================================

(test-case "lseq-literal/map-over-literal"
  ;; Map suc over ~[1 2 3] → ~[2 3 4] → convert to list
  (define result (run-ns-last (string-append preamble
    "(def suc-fn : (-> Nat Nat) (fn (x : Nat) (suc x)))
     (def xs <LSeq Nat> ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))])
     (eval (lseq-to-list Nat (lseq-map Nat Nat suc-fn xs)))")))
  (check-contains result "'[2N 3N 4N]"))

(test-case "lseq-literal/take-from-literal"
  ;; Take 2 from ~[1 2 3] → ~[1 2] → convert to list
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))])
     (eval (lseq-to-list Nat (lseq-take Nat (suc (suc zero)) xs)))")))
  (check-contains result "'[1N 2N]"))

(test-case "lseq-literal/fold-sum"
  ;; Fold (sum) over ~[1 2 3] → 6
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))])
     (eval (lseq-fold Nat Nat (fn (acc : Nat) (fn (x : Nat) (add acc x))) zero xs))")))
  (check-contains result "6"))

;; ========================================
;; Pretty-print: ~[...] output detection
;; ========================================

(test-case "lseq-literal/pretty-print-multi"
  ;; Eval should display as ~[...] via try-as-lseq detection
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero) (suc (suc zero)) (suc (suc (suc zero)))])
     (eval xs)")))
  (check-contains result "~[1N 2N 3N]"))

(test-case "lseq-literal/pretty-print-singleton"
  (define result (run-ns-last (string-append preamble
    "(def xs <LSeq Nat> ~[(suc zero)])
     (eval xs)")))
  (check-contains result "~[1N]"))
