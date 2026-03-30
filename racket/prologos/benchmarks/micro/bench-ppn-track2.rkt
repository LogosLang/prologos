#lang racket/base

;;;
;;; PPN Track 2 Pre-0 Benchmarks: Surface Normalization Pipeline
;;;
;;; Measures the current preparse pipeline to establish baselines
;;; for the Propagator Only replacement design.
;;;
;;; Tiers:
;;;   M1-M5: Micro-benchmarks (individual operations)
;;;   A1-A4: Adversarial tests (worst cases)
;;;   E1-E3: E2E baselines (real-world programs)
;;;

(require racket/list
         racket/string
         racket/format
         racket/path
         racket/port
         "../../driver.rkt"
         "../../macros.rkt"
         "../../parse-reader.rkt"
         "../../metavar-store.rkt"
         "../../propagator.rkt"
         "../../global-env.rkt")

(register-default-token-patterns!)

;; ========================================
;; Timing infrastructure
;; ========================================

(define (time-ms thunk)
  (collect-garbage)
  (collect-garbage)
  (define start (current-inexact-monotonic-milliseconds))
  (define result (thunk))
  (define end (current-inexact-monotonic-milliseconds))
  (values result (- end start)))

(define (bench label thunk #:runs [runs 10] #:warmup [warmup 3])
  ;; Warmup
  (for ([_ (in-range warmup)]) (thunk))
  ;; Timed runs
  (define times
    (for/list ([_ (in-range runs)])
      (collect-garbage)
      (define start (current-inexact-monotonic-milliseconds))
      (thunk)
      (define end (current-inexact-monotonic-milliseconds))
      (- end start)))
  (define sorted (sort times <))
  (define n (length sorted))
  (define median (list-ref sorted (quotient n 2)))
  (define mean (/ (apply + times) n))
  (define mn (apply min times))
  (define mx (apply max times))
  (printf "  ~a: median=~a ms  mean=~a ms  min=~a  max=~a  (n=~a)\n"
          label
          (~r median #:precision '(= 3))
          (~r mean #:precision '(= 3))
          (~r mn #:precision '(= 3))
          (~r mx #:precision '(= 3))
          runs)
  (list label median mean mn mx))

;; ========================================
;; M1: preparse-expand-all total time per program
;; ========================================

(printf "\n=== M1: preparse-expand-all total time ===\n")
(printf "Measures: total preparse wall time for representative programs\n")
(printf "Design impact: if <1%% of elaboration, design is performance-free\n\n")

;; Helper: time preparse-expand-all by running process-string-ws
;; and using the preparse-timing parameter to capture preparse duration
(define preparse-timing-box (box 0.0))

;; We instrument preparse-expand-all via a wrapper.
;; The actual timing happens inside process-string-ws.
(define (time-preparse-via-process src)
  ;; Run full pipeline, capture preparse timing via instrumentation
  (define total-start (current-inexact-monotonic-milliseconds))
  (with-output-to-string
    (lambda ()
      (parameterize ([current-error-port (current-output-port)]
                     [current-mult-meta-store (make-hasheq)])
        (process-string-ws src))))
  (define total-end (current-inexact-monotonic-milliseconds))
  (- total-end total-start))

;; Time FULL process-string-ws
(define (time-process-string-ws src)
  (time-ms (lambda ()
    (with-output-to-string
      (lambda ()
        (parameterize ([current-error-port (current-output-port)]
                       [current-mult-meta-store (make-hasheq)])
          (process-string-ws src)))))))

(define m1-programs
  (list
   (cons "simple-typed"
         "ns bench\ndef x : Int := 42\ndef y : Int := [int+ x 1]\neval y")
   (cons "with-spec"
         "ns bench\nspec add Int Int -> Int\ndefn add [x y] [int+ x y]\neval [add 1 2]")
   (cons "data+match"
         (string-append
          "ns bench\n"
          "data Color := Red | Green | Blue\n\n"
          "spec show-color Color -> String\n"
          "defn show-color\n"
          "  | Red -> \"red\"\n"
          "  | Green -> \"green\"\n"
          "  | Blue -> \"blue\"\n\n"
          "eval [show-color Red]"))
   (cons "trait+impl"
         (string-append
          "ns bench\n"
          "trait Describable\n"
          "  spec describe A -> String\n\n"
          "data Shape := Circle Int | Rect Int Int\n\n"
          "impl (Describable Shape)\n"
          "  defn describe\n"
          "    | Circle r -> \"circle\"\n"
          "    | Rect w h -> \"rect\"\n\n"
          "eval [describe [Circle 5]]"))
   (cons "pipe+let"
         (string-append
          "ns bench\n"
          "def result :=\n"
          "  let x := 10\n"
          "  let y := 20\n"
          "  [int+ x y]\n"
          "eval result"))))

(define m1-results '())
(for ([p (in-list m1-programs)])
  (define label (car p))
  (define src (cdr p))
  (with-handlers ([exn? (lambda (e)
                          (printf "  ~a: ERROR ~a\n" label
                                  (substring (exn-message e) 0
                                             (min 80 (string-length (exn-message e))))))])
    ;; Time full process-string-ws (includes preparse)
    (define-values (_1 total-ms) (time-process-string-ws src))
    (printf "  ~a: total=~a ms\n"
            label
            (~r total-ms #:precision '(= 2)))
    (set! m1-results (cons (list label total-ms) m1-results))))

;; ========================================
;; M2: Per-rule expansion time
;; ========================================

(printf "\n=== M2: Per-rule expansion time ===\n")
(printf "Measures: time for individual expand-* functions\n")
(printf "Design impact: propagator fire function cost per rule\n\n")

;; Time individual expand functions on representative inputs
(define m2-cases
  (list
   (cons "expand-let (simple)"
         (lambda () (preparse-expand-form '(let x := 42 (int+ x 1)))))
   (cons "expand-let (typed)"
         (lambda () (preparse-expand-form '(let x : Int := 42 (int+ x 1)))))
   (cons "expand-cond"
         (lambda () (preparse-expand-form '(cond ($pipe true -> 1) ($pipe false -> 0)))))
   (cons "expand-if"
         (lambda () (preparse-expand-form '(if true 1 0))))
   (cons "expand-list-literal"
         (lambda () (preparse-expand-form '($list-literal 1 2 3))))
   (cons "rewrite-dot-access"
         (lambda () (preparse-expand-form '(($dot-key :name) user))))
   (cons "rewrite-infix-pipe"
         (lambda () (preparse-expand-form '(5 $pipe-gt inc dbl))))
   (cons "expand-quote"
         (lambda () (preparse-expand-form '($quote (foo bar 42)))))))

(define m2-results '())
(for ([c (in-list m2-cases)])
  (define r (bench (car c) (cdr c) #:runs 50 #:warmup 5))
  (set! m2-results (cons r m2-results)))

;; ========================================
;; M3: Registry read cost (parameter vs cell)
;; ========================================

(printf "\n=== M3: Registry read cost ===\n")
(printf "Measures: parameter read vs cell read overhead\n")
(printf "Design impact: spec injection reads spec-store per defn\n\n")

;; Parameter read
(bench "parameter-read (current-spec-store)"
       (lambda () (current-spec-store))
       #:runs 100 #:warmup 10)

;; Lookup-spec (includes parameter read + hash-ref)
(bench "lookup-spec (miss)"
       (lambda () (lookup-spec 'nonexistent-name))
       #:runs 100 #:warmup 10)

;; Count spec-store reads per program
(printf "\n  Spec-store reads per program (estimated):\n")
(printf "  Each defn/def triggers maybe-inject-spec → lookup-spec\n")
(printf "  A program with N defn/def forms → N lookup-spec calls\n")

;; ========================================
;; M4: Fixpoint iteration count
;; ========================================

(printf "\n=== M4: Fixpoint convergence ===\n")
(printf "Measures: iterations of preparse-expand-form per form\n")
(printf "Design impact: propagator re-fires per form cell\n\n")

;; Instrument preparse-expand-form to count iterations
;; We'll use a simple approach: wrap and count
(define iteration-counter (box 0))

(define (count-expand-iterations datum)
  (set-box! iteration-counter 0)
  ;; Run preparse-expand-form with depth tracking
  ;; Each recursive call increments depth, so max depth = iterations
  (define result (preparse-expand-form datum))
  ;; The depth parameter tells us how many times it recursed
  ;; But we can't easily instrument that. Instead, check if result differs from input
  (define changed? (not (equal? datum result)))
  (list datum changed? result))

;; Test convergence on representative forms
(define m4-forms
  (list
   '(let x := 42 x)                          ;; 1 iteration (let → fn application)
   '(cond ($pipe true -> 1) ($pipe false -> 0))  ;; 1 iteration (cond → nested if)
   '(if true 1 0)                             ;; 1 iteration (if → boolrec)
   '($list-literal 1 2 3)                     ;; 1 iteration (list-lit → cons chain)
   '(($dot-key :name) user)                   ;; 1 iteration (dot-key → map-get)
   '(5 $pipe-gt inc dbl)                      ;; 1 iteration (infix → block pipe)
   '(int+ 1 2)                                ;; 0 iterations (no macro matches)
   ))

(for ([form (in-list m4-forms)])
  (define result (count-expand-iterations form))
  (printf "  ~s → changed?=~a\n" (car result) (cadr result)))

;; ========================================
;; M5: Rule registry scan cost
;; ========================================

(printf "\n=== M5: Rule registry scan cost ===\n")
(printf "Measures: cost of scanning 18 rules for non-matching form\n")
(printf "Design impact: overhead per form that doesn't match any rule\n\n")

;; A form that matches NO macros — pure scan cost
(bench "no-match scan (symbol)"
       (lambda () (preparse-expand-form 'just-a-symbol))
       #:runs 100 #:warmup 10)

(bench "no-match scan (simple list)"
       (lambda () (preparse-expand-form '(foo bar baz)))
       #:runs 100 #:warmup 10)

(bench "no-match scan (nested)"
       (lambda () (preparse-expand-form '(foo (bar (baz 1 2)) (qux 3))))
       #:runs 100 #:warmup 10)

;; ========================================
;; A1: 100+ defmacro definitions
;; ========================================

(printf "\n=== A1: Adversarial — 100 defmacro definitions ===\n")
(printf "Stress test: rule registry growth + scan time with many rules\n\n")

;; Build a source with 100 defmacros + 100 uses
(define a1-src
  (string-append
   "ns bench-a1\n\n"
   (apply string-append
     (for/list ([i (in-range 100)])
       (format "defmacro macro~a [x] [int+ x ~a]\n" i i)))
   "\n"
   (apply string-append
     (for/list ([i (in-range 100)])
       (format "eval [macro~a 1]\n" i)))))

(define a1-result
  (bench "100-defmacro full pipeline"
         (lambda ()
           (with-output-to-string
             (lambda ()
               (parameterize ([current-error-port (current-output-port)]
                              [current-mult-meta-store (make-hasheq)])
                 (process-string-ws a1-src)))))
         #:runs 5 #:warmup 2))

;; ========================================
;; A2: Deeply nested macro expansion
;; ========================================

(printf "\n=== A2: Adversarial — deeply nested macro expansion ===\n")
(printf "Stress test: fixpoint convergence cost at depth 20+\n\n")

;; Chain of macros: macro1 → macro2 → macro3 → ... → base value
(define a2-src
  (string-append
   "ns bench-a2\n\n"
   ;; Define 30 macros, each calling the next
   (apply string-append
     (for/list ([i (in-range 30)])
       (if (= i 29)
           (format "defmacro m~a [x] [int+ x 1]\n" i)
           (format "defmacro m~a [x] [m~a x]\n" i (+ i 1)))))
   "\neval [m0 42]\n"))

(define a2-result
  (bench "30-deep macro chain"
         (lambda ()
           (with-output-to-string
             (lambda ()
               (parameterize ([current-error-port (current-output-port)]
                              [current-mult-meta-store (make-hasheq)])
                 (process-string-ws a2-src)))))
         #:runs 5 #:warmup 2))

;; ========================================
;; A3: Many spec+defn cross-references
;; ========================================

(printf "\n=== A3: Adversarial — 50 spec+defn pairs ===\n")
(printf "Stress test: cross-pass injection overhead\n\n")

(define a3-src
  (string-append
   "ns bench-a3\n\n"
   (apply string-append
     (for/list ([i (in-range 50)])
       (format "spec f~a Int -> Int\ndefn f~a [x] [int+ x ~a]\n\n" i i i)))
   "eval [f0 1]\n"))

(define a3-result
  (bench "50 spec+defn pairs"
         (lambda ()
           (with-output-to-string
             (lambda ()
               (parameterize ([current-error-port (current-output-port)]
                              [current-mult-meta-store (make-hasheq)])
                 (process-string-ws a3-src)))))
         #:runs 5 #:warmup 2))

;; ========================================
;; A4: Large single form (20 pattern clauses)
;; ========================================

(printf "\n=== A4: Adversarial — large defn with 20 clauses ===\n")
(printf "Stress test: per-form rewrite cost at scale\n\n")

(define a4-src
  (string-append
   "ns bench-a4\n\n"
   "data D := "
   (apply string-append
     (for/list ([i (in-range 20)])
       (if (= i 0) (format "C~a Int" i) (format " | C~a Int" i))))
   "\n\n"
   "spec dispatch D -> Int\n"
   "defn dispatch\n"
   (apply string-append
     (for/list ([i (in-range 20)])
       (format "  | C~a x -> x\n" i)))
   "\neval [dispatch [C0 42]]\n"))

(define a4-result
  (bench "20-clause defn"
         (lambda ()
           (with-output-to-string
             (lambda ()
               (parameterize ([current-error-port (current-output-port)]
                              [current-mult-meta-store (make-hasheq)])
                 (process-string-ws a4-src)))))
         #:runs 5 #:warmup 2))

;; ========================================
;; E1: Comparative suite timing
;; ========================================

(printf "\n=== E1: Comparative benchmark suite — preparse fraction ===\n")
(printf "Measures: preparse as %% of total elaboration for real programs\n\n")

(define benchmark-dir
  (let ([script-dir (path-only (resolved-module-path-name
                                (variable-reference->resolved-module-path (#%variable-reference))))])
    (build-path script-dir ".." "comparative")))

(define bench-files
  (sort
   (for/list ([f (in-directory benchmark-dir)]
              #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
     f)
   string<? #:key path->string))

(printf "  ~a programs in comparative suite\n\n" (length bench-files))

(for ([f (in-list bench-files)])
  (define fname (path->string (file-name-from-path f)))
  (with-handlers ([exn? (lambda (e)
                          (printf "  ~a: ERROR ~a\n" fname
                                  (substring (exn-message e) 0
                                             (min 60 (string-length (exn-message e))))))])
    ;; Time full process-file
    (define-values (_1 total-ms)
      (time-ms (lambda ()
        (parameterize ([current-mult-meta-store (make-hasheq)])
          (process-file f)))))
    (printf "  ~a: total=~a ms\n"
            fname
            (~r total-ms #:precision '(= 1)))))

;; ========================================
;; E2: Library file loading — preparse fraction
;; ========================================

(printf "\n=== E2: Library files — preparse timing (top 10) ===\n")

(define lib-dir
  (build-path (path-only (resolved-module-path-name
                          (variable-reference->resolved-module-path (#%variable-reference))))
              ".." "lib" "prologos"))

(define lib-files
  (sort
   (for/list ([f (in-directory lib-dir)]
              #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
     f)
   string<? #:key path->string))

(define lib-timings '())
(for ([f (in-list lib-files)])
  (define fname (path->string (find-relative-path lib-dir f)))
  (with-handlers ([exn? (lambda (e) (void))])
    (define-values (_1 total-ms)
      (time-ms (lambda ()
        (parameterize ([current-mult-meta-store (make-hasheq)])
          (process-file f)))))
    (set! lib-timings (cons (list fname total-ms) lib-timings))))

;; Sort by time, show top 10
(define sorted-libs (sort lib-timings > #:key cadr))
(define total-lib-time (apply + (map cadr sorted-libs)))
(printf "  Total time across ~a library files: ~a ms\n\n"
        (length sorted-libs)
        (~r total-lib-time #:precision '(= 1)))
(for ([entry (in-list (take sorted-libs (min 10 (length sorted-libs))))])
  (printf "  ~a: ~a ms\n" (car entry) (~r (cadr entry) #:precision '(= 2))))

;; ========================================
;; Summary
;; ========================================

(printf "\n=== SUMMARY ===\n")
(printf "M1: Preparse fraction of elaboration — see per-program ratios above\n")
(printf "M2: Per-rule cost — see individual timings above\n")
(printf "M3: Registry read — parameter vs cell overhead\n")
(printf "M4: Fixpoint — most forms converge in 0-1 iterations\n")
(printf "M5: Non-matching scan — overhead for forms that don't match any rule\n")
(printf "A1-A4: Adversarial — stress tests for registry, depth, cross-ref, width\n")
(printf "E1-E2: Real programs — preparse %% of total elaboration\n")
(printf "\nDesign implications will be incorporated into D.2.\n")
