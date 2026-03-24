#lang racket/base
;; PM 8F Phase 0 Pre-measurement: bvar frequency in meta solutions
;;
;; Measures: how many solve-meta! calls produce bvar-containing solutions?
;; This data informs whether close-expr (Phase 3) is fixing a real problem
;; or is purely preventive.

(require "../../syntax.rkt"
         "../../metavar-store.rkt"
         "../../elaborator-network.rkt"
         "../../elab-network-types.rkt"
         "../../champ.rkt"
         "../../infra-cell.rkt"
         "../../driver.rkt"
         "../../namespace.rkt"
         "../../tests/test-support.rkt")

;; --- bvar detection (generic: works on any AST struct) ---
(define (has-bvar? expr)
  (cond
    [(not expr) #f]
    [(expr-bvar? expr) #t]
    [(struct? expr)
     (define v (struct->vector expr))
     (for/or ([field (in-vector v 1)])  ;; skip struct name at pos 0
       (and (struct? field) (has-bvar? field)))]
    [else #f]))

;; --- Counters ---
(define bvar-count 0)
(define total-count 0)
(define bvar-examples '())

(define (scan-metas-after-elaboration)
  ;; Walk the meta-info CHAMP looking for solved metas with bvar solutions
  (define net-box (current-prop-net-box))
  (when net-box
    (define net (unbox net-box))
    (define mi-champ (elab-network-meta-info net))
    (when mi-champ
      (champ-fold
       mi-champ
       (lambda (k v acc)
         (define info (if (tagged-entry? v) (tagged-entry-value v) v))
         (when (and (meta-info? info)
                    (eq? (meta-info-status info) 'solved)
                    (meta-info-solution info))
           (set! total-count (add1 total-count))
           (when (has-bvar? (meta-info-solution info))
             (set! bvar-count (add1 bvar-count))
             (when (< (length bvar-examples) 10)
               (set! bvar-examples
                     (cons (list k (meta-info-solution info))
                           bvar-examples)))))
         acc)
       #f))))

;; --- Run a representative set of programs ---
(define test-programs
  '(;; Simple: no bvars expected
    "(ns t) def x : Int := 42"
    ;; Pi types: binders create bvar context
    "(ns t) spec id {A : Type} A -> A\ndefn id [x] x"
    ;; Polymorphic with constraints
    "(ns t) spec inc Int -> Int\ndefn inc [n] [int+ n 1]\ndef result := [inc 5]"
    ;; Pattern matching (under binders)
    "(ns t) def z := (match 0N | zero -> 1N | suc n -> n)"
    ;; Dependent types (most likely to have bvar solutions)
    "(ns t) spec const {A B : Type} A -> B -> A\ndefn const [x y] x"
    ;; Lambda (creates binder context for metas)
    "(ns t) def f := [fn [x : Int] [int+ x 1]]"
    ;; Higher-order (complex meta solving)
    "(ns t) spec apply {A B : Type} [A -> B] -> A -> B\ndefn apply [f x] [f x]"
    ;; List operations (exercises structural decomposition)
    "(ns t) def xs := '[1N 2N 3N]"
    ;; Nested Pi (deep binder context)
    "(ns t) spec compose {A B C : Type} [B -> C] -> [A -> B] -> A -> C\ndefn compose [f g x] [f [g x]]"
    ;; Trait usage (resolution under binders)
    "(ns t) def res := [+ 3 4]"
    ))

(printf "PM 8F Phase 0: bvar Frequency Measurement\n")
(printf "==========================================\n\n")

(for ([prog (in-list test-programs)]
      [i (in-naturals 1)])
  (printf "Program ~a: " i)
  (with-handlers ([exn:fail? (lambda (e)
                                (printf "ERROR: ~a\n" (exn-message e)))])
    (process-string prog)
    (scan-metas-after-elaboration)
    (printf "ok\n")))

(printf "\n--- Results ---\n")
(printf "Total solved metas examined: ~a\n" total-count)
(printf "Metas with bvar-containing solutions: ~a\n" bvar-count)
(printf "Percentage: ~a%\n"
        (if (> total-count 0)
            (real->decimal-string (* 100.0 (/ bvar-count total-count)) 2)
            "N/A"))
(when (pair? bvar-examples)
  (printf "\nExamples of bvar-containing solutions:\n")
  (for ([ex (in-list bvar-examples)])
    (printf "  meta ~a → ~a\n" (car ex) (cadr ex))))
(when (= bvar-count 0)
  (printf "\n✓ No bvar-containing solutions found.\n")
  (printf "  close-expr in Phase 3 is PREVENTIVE, not corrective.\n")
  (printf "  PUnify opens binders before solving — solutions are fvar-based.\n"))
(printf "\n")
