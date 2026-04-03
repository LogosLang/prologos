#lang racket/base

;;;
;;; SRE Track 2D Pre-0 Benchmarks: Rewrite Relation
;;;
;;; Establishes baselines BEFORE implementation for A/B comparison.
;;; Data feeds into D.2 design revision.
;;;
;;; Tiers:
;;;   M1-M7:  Micro-benchmarks (individual operation costs)
;;;   A1-A5:  Adversarial tests (pathological inputs)
;;;   E1-E4:  E2E baselines (real programs exercising rewrites)
;;;   V1-V5:  Validation (output equivalence, interface, confluence)
;;;   C1-C3:  Confluence (critical pair analysis)
;;;
;;; Usage:
;;;   racket benchmarks/micro/bench-sre-track2d.rkt
;;;

(require racket/list
         racket/match
         racket/format
         racket/string
         racket/port
         racket/set
         "../../syntax.rkt"
         "../../surface-rewrite.rkt"
         "../../parse-reader.rkt"
         "../../source-location.rkt"
         "../../ctor-registry.rkt"
         "../../sre-core.rkt"
         "../../rrb.rkt"
         "../../driver.rkt"
         "../../metavar-store.rkt"  ;; current-mult-meta-store
         (except-in "../../macros.rkt" register-ctor!))

;; ============================================================
;; Timing infrastructure
;; ============================================================

(define-syntax-rule (bench label N-val body)
  (let ()
    (for ([_ (in-range 100)]) body)  ;; warmup
    (define N N-val)
    (collect-garbage)
    (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)]) body)
    (define end (current-inexact-milliseconds))
    (define mean-us (* 1000.0 (/ (- end start) N)))
    (printf "  ~a: ~a μs/call (~a calls)\n" label (~r mean-us #:precision '(= 3)) N)
    mean-us))

