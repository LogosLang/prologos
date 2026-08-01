#lang racket/base

;;;
;;; Rel Track 1 — Aspect-A (NAF/guard correctness) tests.
;;;
;;; A.1: a top-level bare `not` goal now RUNS via the DFS engine instead of
;;;      being echoed unevaluated (reduction.rkt run-solve-goal/-one/-explain).
;;;
;;; Grows as A.2 (per-binding belief-clear), A.3 (static floundering gate),
;;; and A.4 (guard) land. E2E fixture mirrors test-relational-e2e.rkt.
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         "../driver.rkt"
         "../errors.rkt"
         "../namespace.rkt"
         "../relations.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a .prologos string through the full pipeline; return result strings.
(define (run-prologos-string content)
  (define tmp (make-temporary-file "rel-t1-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (last-result results) (last results))

;; A small vehicle/license world reused across cases.
(define world
  (string-append
   "ns t :no-prelude\n\n"
   "defr vehicle [?type]\n  || \"bicycle\"\n     \"automobile\"\n\n"
   "defr license [?v]\n  || \"automobile\"\n\n"))

;; A small graph world (edges + a block set) for the A.2b rule-generator cases.
(define graph-world
  (string-append
   "ns t :no-prelude\n\n"
   "defr edge [?a ?b]\n  || \"x\" \"y\"\n     \"y\" \"z\"\n     \"y\" \"w\"\n\n"
   "defr blk [?n]\n  || \"z\"\n\n"))

;; ========================================
;; A.1 — top-level bare `not` goal runs (was echoed)
;; ========================================

(test-case "A.1: solve (not G) for an UNLICENSED ground arg — NAF succeeds, not echoed"
  (define results
    (run-prologos-string
     (string-append world "eval (solve (not (license \"bicycle\")))\n")))
  (define r (last-result results))
  (check-true (string? r))
  ;; the echo would have printed the goal back: "(solve (not (license ...)))"
  (check-false (string-contains? r "solve")
               "top-level (not G) must not be echoed unevaluated")
  ;; bicycle is not licensed => NAF succeeds => one empty-binding answer {}
  (check-true (string-contains? r "{}")
              "NAF over an unlicensed ground arg should succeed with an empty answer"))

(test-case "A.1: solve (not G) for a LICENSED ground arg — NAF fails (nil), not echoed"
  (define results
    (run-prologos-string
     (string-append world "eval (solve (not (license \"automobile\")))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-false (string-contains? r "solve")
               "top-level (not G) must not be echoed unevaluated")
  (check-true (string-contains? r "@[]")
              "NAF over a licensed ground arg should fail (empty result)"))

(test-case "A.1: solve-one (not G) — runs, returns none for a failed NAF"
  (define results
    (run-prologos-string
     (string-append world "eval (solve-one (not (license \"automobile\")))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-false (string-contains? r "solve-one")
               "top-level solve-one (not G) must not be echoed unevaluated")
  (check-true (string-contains? r "none")
              "solve-one of a failed NAF should be none"))

;; ========================================
;; A.2 — clause-body NAF per-binding belief-clear (FACT generator)
;; ========================================

(test-case "A.2: clause-body NAF over a FACT generator — only the unblocked binding survives"
  ;; light-vehicle(v) :- vehicle(v), not(license(v))
  ;; vehicle={bicycle,automobile}, license={automobile} => {bicycle} only.
  ;; Pre-A.2 the single-shared-bit collapse over-included BOTH ({both}).
  (define results
    (run-prologos-string
     (string-append world
       "defr light-vehicle [?v]\n  &> (vehicle v) (not (license v))\n\n"
       "eval (solve (light-vehicle lv))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-true (string-contains? r "bicycle")
              "the unlicensed vehicle should be in the solution")
  (check-false (string-contains? r "automobile")
               "the licensed vehicle must NOT leak (A.2 per-binding belief-clear)"))

(test-case "A.2: ground clause-body NAF queries route to DFS and stay correct"
  (define results
    (run-prologos-string
     (string-append world
       "defr light-vehicle [?v]\n  &> (vehicle v) (not (license v))\n\n"
       "eval (solve (light-vehicle \"bicycle\"))\n"      ;; unlicensed => succeeds
       "eval (solve (light-vehicle \"automobile\"))\n"))) ;; licensed => fails
  (check-true (>= (length results) 2))
  (define bicycle-r (list-ref results (- (length results) 2)))
  (define auto-r (last results))
  (check-true (string-contains? bicycle-r "{}")
              "ground unlicensed vehicle succeeds")
  (check-true (string-contains? auto-r "@[]")
              "ground licensed vehicle fails"))

;; ========================================
;; A.2b — NAF over a body-local-var RULE generator routes to DFS (correct).
;; The on-network engine can't thread body-local (non-param) clause vars, so a
;; join/recursion rule generator is INCOMPLETE on-network; the adaptive dispatcher
;; (stratified-eval use-propagator? reachable-has-body-local-rule?) routes these to
;; DFS. SCAFFOLDING — retires with BSP-LE Track 3 (on-network body-local + SLG).
;; ========================================

(test-case "A.2b: NAF over a JOIN rule generator (body-local var) — routed to DFS, correct"
  ;; twohop(a,c) :- edge(a,b), edge(b,c)   [b is a body-local join var]
  ;; safe-twohop(a,c) :- twohop(a,c), not(blk(c))
  ;; twohop(x)={z,w}, blk={z} => safe-twohop(x,c)={w}.
  ;; On-network the join var b can't thread (=> {}); DFS threads it correctly.
  (define results
    (run-prologos-string
     (string-append graph-world
       "defr twohop [?a ?c]\n  &> (edge a b) (edge b c)\n\n"
       "defr safe-twohop [?a ?c]\n  &> (twohop a c) (not (blk c))\n\n"
       "eval (solve (safe-twohop \"x\" c))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-true (string-contains? r "\"w\"")
              "the unblocked two-hop target must be in the solution")
  (check-false (string-contains? r "\"z\"")
               "the blocked target must not leak"))

(test-case "A.2b: NAF over a RECURSIVE rule generator — routed to DFS, complete + correct"
  ;; reaches(a,c) :- edge(a,c) ; edge(a,b), reaches(b,c)   [b is a body-local recursion var]
  ;; safe-reach(a,c) :- reaches(a,c), not(blk(c))
  ;; reaches(x)={y,z,w}, blk={z} => safe-reach(x,c)={y,w}.
  ;; On-network reaches yields the base case only ({y}); DFS is complete.
  (define results
    (run-prologos-string
     (string-append graph-world
       "defr reaches [?a ?c]\n  &> (edge a c)\n  &> (edge a b) (reaches b c)\n\n"
       "defr safe-reach [?a ?c]\n  &> (reaches a c) (not (blk c))\n\n"
       "eval (solve (safe-reach \"x\" c))\n")))
  (define r (last-result results))
  (check-true (string? r))
  (check-true (string-contains? r "\"y\"")
              "the base-reachable unblocked target must be present")
  (check-true (string-contains? r "\"w\"")
              "the transitively-reachable unblocked target must be present (recursion not dropped)")
  (check-false (string-contains? r "\"z\"")
               "the blocked target must not leak"))

;; ========================================
;; A.3 — static floundering gate: a `not`/`guard` var bound by NOTHING is unsafe.
;; PERMISSIVE (Prolog `\+` mode discipline): head params COUNT as binders, so
;; `p(x) :- not q(x)` is allowed (an unsafe-mode call gives the standard Prolog nil).
;; ========================================

;; A prologos-error surfaces as a struct in the results list (not a string);
;; stringify uniformly (mirrors test-validate.rkt's result-str).
(define (result-str r)
  (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))

(test-case "A.3 Site A: defr clause with a body var bound by nothing → floundering error"
  ;; bad(y) :- not(lic(z))  — z is bound by no positive goal → unsafe.
  (define results
    (run-prologos-string
     (string-append "ns t :no-prelude\n\n"
       "defr lic [?x]\n  || \"car\"\n\n"
       "defr bad [?y]\n  &> (not (lic z))\n")))
  (define s (result-str (last-result results)))
  (check-true (string-contains? s "floundering")
              "an unbound negation var must be flagged as floundering")
  (check-true (string-contains? s "variable z")
              "the offending variable is named"))

(test-case "A.3 Site A (permissive): `not` over a head param registers OK; ground call is safe"
  ;; risky(x) :- not(lic(x)) — x is a head param → permissive allows it.
  (define results
    (run-prologos-string
     (string-append "ns t :no-prelude\n\n"
       "defr lic [?x]\n  || \"car\"\n\n"
       "defr risky [?x]\n  &> (not (lic x))\n\n"
       "eval (solve (risky \"bike\"))\n")))  ;; bike not licensed → succeeds
  (define s (result-str (last-result results)))
  (check-false (string-contains? s "floundering")
               "a head-param negation must NOT be rejected (permissive)")
  (check-true (string-contains? s "{}")
              "the ground safe call succeeds"))

(test-case "A.3 Site B: top-level solve (not G) with a free var → warning + nil (Prolog-parity)"
  ;; Prolog runs the query and returns the standard unsafe-`\+` result (nil); a
  ;; non-fatal floundering warning goes to stderr (not a hard error).
  (define err (open-output-string))
  (define results
    (parameterize ([current-error-port err])
      (run-prologos-string
       (string-append "ns t :no-prelude\n\n"
         "defr lic [?x]\n  || \"car\"\n\n"
         "eval (solve (not (lic v)))\n"))))
  (define s (result-str (last-result results)))
  (check-true (string-contains? s "@[]")
              "top-level `not` over a free var returns the standard Prolog empty result (not an error)")
  (check-true (string-contains? (get-output-string err) "floundering")
              "a floundering warning is emitted to stderr"))

;; ========================================
;; A.4 — guard: guard-bearing queries route to DFS (SCAFFOLDING, retire w/ BSP-LE
;; Track 3). On-network guards are buggy (the single shared guard bit cannot filter
;; per-row; the S0 belief-narrow is re-projected away; struct conditions weren't
;; resolved). Check 4 (`reachable-has-guard?` in stratified-eval) routes them to
;; DFS, which filters guards correctly for ground AND free-var, single AND multi-
;; fact generators. Design for the on-network guard mechanism is captured in the
;; BSP-LE Track 3 note.
;; ========================================

(define guard-world
  (string-append
   "ns t :no-prelude\n\n"
   "defr weighted-edge [?from ?to ?weight]\n  || \"a\" \"b\" 3\n     \"b\" \"c\" 0\n     \"c\" \"d\" 5\n\n"
   "defr positive-edge [?from ?to ?weight]\n  &> (weighted-edge from to weight) (guard [gt weight 0])\n\n"))

(test-case "A.4: guard over a multi-fact generator filters per-row (routed to DFS)"
  ;; weighted-edge = {(a,b,3),(b,c,0),(c,d,5)}; positive-edge keeps weight > 0.
  ;; On-network the single shared guard bit leaks/over-narrows; DFS filters per-row.
  (define results
    (run-prologos-string
     (string-append guard-world "eval (solve (positive-edge from to w))\n")))
  (define s (result-str (last-result results)))
  (check-true (string-contains? s ":w 3") "the w=3 edge (a→b) is kept")
  (check-true (string-contains? s ":w 5") "the w=5 edge (c→d) is kept")
  (check-false (string-contains? s ":w 0") "the w=0 edge (b→c) is filtered out"))

(test-case "A.4: ground guard queries stay correct"
  (define results
    (run-prologos-string
     (string-append guard-world
       "eval (solve (positive-edge \"a\" \"b\" 3))\n"      ;; w=3 passes
       "eval (solve (positive-edge \"b\" \"c\" 0))\n")))   ;; w=0 fails
  (check-true (>= (length results) 2))
  (define pass-r (result-str (list-ref results (- (length results) 2))))
  (define fail-r (result-str (last-result results)))
  (check-true (string-contains? pass-r "{}") "w=3 passes the guard")
  (check-true (string-contains? fail-r "@[]") "w=0 fails the guard"))

