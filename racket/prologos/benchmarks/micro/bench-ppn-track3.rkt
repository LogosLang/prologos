#lang racket/base

;;;
;;; PPN Track 3 Pre-0 Benchmarks: Parser as Propagators
;;;
;;; Measures the current pipeline to establish baselines for the
;;; propagator-based parser replacement.
;;;
;;; Tiers:
;;;   M1-M7: Micro-benchmarks (individual operations)
;;;   A1-A5: Adversarial tests (worst-case inputs)
;;;   E1-E4: E2E baselines (real-world programs)
;;;   V1-V3: Algebraic validation (lattice property tests)
;;;

(require racket/list
         racket/string
         racket/format
         racket/path
         racket/port
         racket/set
         "../../driver.rkt"
         "../../macros.rkt"
         "../../parser.rkt"
         "../../parse-reader.rkt"
         "../../surface-rewrite.rkt"
         "../../tree-parser.rkt"
         "../../surface-syntax.rkt"
         "../../source-location.rkt"
         "../../metavar-store.rkt"
         "../../propagator.rkt"
         "../../global-env.rkt"
         "../../errors.rkt")

(register-default-token-patterns!)

;; Helper: read sexp string to list of syntax objects
(define (read-sexp-stxs str)
  (compat-read-syntax-all "<bench>" (open-input-string str)))

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
  (for ([_ (in-range warmup)]) (thunk))
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

;; Suppress output during benchmarks
(define (silent thunk)
  (with-output-to-string
    (lambda ()
      (parameterize ([current-error-port (current-output-port)])
        (thunk)))))

(define (process-ws-silent src)
  (silent (lambda ()
      (process-string-ws src)))))

;; ========================================
;; Test programs
;; ========================================

(define prog-simple
  "ns bench :no-prelude\ndef x : Int := 42\ndef y : Int := [int+ x 1]\nspec add Int Int -> Int\ndefn add [a b] [int+ a b]\neval [add x y]")

(define prog-data-match
  (string-append
   "ns bench :no-prelude\n"
   "data Color := Red | Green | Blue\n\n"
   "spec show Color -> Int\n"
   "defn show\n"
   "  | Red -> 1\n"
   "  | Green -> 2\n"
   "  | Blue -> 3\n\n"
   "eval [show Red]"))

(define prog-trait-impl
  (string-append
   "ns bench :no-prelude\n"
   "data Shape := Circle Int | Rect Int Int\n\n"
   "trait Describable\n"
   "  spec describe A -> Int\n\n"
   "impl (Describable Shape)\n"
   "  defn describe\n"
   "    | Circle r -> r\n"
   "    | Rect w h -> [int+ w h]\n\n"
   "eval [describe [Circle 5]]"))

(define prog-medium
  (string-append
   "ns bench :no-prelude\n"
   (apply string-append
     (for/list ([i (in-range 20)])
       (format "def v~a : Int := ~a\n" i i)))
   (apply string-append
     (for/list ([i (in-range 5)])
       (format "spec f~a Int -> Int\ndefn f~a [x] [int+ x ~a]\n" i i i)))
   "eval [f0 1]"))

(define prog-large
  (string-append
   "ns bench :no-prelude\n"
   (apply string-append
     (for/list ([i (in-range 3)])
       (format "data T~a := C~aA Int | C~aB Int Int\n" i i i)))
   (apply string-append
     (for/list ([i (in-range 30)])
       (format "def x~a : Int := ~a\n" i i)))
   (apply string-append
     (for/list ([i (in-range 10)])
       (format "spec g~a Int -> Int\ndefn g~a [x] [int+ x ~a]\n" i i i)))
   "eval [g0 1]"))


;; ========================================================================
;; M1: parse-datum isolation (sexp mode)
;; ========================================================================

(printf "\n=== M1: parse-datum isolation ===\n")
(printf "Measures: parse-datum time on pre-expanded sexps\n")
(printf "Design impact: confirms parsing is negligible vs elaboration\n\n")