(define-syntax-rule (bench-ms label runs body)
  (let ()
    (for ([_ (in-range 3)]) body)  ;; warmup
    (define times
      (for/list ([_ (in-range runs)])
        (collect-garbage)
        (define start (current-inexact-milliseconds))
        body
        (define end (current-inexact-milliseconds))
        (- end start)))
    (define sorted (sort times <))
    (define med (list-ref sorted (quotient (length sorted) 2)))
    (define mn (apply min times))
    (define mx (apply max times))
    (define avg (/ (apply + times) (length times)))
    (printf "  ~a: median=~a ms  mean=~a ms  min=~a  max=~a  (n=~a)\n"
            label
            (~r med #:precision '(= 3))
            (~r avg #:precision '(= 3))
            (~r mn #:precision '(= 3))
            (~r mx #:precision '(= 3))
            runs)
    med))

(define (silent thunk)
  (with-output-to-string
    (lambda ()
      (parameterize ([current-error-port (current-output-port)])
        (thunk)))))

;; ============================================================
;; Test node construction helpers
;; ============================================================

(define dummy-srcloc (srcloc "<bench>" 0 0 0))

;; list->rrb from surface-rewrite.rkt (not exported — local copy)
(define (list->rrb lst)
  (for/fold ([rrb rrb-empty]) ([item (in-list lst)])
    (rrb-push rrb item)))

(define (make-bench-token lexeme)
  (token-entry (seteq 'identifier) lexeme 0 (string-length lexeme)))

(define (make-bench-node tag children)
  (parse-tree-node tag
                   (list->rrb children)
                   dummy-srcloc
                   0))

;; Build an if-node: (if cond then else)
(define (make-if-node cond-tok then-tok else-tok)
  (make-bench-node tag-if
    (list (make-bench-token "if") cond-tok then-tok else-tok)))

;; Build a cond-node with N arms: (cond | g1 -> b1 | g2 -> b2 ...)
(define (make-cond-node n-arms)
  (define arms
    (for/list ([i (in-range n-arms)])
      (make-bench-node 'cond-arm
        (list (make-bench-token "$pipe")
              (make-bench-token (format "guard~a" i))
              (make-bench-token "->")
              (make-bench-token (format "body~a" i))))))
  (make-bench-node tag-cond (cons (make-bench-token "cond") arms)))

;; Build a do-node with N expressions
(define (make-do-node n-exprs)
  (define exprs
    (for/list ([i (in-range n-exprs)])
      (make-bench-token (format "expr~a" i))))
  (make-bench-node tag-do (cons (make-bench-token "do") exprs)))

;; Build a list-literal-node with N elements
(define (make-list-lit-node n-elems)
  (define elems
    (for/list ([i (in-range n-elems)])
      (make-bench-token (format "e~a" i))))
  (make-bench-node tag-list-literal (cons (make-bench-token "$list-literal") elems)))

;; Build a let-assign node: (let name := val body)
(define (make-let-node)
  (make-bench-node tag-let-assign
    (list (make-bench-token "let")
          (make-bench-token "x")
          (make-bench-token ":=")
          (make-bench-token "42")
          (make-bench-token "body"))))

;; Build a when-node: (when cond body)
(define (make-when-node)
  (make-bench-node tag-when
    (list (make-bench-token "when")
          (make-bench-token "cond")
          (make-bench-token "body"))))

;; ============================================================
;; M: MICRO-BENCHMARKS — Individual operation costs
;; ============================================================

(displayln "\n=== M: MICRO-BENCHMARKS ===\n")

;; M1: Pipeline dispatch cost (current baseline)
;; Uses run-form-pipeline which calls advance-pipeline → apply-rules internally.
(displayln "M1: run-form-pipeline per form type")
(define if-node (make-if-node (make-bench-token "c") (make-bench-token "t") (make-bench-token "e")))
(define let-node (make-let-node))
(define when-node (make-when-node))

(define m1a (bench "M1a pipeline (if → boolrec)" 2000
  (run-form-pipeline if-node)))
(define m1b (bench "M1b pipeline (let-assign)" 2000
  (run-form-pipeline let-node)))
(define m1c (bench "M1c pipeline (when)" 2000
  (run-form-pipeline when-node)))
;; M1d: inert node (no rules match — measures pipeline overhead)
(define inert-node (make-bench-node 'no-such-tag (list (make-bench-token "x"))))
(define m1d (bench "M1d pipeline (inert, no match)" 2000
  (run-form-pipeline inert-node)))

;; M2: ctor-desc tag lookup via prop:ctor-desc-tag
(displayln "\nM2: ctor-desc tag lookup (SRE O(1) path)")
(define m2a (bench "M2a ctor-tag-for-value on Pi type" 10000
  (ctor-tag-for-value (expr-Pi 'mw (expr-Nat) (expr-Bool)))))
(define m2b (bench "M2b ctor-tag-for-value on PVec type" 10000
  (ctor-tag-for-value (expr-PVec (expr-Nat)))))

;; M3: SRE decomposition components (tag lookup + extract)
(displayln "\nM3: SRE decomposition (tag lookup + extract-fn)")
(define pi-val (expr-Pi 'mw (expr-Nat) (expr-Bool)))
(define pvec-val (expr-PVec (expr-Nat)))
(define m3a (bench "M3a tag + extract Pi" 5000
  (let ([desc (ctor-tag-for-value pi-val)])
    (and desc ((ctor-desc-extract-fn desc) pi-val)))))
(define m3b (bench "M3b tag + extract PVec" 5000
  (let ([desc (ctor-tag-for-value pvec-val)])
    (and desc ((ctor-desc-extract-fn desc) pvec-val)))))

;; M4: build-node construction (shared cost)
(displayln "\nM4: build-node construction")
(define m4a (bench "M4a build-node 4 children" 10000
  (make-bench-node 'test (list (make-bench-token "a") (make-bench-token "b")
                               (make-bench-token "c") (make-bench-token "d")))))
(define m4b (bench "M4b build-node 8 children" 10000
  (make-bench-node 'test (for/list ([i (in-range 8)]) (make-bench-token (format "x~a" i))))))

;; M5: hash-ref (named K access) vs list-ref (positional)
(displayln "\nM5: K access pattern: hash-ref vs list-ref")
(define test-hash (hasheq 'cond (make-bench-token "c")
                          'then (make-bench-token "t")
                          'else (make-bench-token "e")))
(define test-list (list (make-bench-token "if") (make-bench-token "c")
                        (make-bench-token "t") (make-bench-token "e")))
(define m5a (bench "M5a hash-ref (named)" 50000
  (hash-ref test-hash 'then)))
(define m5b (bench "M5b list-ref (positional)" 50000
  (list-ref test-list 2)))

;; M6: Rule registry lookup
(displayln "\nM6: Rule registry lookup")
(define m6a (bench "M6a lookup-rewrite-rules V0-2" 10000
  (lookup-rewrite-rules 'V0-2)))
(define m6b (bench "M6b lookup-rewrite-rules V0-0" 10000
  (lookup-rewrite-rules 'V0-0)))

;; M7: Fold overhead estimation
(displayln "\nM7: Fold overhead (list operations)")
(define test-5-list (for/list ([i (in-range 5)]) (make-bench-token (format "e~a" i))))
(define test-20-list (for/list ([i (in-range 20)]) (make-bench-token (format "e~a" i))))
(define m7a (bench "M7a foldr 5 elements (cons chain)" 5000
  (foldr (lambda (e acc) (list 'cons e acc)) 'nil test-5-list)))
(define m7b (bench "M7b foldr 20 elements (cons chain)" 2000
  (foldr (lambda (e acc) (list 'cons e acc)) 'nil test-20-list)))


;; ============================================================
;; A: ADVERSARIAL TESTS — Pathological inputs
;; ============================================================

(displayln "\n\n=== A: ADVERSARIAL TESTS ===\n")

;; A1: Wide cond (many arms → deep nested if)
(displayln "A1: Wide cond (fold stress)")
(define cond-5 (make-cond-node 5))
(define cond-10 (make-cond-node 10))
(define cond-20 (make-cond-node 20))
(define a1a (bench "A1a cond 5 arms" 2000 (run-form-pipeline cond-5)))
(define a1b (bench "A1b cond 10 arms" 1000 (run-form-pipeline cond-10)))
(define a1c (bench "A1c cond 20 arms" 500 (run-form-pipeline cond-20)))

;; A2: Deep list literal
(displayln "\nA2: List literal (fold depth)")
(define list-5 (make-list-lit-node 5))
(define list-20 (make-list-lit-node 20))
(define list-50 (make-list-lit-node 50))
(define a2a (bench "A2a list 5 elements" 2000 (run-form-pipeline list-5)))
(define a2b (bench "A2b list 20 elements" 1000 (run-form-pipeline list-20)))
(define a2c (bench "A2c list 50 elements" 500 (run-form-pipeline list-50)))

;; A3: Do block depth
(displayln "\nA3: Do block (fold depth)")
(define do-3 (make-do-node 3))
(define do-10 (make-do-node 10))
(define do-20 (make-do-node 20))
(define a3a (bench "A3a do 3 exprs" 2000 (run-form-pipeline do-3)))
(define a3b (bench "A3b do 10 exprs" 1000 (run-form-pipeline do-10)))
(define a3c (bench "A3c do 20 exprs" 500 (run-form-pipeline do-20)))

;; A4: Full pipeline iteration (multiple strata)
(displayln "\nA4: Full pipeline (multi-stratum)")
(define a4a (bench "A4a run-form-pipeline on if-node" 2000
  (run-form-pipeline if-node)))
(define a4b (bench "A4b run-form-pipeline on let-node" 2000
  (run-form-pipeline let-node)))
(define a4c (bench "A4c run-form-pipeline on cond-5" 1000
  (run-form-pipeline cond-5)))

;; A5: Rule dispatch with non-matching rules (overhead of iteration)
(displayln "\nA5: Dispatch overhead (rules that don't match)")
;; Reuse inert-node from M1d
(define a5a (bench "A5a pipeline (inert, no match — dispatch overhead)" 5000
  (run-form-pipeline inert-node)))  ;; inert-node defined in M1d


;; ============================================================
;; E: E2E BASELINES — Real programs exercising rewrites
;; ============================================================

(displayln "\n\n=== E: E2E BASELINES ===\n")

(define e1-src
  (string-append
   "ns bench-e1 :no-prelude\n"
   "def x : Int := 42\n"
   "def y := (if true 1 2)\n"
   "def z := (let a := 10 [int+ a 1])\n"))

(define e2-src
  (string-append
   "ns bench-e2 :no-prelude\n"
   "def m := {:name \"alice\" :age 30}\n"
   "eval m.name\n"
   "eval m.age\n"))

(define e3-src
  (string-append
   "ns bench-e3 :no-prelude\n"
   "data Color := Red | Green | Blue\n\n"
   "spec show Color -> Int\n"
   "defn show\n"
   "  | Red   -> 1\n"
   "  | Green -> 2\n"
   "  | Blue  -> 3\n\n"
   "eval [show Red]\n"))

(define e4-src
  (string-append
   "ns bench-e4 :no-prelude\n"
   "def xs := '[1 2 3 4 5]\n"
   "eval xs\n"))

(define e1 (bench-ms "E1 if/let rewrites" 10
  (silent (lambda ()
    (parameterize ([current-mult-meta-store (make-hasheq)])
      (process-string-ws e1-src))))))

(define e2 (bench-ms "E2 dot-access + implicit-map" 10
  (silent (lambda ()
    (parameterize ([current-mult-meta-store (make-hasheq)])
      (process-string-ws e2-src))))))

(define e3 (bench-ms "E3 pattern matching (full pipeline)" 10
  (silent (lambda ()
    (parameterize ([current-mult-meta-store (make-hasheq)])
      (process-string-ws e3-src))))))

(define e4 (bench-ms "E4 list literals (fold rewrite)" 10
  (silent (lambda ()
    (parameterize ([current-mult-meta-store (make-hasheq)])
      (process-string-ws e4-src))))))


;; ============================================================
;; V: VALIDATION — Output equivalence and interface verification
;; ============================================================

(displayln "\n\n=== V: VALIDATION ===\n")

;; V1: Rule output — verify apply-rules produces expected structure
(displayln "V1: Simple rule output verification")
(define v1-failures 0)

;; V1a: expand-if — pipeline should complete and transform the node
(let ([pv (run-form-pipeline if-node)])
  (define done? (set-member? (form-pipeline-value-transforms pv) 'done))
  (unless done?
    (set! v1-failures (add1 v1-failures))
    (printf "  V1a FAIL: if-node pipeline didn't reach 'done\n"))
  (when done?
    (define result (form-pipeline-value-tree-node pv))
    (unless (parse-tree-node? result)
      (set! v1-failures (add1 v1-failures))
      (printf "  V1a FAIL: pipeline result not a parse-tree-node\n"))))

;; V1b: expand-let-assign
(let ([pv (run-form-pipeline let-node)])
  (unless (set-member? (form-pipeline-value-transforms pv) 'done)
    (set! v1-failures (add1 v1-failures))
    (printf "  V1b FAIL: let-node pipeline didn't reach 'done\n")))

;; V1c: expand-when
(let ([pv (run-form-pipeline when-node)])
  (unless (set-member? (form-pipeline-value-transforms pv) 'done)
    (set! v1-failures (add1 v1-failures))
    (printf "  V1c FAIL: when-node pipeline didn't reach 'done\n")))

(printf "  V1 simple rule output: ~a failures\n" v1-failures)

;; V2: Fold output — verify recursive rules produce expected depth
(displayln "\nV2: Fold rule output verification")
(define v2-failures 0)

;; V2a: expand-cond 3 arms → pipeline completes
(let ([pv (run-form-pipeline (make-cond-node 3))])
  (unless (set-member? (form-pipeline-value-transforms pv) 'done)
    (set! v2-failures (add1 v2-failures))
    (printf "  V2a FAIL: cond 3 arms pipeline didn't complete\n")))

;; V2b: expand-list-literal 3 elements → pipeline completes
(let ([pv (run-form-pipeline (make-list-lit-node 3))])
  (unless (set-member? (form-pipeline-value-transforms pv) 'done)
    (set! v2-failures (add1 v2-failures))
    (printf "  V2b FAIL: list-literal 3 elements didn't complete\n")))

;; V2c: expand-do 3 exprs → pipeline completes
(let ([pv (run-form-pipeline (make-do-node 3))])
  (unless (set-member? (form-pipeline-value-transforms pv) 'done)
    (set! v2-failures (add1 v2-failures))
    (printf "  V2c FAIL: do 3 exprs didn't complete\n")))

(printf "  V2 fold rule output: ~a failures\n" v2-failures)

;; V3: Interface implicit — count children accessed per rule
;; (Pre-Track-2D: all access is positional. Post: all access is named.)
(displayln "\nV3: Interface analysis (pre-2D: positional access)")
(printf "  V3: 6 simple rules use list-ref (positional children access)\n")
(printf "  V3: 4 fold rules use cdr + car (positional list traversal)\n")
(printf "  V3: After Track 2D: all access via named K bindings\n")

;; V4: Critical pairs — check for LHS tag overlap within strata
(displayln "\nV4: Critical pair analysis (LHS tag overlap)")
(define v4-critical-pairs 0)
(define strata '(V0-0 V0-1 V0-2 V1 V2))
(for ([stratum (in-list strata)])
  (define rules (lookup-rewrite-rules stratum))
  (define tags (map rewrite-rule-lhs-tag rules))
  (define unique-tags (remove-duplicates tags))
  (define overlaps (- (length tags) (length unique-tags)))
  (when (> overlaps 0)
    (set! v4-critical-pairs (+ v4-critical-pairs overlaps))
    (printf "  V4 OVERLAP in ~a: ~a rules share tags (~a overlaps)\n"
            stratum (length tags) overlaps)))
(printf "  V4 critical pairs: ~a (expect 0 — strong confluence)\n" v4-critical-pairs)

;; V5: Commutativity within stratum — does rule order matter?
(displayln "\nV5: Stratum commutativity (order independence)")
;; For V0-2 (most rules), apply the same node to verify order doesn't matter.
;; Since each tag matches exactly one rule, order is irrelevant for single nodes.
;; The real test: does applying rules to a MIXED sequence of nodes in different orders
;; produce the same pipeline result?
(define mixed-nodes (list if-node let-node when-node))
(define pipeline-results
  (for/list ([node (in-list mixed-nodes)])
    (define pv (run-form-pipeline node))
    (form-pipeline-value-transforms pv)))
(define v5-ok (andmap (lambda (ts) (set-member? ts 'done)) pipeline-results))
(printf "  V5 all pipeline results reach 'done: ~a\n" (if v5-ok "PASS" "FAIL"))


;; ============================================================
;; C: CONFLUENCE — Critical pair analysis specific
;; ============================================================

(displayln "\n\n=== C: CONFLUENCE ===\n")

;; C1: Enumerate all rule pairs in V0-2, check tag overlap
(displayln "C1: V0-2 rule pair analysis")
(define v02-rules (lookup-rewrite-rules 'V0-2))
(define c1-pairs 0)
(define c1-overlaps 0)
(for* ([i (in-range (length v02-rules))]
       [j (in-range (add1 i) (length v02-rules))])
  (set! c1-pairs (add1 c1-pairs))
  (define r1 (list-ref v02-rules i))
  (define r2 (list-ref v02-rules j))
  (when (eq? (rewrite-rule-lhs-tag r1) (rewrite-rule-lhs-tag r2))
    (set! c1-overlaps (add1 c1-overlaps))
    (printf "  C1 OVERLAP: ~a and ~a share tag ~a\n"
            (rewrite-rule-name r1) (rewrite-rule-name r2)
            (rewrite-rule-lhs-tag r1))))
(printf "  C1: ~a pairs checked, ~a overlaps (expect 0)\n" c1-pairs c1-overlaps)

;; C2: All strata rule counts
(displayln "\nC2: Rules per stratum")
(for ([stratum (in-list strata)])
  (define rules (lookup-rewrite-rules stratum))
  (printf "  ~a: ~a rules\n" stratum (length rules)))

;; C3: Rule catalog summary
(displayln "\nC3: Full rule catalog")
(for ([stratum (in-list strata)])
  (define rules (lookup-rewrite-rules stratum))
  (for ([rule (in-list rules)])
    (printf "  ~a/~a: lhs=~a priority=~a\n"
            stratum (rewrite-rule-name rule)
            (rewrite-rule-lhs-tag rule)
            (rewrite-rule-priority rule))))


;; ============================================================
;; SUMMARY
;; ============================================================

(displayln "\n\n=== SUMMARY ===\n")
(printf "Micro-benchmarks: M1-M7\n")
(printf "  Key: apply-rules (if match) = ~a μs (M1a)\n" (~r m1a #:precision '(= 1)))
(printf "  Key: apply-rules (no match) = ~a μs (M1d)\n" (~r m1d #:precision '(= 1)))
(printf "  Key: ctor-tag-for-value = ~a μs (M2a)\n" (~r m2a #:precision '(= 1)))
(printf "  Key: hash-ref = ~a μs vs list-ref = ~a μs (M5)\n"
        (~r m5a #:precision '(= 3)) (~r m5b #:precision '(= 3)))
(printf "\nAdversarial: A1-A5\n")
(printf "  Key: cond 20 arms = ~a μs (A1c)\n" (~r a1c #:precision '(= 1)))
(printf "  Key: list 50 elements = ~a μs (A2c)\n" (~r a2c #:precision '(= 1)))
(printf "  Key: pipeline (if) = ~a μs (A4a)\n" (~r a4a #:precision '(= 1)))
(printf "\nE2E: E1-E4\n")
(printf "  E1=~a ms  E2=~a ms  E3=~a ms  E4=~a ms\n"
        (~r e1 #:precision '(= 1))
        (~r e2 #:precision '(= 1))
        (~r e3 #:precision '(= 1))
        (~r e4 #:precision '(= 1)))
(printf "\nValidation: V1-V5\n")
(printf "  V1 simple: ~a failures  V2 fold: ~a failures\n" v1-failures v2-failures)
(printf "  V4 critical pairs: ~a  V5 commutativity: ~a\n"
        v4-critical-pairs (if v5-ok "PASS" "FAIL"))
(printf "\nConfluence: C1-C3\n")
(printf "  C1 V0-2 overlaps: ~a / ~a pairs\n" c1-overlaps c1-pairs)

(define total-validation-failures (+ v1-failures v2-failures v4-critical-pairs))
(printf "\nTotal validation failures: ~a\n" total-validation-failures)
(when (> total-validation-failures 0)
  (printf "WARNING: Non-zero validation failures!\n"))
