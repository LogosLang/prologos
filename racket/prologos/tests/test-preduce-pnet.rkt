#lang racket/base
;; PReduce Track 5 Phase 1 — the .pnet/2 container's first realization + origin
;; provenance + the projection (ledger iter 36).
(require rackunit racket/set racket/file
         "../pnet-sections.rkt"
         "../preduce-pnet.rkt"
         (only-in "../pnet-serialize.rkt" deep-serializable->struct)
         "../eclass-graph.rkt"
         "../eclass-cell.rkt"
         "../extraction-store.rkt"
         "../propagator.rkt"
         "../syntax.rkt")

;; ---- the container: round-trip + unknown-tag skip + degraded reads ----
(define tmp (make-temporary-file "pnetx-test-~a"))
(pnet2-write-sections tmp (list (cons 'alpha '(1 2 3))
                                (cons 'beta (hash 'k "v"))))
(define secs (pnet2-read-sections tmp))
(check-equal? (pnet2-section-ref secs 'alpha) '(1 2 3) "round-trip")
(check-equal? (pnet2-section-ref secs 'beta) (hash 'k "v"))
(check-false (pnet2-section-ref secs 'unknown-tag) "unknown tags skip by lookup")
(check-false (pnet2-read-sections "/nonexistent/path.pnetx") "missing file = degraded #f")
(display-to-file "(not-a-pnet2-file)" tmp #:exists 'replace)
(check-false (pnet2-read-sections tmp) "malformed = degraded #f, never fatal")
(delete-file tmp)

;; ---- origin provenance + the projection ----
(parameterize ([current-intern-origin 'test-module]
               [current-parent-index-cell-id #f])
  (define-values (net0 hc) (make-eclass-graph (make-prop-network)))
  (define pb (box net0))
  (init-extraction-store-cell! pb)
  (define store (current-extraction-store-cell-id))
  (define-values (net1 c1 _d1) (eclass-intern (unbox pb) hc (expr-int 42) #:cost 1))
  ;; an effectful class: NEVER ground/projected
  (define occ (box (hash)))
  (define-values (net2 c2 _k2) (eclass-intern-effectful net1 occ 'read 0 '(p)))
  ;; a class interned under a DIFFERENT origin: filtered out
  (define-values (net3 c3 _d3)
    (parameterize ([current-intern-origin 'other-module])
      (eclass-intern net2 hc (expr-int 99) #:cost 1)))
  (define net4 (run-to-quiescence net3))
  ;; provenance carries the origin (scan semantics)
  (check-true (set-member? (hash-ref (eclass-read net4 c1) ':provenance)
                           'origin:test-module)
              "interned origin marker (eq-stable across constructions)")
  ;; the projection: only the ground, this-origin, admissible class
  (define sections (preduce-project-sections net4 hc store 'test-module))
  (define ecs (cdr (assq 'preduce-eclasses sections)))
  (check-equal? (length ecs) 1 "exactly the one ground/this-origin class projects")
  (check-equal? (deep-serializable->struct (cadr (car ecs))) (expr-int 42)
                "the projected form decodes to the best (codec-encoded since 2026-06-11)")
  ;; residue tolerance (iter 37 amendment): the projection reads cell state;
  ;; pending worklist ids cannot change it — projecting a non-drained net is
  ;; the PRODUCTION reality (the prn's permanent residue finding)
  (define-values (net5 cc) (net-new-cell net4 'bot (lambda (o n) n)))
  (define-values (net6 _pid)
    (net-add-propagator net5 (list cc) (list cc) (lambda (n) n)))
  (check-not-exn (lambda () (preduce-project-sections net6 hc store 'test-module))
                 "residue-tolerant projection")
  ;; full file round-trip through the projection
  (define tmp2 (make-temporary-file "pnetx-proj-~a"))
  (preduce-write-pnetx! tmp2 net4 hc store 'test-module)
  (define back (pnet2-read-sections tmp2))
  (check-equal? (length (pnet2-section-ref back 'preduce-eclasses)) 1)
  (delete-file tmp2))

;; ---- key-survival regression (2026-06-11): memo classes must be reachable by
;; their PERSISTED (body) digest on reload — the warm lookup arrives keyed by
;; digest(body); the persisted form is the cost-0 RESULT whose digest differs.
;; Pre-fix, 100% of real memo entries were unreachable warm (DEFERRED.md entry).
(parameterize ([current-intern-origin 'memo-test]
               [current-parent-index-cell-id #f])
  (define-values (net0 hc) (make-eclass-graph (make-prop-network)))
  (define pb (box net0))
  (define body '(reduce memo-body 20 22))
  (define result '(memo-result 42))
  (define-values (net1 cid1 _bd) (eclass-intern (unbox pb) hc body #:cost 10))
  (define net2 (net-cell-write net1 cid1 (make-eclass-value #:best (cons 0 result))))
  (set-box! pb net2)
  (define src (make-temporary-file "pnetx-src-~a"))
  (display-to-file "x" src #:exists 'replace)
  (preduce-save-pnetx! pb src hc #f 'memo-test)
  ;; fresh world (a new session)
  (define-values (wnet0 whc) (make-eclass-graph (make-prop-network)))
  (define wb (box wnet0))
  (preduce-load-pnetx! wb src whc #f)
  ;; the warm intern of the BODY must hit the memo
  (define-values (wnet1 wcid _wd) (eclass-intern (unbox wb) whc body #:cost 10))
  (set-box! wb wnet1)
  (define wbest (hash-ref (eclass-read (unbox wb) wcid) ':best #f))
  (check-true (and wbest (zero? (car wbest)))
              "key survival: warm body intern hits the memo (cost 0)")
  (check-equal? (cdr wbest) result "the memoized result is served warm")
  (delete-file src)
  (delete-file (preduce-pnetx-path src)))

;; ---- expr-STRUCT round-trip regression (2026-06-11, second stacked defect):
;; transparent expr structs do not survive raw write/read (they come back as
;; plain vectors and crash nf with "no matching clause" when served warm).
;; The container payloads now route through pnet-serialize's codec; this
;; round-trips the exact crashing shape (an expr-lam result).
(parameterize ([current-intern-origin 'codec-test]
               [current-parent-index-cell-id #f])
  (define-values (net0 hc) (make-eclass-graph (make-prop-network)))
  (define pb (box net0))
  (define body (expr-app (expr-lam 'mw (expr-Int) (expr-bvar 0)) (expr-int 7)))
  (define result (expr-lam 'mw (expr-Int) (expr-bvar 0)))
  (define-values (net1 cid1 _d) (eclass-intern (unbox pb) hc body #:cost 10))
  (define net2 (net-cell-write net1 cid1 (make-eclass-value #:best (cons 0 result))))
  (set-box! pb net2)
  (define src (make-temporary-file "pnetx-codec-~a"))
  (display-to-file "x" src #:exists 'replace)
  (preduce-save-pnetx! pb src hc #f 'codec-test)
  (define-values (wnet0 whc) (make-eclass-graph (make-prop-network)))
  (define wb (box wnet0))
  (preduce-load-pnetx! wb src whc #f)
  (define-values (wnet1 wcid _wd) (eclass-intern (unbox wb) whc body #:cost 10))
  (set-box! wb wnet1)
  (define wbest (hash-ref (eclass-read (unbox wb) wcid) ':best #f))
  (check-true (and wbest (zero? (car wbest))) "expr-struct memo hits warm")
  (check-true (expr-lam? (cdr wbest))
              "the served form is a REAL expr-lam struct, not a vector")
  (check-equal? (cdr wbest) result "expr round-trips structurally equal")
  (delete-file src)
  (delete-file (preduce-pnetx-path src)))