;; Sexp programs for parse-datum isolation (WS reader not exported)
(define sexp-simple
  "(ns bench :no-prelude) (def x : Int := 42) (def y : Int := (int+ x 1)) (spec add Int -> Int -> Int) (defn add [a b] (int+ a b)) (eval (add x y))")

(define sexp-medium
  (string-append
   "(ns bench :no-prelude) "
   (apply string-append
     (for/list ([i (in-range 20)])
       (format "(def v~a : Int := ~a) " i i)))
   (apply string-append
     (for/list ([i (in-range 5)])
       (format "(spec f~a Int -> Int) (defn f~a [x] (int+ x ~a)) " i i i)))
   "(eval (f0 1))"))

(define sexp-large
  (string-append
   "(ns bench :no-prelude) "
   (apply string-append
     (for/list ([i (in-range 3)])
       (format "(data T~a (C~aA Int) (C~aB Int Int)) " i i i)))
   (apply string-append
     (for/list ([i (in-range 30)])
       (format "(def x~a : Int := ~a) " i i)))
   (apply string-append
     (for/list ([i (in-range 10)])
       (format "(spec g~a Int -> Int) (defn g~a [x] (int+ x ~a)) " i i i)))
   "(eval (g0 1))"))

(define (time-parse-datum-on src label)
  ;; Use read-sexp-stxs to get stxs, then preparse+parse
  (define raw-stxs (read-sexp-stxs src))
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (bench (format "parse-datum x100: ~a (~a forms)" label (length expanded-stxs))
         (lambda ()
           (for ([_ (in-range 100)])
             (map parse-datum expanded-stxs)))
         #:runs 10 #:warmup 3))

(time-parse-datum-on sexp-simple "simple")
(time-parse-datum-on sexp-medium "medium")
(time-parse-datum-on sexp-large "large")


;; ========================================================================
;; M2: preparse-expand-all decomposed
;; ========================================================================

(printf "\n=== M2: preparse-expand-all decomposed ===\n")
(printf "Measures: expansion vs registration separation\n")
(printf "Design impact: how much work does Phase 3 registration migration replace?\n\n")

(define (time-preparse-decomposed src label)
  (define raw-stxs (read-sexp-stxs src))

  (bench (format "preparse-expand-all: ~a (~a raw)" label (length raw-stxs))
         (lambda () (preparse-expand-all raw-stxs))
         #:runs 20 #:warmup 5)

  (define expanded (preparse-expand-all raw-stxs))
  (bench (format "map parse-datum: ~a (~a expanded)" label (length expanded))
         (lambda () (map parse-datum expanded))
         #:runs 20 #:warmup 5))

(time-preparse-decomposed sexp-simple "simple")
;; Sexp version of trait-impl for M2
(define sexp-trait-impl
  (string-append
   "(ns bench :no-prelude) "
   "(data Shape (Circle Int) (Rect Int Int)) "
   "(trait Describable (spec describe A -> Int)) "
   "(impl (Describable Shape) "
   "  (defn describe ((Circle r) r) ((Rect w h) (int+ w h)))) "
   "(eval (describe (Circle 5)))"))
(time-preparse-decomposed sexp-trait-impl "trait-impl")


;; ========================================================================
;; M3: tree-parser vs parse-datum per form type
;; ========================================================================

(printf "\n=== M3: tree-parser vs parse-datum per form ===\n")
(printf "Measures: per-form cost through both pipelines\n")
(printf "Design impact: production fire cost baseline per form type\n\n")

;; Helper: run tree pipeline on a single form
(define (time-tree-pipeline src)
  (define pt (read-to-tree src))
  (define root (parse-tree-root pt))
  (define grouped (group-tree-node root))
  (define refined (refine-tag grouped))
  (define rewritten (rewrite-tree refined))
  (parse-top-level-forms-from-tree rewritten))

;; WS programs for tree pipeline, sexp equivalents for parse-datum
(define m3-programs
  (list
   (cons "def (tree handles)"
         (cons "ns b :no-prelude\ndef x : Int := 42"
               "(ns b :no-prelude) (def x : Int := 42)"))
   (cons "defn (tree handles)"
         (cons "ns b :no-prelude\nspec f Int -> Int\ndefn f [x] [int+ x 1]"
               "(ns b :no-prelude) (spec f Int -> Int) (defn f [x] (int+ x 1))"))
   (cons "data (tree stubs)"
         (cons "ns b :no-prelude\ndata Color := Red | Green | Blue"
               "(ns b :no-prelude) (data Color Red Green Blue)"))
   (cons "trait (tree stubs)"
         (cons "ns b :no-prelude\ntrait Show\n  spec show A -> Int"
               "(ns b :no-prelude) (trait Show (spec show A -> Int))"))))

(for ([p (in-list m3-programs)])
  (define label (car p))
  (define ws-src (cadr p))
  (define sexp-src (cddr p))
  ;; Time tree pipeline
  (bench (format "tree-pipe: ~a" label)
         (lambda () (time-tree-pipeline ws-src))
         #:runs 20 #:warmup 5)
  ;; Time sexp pipeline (parse-datum only)
  (define raw (read-sexp-stxs sexp-src))
  (define expanded (preparse-expand-all raw))
  (bench (format "sexp-pipe: ~a" label)
         (lambda () (map parse-datum expanded))
         #:runs 20 #:warmup 5))


;; ========================================================================
;; M4: merge-form cost
;; ========================================================================

(printf "\n=== M4: merge-form cost ===\n")
(printf "Measures: merge function in isolation\n")
(printf "Design impact: cell merge function cost per form\n\n")

;; Time the full merge by running process-string-ws (which calls merge internally)
;; We compare WS full pipeline vs sexp full pipeline to measure merge overhead
(bench "full-pipeline WS (simple)"
       (lambda () (process-ws-silent prog-simple))
       #:runs 10 #:warmup 3)

(bench "full-pipeline sexp (simple)"
       (lambda () (silent (lambda ()
           (process-string sexp-simple)))))
       #:runs 10 #:warmup 3)

(bench "full-pipeline WS (data-match)"
       (lambda () (process-ws-silent prog-data-match))
       #:runs 10 #:warmup 3)


;; ========================================================================
;; M5: Production dispatch overhead
;; ========================================================================

(printf "\n=== M5: Production dispatch overhead ===\n")
(printf "Measures: hash lookup cost at various registry sizes\n")
(printf "Design impact: set-valued registry vs singleton overhead\n\n")

;; Simulate a production registry as a hash of sets
(define (make-test-registry n)
  (for/hasheq ([i (in-range n)])
    (values (string->symbol (format "keyword-~a" i))
            (set (list 'builtin i)))))

(define reg-236 (make-test-registry 236))
(define reg-500 (make-test-registry 500))
(define reg-1000 (make-test-registry 1000))

;; Lookup + set-max (simulates provenance selection)
(define (dispatch-from reg keyword)
  (define prods (hash-ref reg keyword #f))
  (and prods (set-first prods)))

(bench "registry lookup (236 entries, hit)"
       (lambda ()
         (for ([_ (in-range 1000)])
           (dispatch-from reg-236 'keyword-100)))
       #:runs 20 #:warmup 5)

(bench "registry lookup (500 entries, hit)"
       (lambda ()
         (for ([_ (in-range 1000)])
           (dispatch-from reg-500 'keyword-250)))
       #:runs 20 #:warmup 5)

(bench "registry lookup (1000 entries, hit)"
       (lambda ()
         (for ([_ (in-range 1000)])
           (dispatch-from reg-1000 'keyword-500)))
       #:runs 20 #:warmup 5)

(bench "registry lookup (236 entries, miss)"
       (lambda ()
         (for ([_ (in-range 1000)])
           (dispatch-from reg-236 'nonexistent)))
       #:runs 20 #:warmup 5)

;; Per-keyword set merge (Track 7 simulation: adding user production)
(define (merge-registries a b)
  (for/fold ([result a]) ([(k v) (in-hash b)])
    (hash-set result k (set-union (hash-ref result k (set)) v))))

(bench "registry merge (236 + 10 user productions)"
       (lambda ()
         (merge-registries reg-236 (make-test-registry 10)))
       #:runs 20 #:warmup 5)


;; ========================================================================
;; M6: Per-form cell creation cost
;; ========================================================================

(printf "\n=== M6: Per-form cell creation cost ===\n")
(printf "Measures: cell creation + Pocket Universe merge on prop-network\n")
(printf "Design impact: per-form cell overhead x N forms\n\n")

;; Simulate FormCell creation and merge using form-pipeline-value
;; (Already exists in surface-rewrite.rkt)
;; D.5b: transforms is a seteq of stage symbols (dependency-set lattice).
(define (make-test-form-pv stage)
  (form-pipeline-value (seteq stage) #f '() 1 (hasheq)))

(bench "form-pipeline-value creation x1000"
       (lambda ()
         (for ([_ (in-range 1000)])
           (form-pipeline-value (seteq 'raw) #f '() 1 (hasheq))))
       #:runs 20 #:warmup 5)

(bench "form-pipeline-merge x1000 (raw→tagged)"
       (lambda ()
         (define old (make-test-form-pv 'raw))
         (define new (make-test-form-pv 'tagged))
         (for ([_ (in-range 1000)])
           (form-pipeline-merge old new)))
       #:runs 20 #:warmup 5)

(bench "form-pipeline-merge x1000 (same stage = no-op)"
       (lambda ()
         (define a (make-test-form-pv 'grouped))
         (define b (make-test-form-pv 'grouped))
         (for ([_ (in-range 1000)])
           (form-pipeline-merge a b)))
       #:runs 20 #:warmup 5)


;; ========================================================================
;; M7: Full pipeline phase timing isolation
;; ========================================================================

(printf "\n=== M7: Full pipeline phase timing ===\n")
(printf "Measures: time each pipeline phase separately\n")
(printf "Design impact: which phase dominates? Which is worth optimizing?\n\n")

(define (time-phases src)
  ;; Phase 1: read-to-tree
  (define-values (pt read-ms)
    (time-ms (lambda () (read-to-tree src))))
  ;; Phase 2: group
  (define-values (grouped group-ms)
    (time-ms (lambda () (group-tree-node (parse-tree-root pt)))))
  ;; Phase 3: refine-tag
  (define-values (refined refine-ms)
    (time-ms (lambda () (refine-tag grouped))))
  ;; Phase 4: rewrite-tree
  (define-values (rewritten rewrite-ms)
    (time-ms (lambda () (rewrite-tree refined))))
  ;; Phase 5: parse-top-level-forms-from-tree
  (define-values (surfs parse-ms)
    (time-ms (lambda () (parse-top-level-forms-from-tree rewritten))))

  (printf "  read-to-tree: ~a ms\n" (~r read-ms #:precision '(= 3)))
  (printf "  group-tree:   ~a ms\n" (~r group-ms #:precision '(= 3)))
  (printf "  refine-tag:   ~a ms\n" (~r refine-ms #:precision '(= 3)))
  (printf "  rewrite-tree: ~a ms\n" (~r rewrite-ms #:precision '(= 3)))
  (printf "  parse-forms:  ~a ms\n" (~r parse-ms #:precision '(= 3)))
  (printf "  total-tree:   ~a ms\n" (~r (+ read-ms group-ms refine-ms rewrite-ms parse-ms) #:precision '(= 3)))
  (printf "  surfs produced: ~a\n" (length surfs)))

(printf "\n  --- prog-simple ---\n")
(time-phases prog-simple)
(printf "\n  --- prog-data-match ---\n")
(time-phases prog-data-match)
(printf "\n  --- prog-large ---\n")
(time-phases prog-large)


;; ========================================================================
;; A1: 200-form program (cell creation stress)
;; ========================================================================

(printf "\n\n=== A1: Adversarial — 200-form program ===\n")
(printf "Stress test: cell creation at realistic scale\n\n")

(define a1-src
  (string-append
   "ns bench-a1 :no-prelude\n"
   (apply string-append
     (for/list ([i (in-range 100)])
       (format "def v~a : Int := ~a\n" i i)))
   (apply string-append
     (for/list ([i (in-range 30)])
       (format "spec f~a Int -> Int\ndefn f~a [x] [int+ x ~a]\n" i i i)))
   (apply string-append
     (for/list ([i (in-range 5)])
       (format "data D~a := C~aA Int | C~aB Int Int\n" i i i)))
   "eval [f0 1]\n"))

(bench "A1: 200-form full pipeline"
       (lambda () (process-ws-silent a1-src))
       #:runs 5 #:warmup 2)

(printf "\n  Tree pipeline phases for A1:\n")
(time-phases a1-src)


;; ========================================================================
;; A2: Deep data hierarchy (registration stress)
;; ========================================================================

(printf "\n\n=== A2: Adversarial — deep data hierarchy ===\n")
(printf "Stress test: 20 data types x 10 constructors = 200 registrations\n\n")

(define a2-src
  (string-append
   "ns bench-a2 :no-prelude\n"
   (apply string-append
     (for/list ([i (in-range 20)])
       (string-append
        (format "data T~a := " i)
        (string-join
         (for/list ([j (in-range 10)])
           (format "C~a_~a Int" i j))
         " | ")
        "\n")))
   "eval 42\n"))

(bench "A2: 20 data types x 10 ctors"
       (lambda () (process-ws-silent a2-src))
       #:runs 5 #:warmup 2)


;; ========================================================================
;; A3: 50 spec+defn cross-references
;; ========================================================================

(printf "\n\n=== A3: Adversarial — 50 spec+defn pairs ===\n")
(printf "Stress test: spec pre-scan ordering dependency\n\n")

(define a3-src
  (string-append
   "ns bench-a3 :no-prelude\n"
   (apply string-append
     (for/list ([i (in-range 50)])
       (format "spec f~a Int -> Int\ndefn f~a [x] [int+ x ~a]\n" i i i)))
   "eval [f0 1]\n"))

(bench "A3: 50 spec+defn pairs"
       (lambda () (process-ws-silent a3-src))
       #:runs 5 #:warmup 2)


;; ========================================================================
;; A4: Large mixfix expressions (Pocket Universe stress)
;; ========================================================================

(printf "\n\n=== A4: Adversarial — 20 mixfix expressions ===\n")
(printf "Stress test: per-form Pocket Universe resolution\n\n")

(define a4-src
  (string-append
   "ns bench-a4 :no-prelude\n"
   (apply string-append
     (for/list ([i (in-range 20)])
       (format "def r~a : Int := .{~a + ~a * ~a - ~a}\n" i i (+ i 1) (+ i 2) (+ i 3))))))

(bench "A4: 20 mixfix expressions"
       (lambda () (process-ws-silent a4-src))
       #:runs 5 #:warmup 2)


;; ========================================================================
;; A5: Production registry at Track 7 scale
;; ========================================================================

(printf "\n\n=== A5: Adversarial — 500-entry production registry ===\n")
(printf "Stress test: set-valued lookup + provenance selection at scale\n\n")

;; Build a 500-entry registry with some keywords having multiple productions
(define a5-registry
  (let ([base (make-test-registry 236)])
    ;; Add 264 "user" productions, 50 of which share keywords with builtins
    (for/fold ([reg base]) ([i (in-range 264)])
      (define kw (if (< i 50)
                     (string->symbol (format "keyword-~a" i))  ;; overlap with builtins
                     (string->symbol (format "user-keyword-~a" i))))
      (hash-set reg kw (set-union (hash-ref reg kw (set)) (set (list 'user i)))))))

(bench "A5: dispatch 1000x from 500-entry registry"
       (lambda ()
         (for ([i (in-range 1000)])
           (define kw (string->symbol (format "keyword-~a" (modulo i 236))))
           (dispatch-from a5-registry kw)))
       #:runs 20 #:warmup 5)

;; Count multi-production keywords
(define multi-prod-count
  (for/sum ([(k v) (in-hash a5-registry)])
    (if (> (set-count v) 1) 1 0)))
(printf "  Keywords with >1 production: ~a / ~a\n" multi-prod-count (hash-count a5-registry))


;; ========================================================================
;; E1: Comparative benchmark suite
;; ========================================================================

(printf "\n\n=== E1: Comparative suite — full pipeline timing ===\n")
(printf "Measures: total wall time for real programs\n\n")

(define benchmark-dir
  (let ([script-dir (path-only (resolved-module-path-name
                                (variable-reference->resolved-module-path (#%variable-reference))))])
    (build-path script-dir ".." "comparative")))

(define bench-files
  (if (directory-exists? benchmark-dir)
      (sort
       (for/list ([f (in-directory benchmark-dir)]
                  #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
         f)
       string<? #:key path->string)
      '()))

(printf "  ~a programs in comparative suite\n\n" (length bench-files))

(for ([f (in-list bench-files)])
  (define fname (path->string (file-name-from-path f)))
  (with-handlers ([exn? (lambda (e)
                          (printf "  ~a: ERROR ~a\n" fname
                                  (substring (exn-message e) 0
                                             (min 80 (string-length (exn-message e))))))])
    (define-values (_1 total-ms)
      (time-ms (lambda ()
          (process-file f)))))
    (printf "  ~a: ~a ms\n" fname (~r total-ms #:precision '(= 1)))))


;; ========================================================================
;; E2: Library file loading
;; ========================================================================

(printf "\n\n=== E2: Library file loading (top 10 by size) ===\n")

(define lib-dir
  (build-path (path-only (resolved-module-path-name
                          (variable-reference->resolved-module-path (#%variable-reference))))
              ".." ".." "lib" "prologos"))

(define lib-files
  (if (directory-exists? lib-dir)
      (sort
       (for/list ([f (in-directory lib-dir)]
                  #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
         (cons f (file-size f)))
       > #:key cdr)
      '()))

(printf "  ~a library files found\n\n" (length lib-files))

(for ([entry (in-list (take lib-files (min 10 (length lib-files))))])
  (define f (car entry))
  (define size (cdr entry))
  (define fname (path->string (file-name-from-path f)))
  (with-handlers ([exn? (lambda (e)
                          (printf "  ~a (~a bytes): ERROR ~a\n" fname size
                                  (substring (exn-message e) 0
                                             (min 60 (string-length (exn-message e))))))])
    (define-values (_1 total-ms)
      (time-ms (lambda ()
          (process-file f)))))
    (printf "  ~a (~a bytes): ~a ms\n" fname size (~r total-ms #:precision '(= 1)))))


;; ========================================================================
;; E3: Acceptance file canary
;; ========================================================================

(printf "\n\n=== E3: Acceptance file canary ===\n")

(define examples-dir
  (build-path (path-only (resolved-module-path-name
                          (variable-reference->resolved-module-path (#%variable-reference))))
              ".." "examples"))

(define example-files
  (if (directory-exists? examples-dir)
      (sort
       (for/list ([f (in-directory examples-dir)]
                  #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
         f)
       string<? #:key path->string)
      '()))

(printf "  ~a example .prologos files\n\n" (length example-files))

(define e3-pass 0)
(define e3-fail 0)
(for ([f (in-list example-files)])
  (define fname (path->string (file-name-from-path f)))
  (with-handlers ([exn? (lambda (e)
                          (printf "  FAIL ~a: ~a\n" fname
                                  (substring (exn-message e) 0
                                             (min 80 (string-length (exn-message e)))))
                          (set! e3-fail (+ e3-fail 1)))])
      (process-file f))
    (set! e3-pass (+ e3-pass 1))))

(printf "\n  Result: ~a pass, ~a fail out of ~a\n" e3-pass e3-fail (length example-files))


;; ========================================================================
;; E4: WS vs sexp full pipeline comparison
;; ========================================================================

(printf "\n\n=== E4: WS vs sexp pipeline comparison ===\n")
(printf "Measures: overhead of WS path (tree-parser + merge) vs sexp path\n\n")

;; Use simple program that works in both WS and sexp modes
(bench "E4 WS: simple"
       (lambda () (process-ws-silent prog-simple))
       #:runs 10 #:warmup 3)

(bench "E4 sexp: simple"
       (lambda () (silent (lambda ()
           (process-string sexp-simple)))))
       #:runs 10 #:warmup 3)

(bench "E4 WS: medium (20 defs)"
       (lambda () (process-ws-silent prog-medium))
       #:runs 5 #:warmup 2)

(bench "E4 sexp: medium (20 defs)"
       (lambda () (silent (lambda ()
           (process-string sexp-medium)))))
       #:runs 5 #:warmup 2)


;; ========================================================================
;; V1: FormCell merge algebraic properties
;; ========================================================================

(printf "\n\n=== V1: FormCell merge algebraic properties ===\n")
(printf "Validates: commutativity, associativity, idempotence of form-pipeline-merge\n\n")

(define test-stages '(raw tagged grouped v0-0 v0-1 v0-2 v1 v2 done))

(define (random-pv)
  (define stage (list-ref test-stages (random (length test-stages))))
  (form-pipeline-value (seteq stage) #f '() (random 100) (hasheq)))

;; V1a: Commutativity
(define v1a-failures 0)
(for ([_ (in-range 500)])
  (define a (random-pv))
  (define b (random-pv))
  (define ab (form-pipeline-merge a b))
  (define ba (form-pipeline-merge b a))
  (unless (equal? (form-pipeline-value-transforms ab)
                  (form-pipeline-value-transforms ba))
    (set! v1a-failures (+ v1a-failures 1))))
(printf "  V1a commutativity: ~a failures / 500 tests\n" v1a-failures)

;; V1b: Associativity
(define v1b-failures 0)
(for ([_ (in-range 500)])
  (define a (random-pv))
  (define b (random-pv))
  (define c (random-pv))
  (define ab-c (form-pipeline-merge (form-pipeline-merge a b) c))
  (define a-bc (form-pipeline-merge a (form-pipeline-merge b c)))
  (unless (equal? (form-pipeline-value-transforms ab-c)
                  (form-pipeline-value-transforms a-bc))
    (set! v1b-failures (+ v1b-failures 1))))
(printf "  V1b associativity: ~a failures / 500 tests\n" v1b-failures)

;; V1c: Idempotence
(define v1c-failures 0)
(for ([_ (in-range 500)])
  (define a (random-pv))
  (define aa (form-pipeline-merge a a))
  (unless (equal? (form-pipeline-value-transforms aa)
                  (form-pipeline-value-transforms a))
    (set! v1c-failures (+ v1c-failures 1))))
(printf "  V1c idempotence: ~a failures / 500 tests\n" v1c-failures)


;; ========================================================================
;; V2: Pipeline-preference ordering — distributivity
;; ========================================================================

(printf "\n\n=== V2: Pipeline-preference ordering — distributivity ===\n")
(printf "Validates: join(a, meet(b, c)) = meet(join(a, b), join(a, c))\n")
(printf "NOTE: Testing stage component only (meet = min of stage chain)\n\n")

;; Define meet on stages (min of chain)
(define (stage-meet a b)
  (define ai (stage-index-fn a))
  (define bi (stage-index-fn b))
  (if (<= ai bi) a b))

(define (stage-index-fn stage)
  (let loop ([stages test-stages] [i 0])
    (cond
      [(null? stages) -1]
      [(eq? (car stages) stage) i]
      [else (loop (cdr stages) (+ i 1))])))

(define (stage-join a b)
  (define ai (stage-index-fn a))
  (define bi (stage-index-fn b))
  (if (>= ai bi) a b))

(define v2-failures 0)
(for ([_ (in-range 1000)])
  (define a (list-ref test-stages (random (length test-stages))))
  (define b (list-ref test-stages (random (length test-stages))))
  (define c (list-ref test-stages (random (length test-stages))))
  ;; join(a, meet(b, c))
  (define lhs (stage-join a (stage-meet b c)))
  ;; meet(join(a, b), join(a, c))
  (define rhs (stage-meet (stage-join a b) (stage-join a c)))
  (unless (eq? lhs rhs)
    (set! v2-failures (+ v2-failures 1))
    (when (< v2-failures 5)
      (printf "  FAIL: a=~a b=~a c=~a → lhs=~a rhs=~a\n" a b c lhs rhs))))
(printf "  V2 distributivity: ~a failures / 1000 tests\n" v2-failures)

;; V2b: Heyting pseudo-complement exists for stages
;; For finite chain: pseudo-complement of a relative to b is:
;;   b if a > b, else ⊤ (= 'done)
(printf "\n  V2b: Pseudo-complement existence check (stage chain):\n")
(define v2b-ok #t)
(for* ([a (in-list test-stages)]
       [b (in-list test-stages)])
  ;; Pseudo-complement c: largest c such that meet(a,c) <= b
  ;; In a chain: if a <= b, then c = ⊤ (done). If a > b, then c = b.
  (define ai (stage-index-fn a))
  (define bi (stage-index-fn b))
  (define pseudo-comp (if (<= ai bi) 'done b))
  ;; Verify: meet(a, pseudo-comp) <= b
  (define check (stage-meet a pseudo-comp))
  (define check-i (stage-index-fn check))
  (unless (<= check-i bi)
    (printf "  FAIL: a=~a b=~a pseudo-comp=~a but meet(a,c)=~a > b\n"
            a b pseudo-comp check)
    (set! v2b-ok #f)))
(printf "  V2b pseudo-complement: ~a\n" (if v2b-ok "ALL PASS" "FAILURES FOUND"))


;; ========================================================================
;; V3: ProductionRegistry set-union properties
;; ========================================================================

(printf "\n\n=== V3: ProductionRegistry set-union properties ===\n")
(printf "Validates: per-keyword set union is commutative, associative, idempotent\n\n")

(define (random-registry size)
  (for/hasheq ([_ (in-range size)])
    (define kw (string->symbol (format "kw-~a" (random 50))))
    (values kw (set (list 'prod (random 100))))))

;; V3a: Commutativity
(define v3a-failures 0)
(for ([_ (in-range 100)])
  (define a (random-registry 10))
  (define b (random-registry 10))
  (define ab (merge-registries a b))
  (define ba (merge-registries b a))
  (unless (equal? ab ba)
    (set! v3a-failures (+ v3a-failures 1))))
(printf "  V3a commutativity: ~a failures / 100 tests\n" v3a-failures)

;; V3b: Associativity
(define v3b-failures 0)
(for ([_ (in-range 100)])
  (define a (random-registry 10))
  (define b (random-registry 10))
  (define c (random-registry 10))
  (define ab-c (merge-registries (merge-registries a b) c))
  (define a-bc (merge-registries a (merge-registries b c)))
  (unless (equal? ab-c a-bc)
    (set! v3b-failures (+ v3b-failures 1))))
(printf "  V3b associativity: ~a failures / 100 tests\n" v3b-failures)

;; V3c: Idempotence
(define v3c-failures 0)
(for ([_ (in-range 100)])
  (define a (random-registry 10))
  (define aa (merge-registries a a))
  (unless (equal? aa a)
    (set! v3c-failures (+ v3c-failures 1))))
(printf "  V3c idempotence: ~a failures / 100 tests\n" v3c-failures)

;; V3d: Provenance selection from merged set
(printf "\n  V3d: Provenance selection from merged set:\n")
(define merged-with-overlap
  (merge-registries
   (hasheq 'fn (set '(builtin 0)) 'if (set '(builtin 1)))
   (hasheq 'fn (set '(user 99)) 'when (set '(user 50)))))
(for ([(k v) (in-hash merged-with-overlap)])
  (printf "    ~a: ~a productions → ~a\n"
          k (set-count v) v))


;; ========================================================================
;; Summary
;; ========================================================================

(printf "\n\n=== SUMMARY ===\n")
(printf "V1: commutativity=~a, associativity=~a, idempotence=~a\n"
        v1a-failures v1b-failures v1c-failures)
(printf "V2: distributivity=~a, pseudo-complement=~a\n"
        v2-failures (if v2b-ok "PASS" "FAIL"))
(printf "V3: commutativity=~a, associativity=~a, idempotence=~a\n"
        v3a-failures v3b-failures v3c-failures)
(printf "E3: ~a/~a acceptance files pass\n" e3-pass (length example-files))
(printf "\nDone.\n")
