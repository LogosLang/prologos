#lang racket/base

;;;
;;; test-module-network-01.rkt — Track 5 Phase 1 unit tests
;;;
;;; Tests:
;;;   1. Module lifecycle lattice (merge-mod-status)
;;;   2. module-network-ref struct and operations
;;;   3. Shadow-cell cross-network prototype
;;;

(require rackunit
         "../propagator.rkt"
         "../infra-cell.rkt"
         "../namespace.rkt"
         "../global-env.rkt")  ;; PPN 4C Addendum Phase 4A.c-ii-a: external-definitions-* tests

;; ========================================
;; 1. Module Lifecycle Lattice
;; ========================================

(test-case "merge-mod-status: bot + loading = loading"
  (check-equal? (merge-mod-status 'infra-bot mod-loading) mod-loading))

(test-case "merge-mod-status: bot + loaded = loaded"
  (check-equal? (merge-mod-status 'infra-bot mod-loaded) mod-loaded))

(test-case "merge-mod-status: bot + stale = stale"
  (check-equal? (merge-mod-status 'infra-bot mod-stale) mod-stale))

(test-case "merge-mod-status: loading + loaded = loaded"
  (check-equal? (merge-mod-status mod-loading mod-loaded) mod-loaded))

(test-case "merge-mod-status: loaded + loading = loaded (monotone)"
  (check-equal? (merge-mod-status mod-loaded mod-loading) mod-loaded))

(test-case "merge-mod-status: loaded + stale = stale"
  (check-equal? (merge-mod-status mod-loaded mod-stale) mod-stale))

(test-case "merge-mod-status: stale + loaded = stale (stale dominates)"
  (check-equal? (merge-mod-status mod-stale mod-loaded) mod-stale))

(test-case "merge-mod-status: stale + stale = stale"
  (check-equal? (merge-mod-status mod-stale mod-stale) mod-stale))

(test-case "merge-mod-status: loading + loading = loading"
  (check-equal? (merge-mod-status mod-loading mod-loading) mod-loading))

;; ========================================
;; 2. Module Network Ref — CRUD Operations
;; ========================================

(test-case "make-module-network: creates with mod-loading status"
  (define mnr (make-module-network))
  (check-equal? (module-network-status mnr) mod-loading)
  (check-equal? (module-network-ref-cell-id-map mnr) (hasheq))
  (check-equal? (module-network-ref-dep-edges mnr) (hasheq))
  (check-false  (module-network-ref-snapshot-hash mnr)))

(test-case "module-network-add-definition: adds a cell, lookup works"
  (define mnr0 (make-module-network))
  (define-values (mnr1 cid) (module-network-add-definition mnr0 'foo (cons 'Int 42)))
  (check-not-false cid)
  (define result (module-network-lookup mnr1 'foo))
  (check-equal? result (cons 'Int 42)))

(test-case "module-network-lookup: returns #f for missing name"
  (define mnr (make-module-network))
  (check-false (module-network-lookup mnr 'nonexistent)))

(test-case "module-network-write: updates existing cell"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _cid) (module-network-add-definition mnr0 'bar (cons 'Int 1)))
  (define mnr2 (module-network-write mnr1 'bar (cons 'Int 99)))
  (check-equal? (module-network-lookup mnr2 'bar) (cons 'Int 99)))

(test-case "module-network-set-status: loading → loaded"
  (define mnr0 (make-module-network))
  (check-equal? (module-network-status mnr0) mod-loading)
  (define mnr1 (module-network-set-status mnr0 mod-loaded))
  (check-equal? (module-network-status mnr1) mod-loaded))

(test-case "module-network-set-status: loaded → stale (monotone)"
  (define mnr0 (make-module-network))
  (define mnr1 (module-network-set-status mnr0 mod-loaded))
  (define mnr2 (module-network-set-status mnr1 mod-stale))
  (check-equal? (module-network-status mnr2) mod-stale))

(test-case "module-network-set-status: stale + loaded stays stale (monotone merge)"
  (define mnr0 (make-module-network))
  (define mnr1 (module-network-set-status mnr0 mod-stale))
  (define mnr2 (module-network-set-status mnr1 mod-loaded))
  (check-equal? (module-network-status mnr2) mod-stale))

(test-case "module-network-materialize: returns all definitions"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'foo (cons 'Int 1)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'bar (cons 'String "hi")))
  (define-values (mnr3 _c3) (module-network-add-definition mnr2 'baz (cons 'Bool #t)))
  (define snap (module-network-materialize mnr3))
  (check-equal? (hash-count snap) 3)
  (check-equal? (hash-ref snap 'foo) (cons 'Int 1))
  (check-equal? (hash-ref snap 'bar) (cons 'String "hi"))
  (check-equal? (hash-ref snap 'baz) (cons 'Bool #t)))

(test-case "module-network: multiple definitions with overwrites"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'x (cons 'Int 10)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'y (cons 'Int 20)))
  ;; Overwrite x
  (define mnr3 (module-network-write mnr2 'x (cons 'Int 100)))
  (check-equal? (module-network-lookup mnr3 'x) (cons 'Int 100))
  (check-equal? (module-network-lookup mnr3 'y) (cons 'Int 20)))

;; ========================================
;; 2b. Imports field + cascading lookup (PPN 4C Addendum Phase 4A.a)
;; ========================================
;; Q-4A.4 Option (b) share-by-reference: mnr.imports holds REFERENCES to
;; imported mnrs; module-network-cascading-lookup walks local then imports.
;; Q1 cons-prepend (newest first) → last-write-wins shadowing.

(test-case "make-module-network: imports defaults to empty"
  (define mnr (make-module-network))
  (check-equal? (module-network-ref-imports mnr) '()))

(test-case "module-network-add-import: cons-prepends (newest first)"
  (define base (make-module-network))
  (define imp-a (make-module-network))
  (define imp-b (make-module-network))
  (define m1 (module-network-add-import base imp-a))
  (define m2 (module-network-add-import m1 imp-b))
  ;; cons-prepend: imp-b (newest) at front, imp-a after
  (check-equal? (module-network-ref-imports m2) (list imp-b imp-a)))

(test-case "cascading-lookup: local hit (no imports)"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c) (module-network-add-definition mnr0 'foo (cons 'Int 1)))
  (check-equal? (module-network-cascading-lookup mnr1 'foo) (cons 'Int 1)))

(test-case "cascading-lookup: miss returns #f"
  (define mnr (make-module-network))
  (check-equal? (module-network-cascading-lookup mnr 'absent) #f))

(test-case "cascading-lookup: one-level import hit"
  ;; imp defines bar; local imports imp; lookup bar cascades into imp
  (define imp0 (make-module-network))
  (define-values (imp1 _c) (module-network-add-definition imp0 'bar (cons 'String "from-imp")))
  (define local0 (make-module-network))
  (define local1 (module-network-add-import local0 imp1))
  (check-equal? (module-network-cascading-lookup local1 'bar) (cons 'String "from-imp"))
  ;; local has no own defs → miss for a name nowhere
  (check-equal? (module-network-cascading-lookup local1 'nope) #f))

(test-case "cascading-lookup: transitive (two-level) import hit"
  ;; grandparent defines deep; parent imports grandparent; local imports parent
  (define gp0 (make-module-network))
  (define-values (gp1 _c) (module-network-add-definition gp0 'deep (cons 'Bool #t)))
  (define parent0 (make-module-network))
  (define parent1 (module-network-add-import parent0 gp1))
  (define local0 (make-module-network))
  (define local1 (module-network-add-import local0 parent1))
  (check-equal? (module-network-cascading-lookup local1 'deep) (cons 'Bool #t)))

(test-case "cascading-lookup: local shadows import (same name)"
  ;; both local and imp define dup; local wins (walked first)
  (define imp0 (make-module-network))
  (define-values (imp1 _ci) (module-network-add-definition imp0 'dup (cons 'Int 'from-import)))
  (define local0 (make-module-network))
  (define-values (local1 _cl) (module-network-add-definition local0 'dup (cons 'Int 'from-local)))
  (define local2 (module-network-add-import local1 imp1))
  (check-equal? (module-network-cascading-lookup local2 'dup) (cons 'Int 'from-local)))

(test-case "cascading-lookup: newest import shadows older (cons-prepend order)"
  ;; imp-old and imp-new both define same name; imp-new added last (cons-front) wins
  (define imp-old0 (make-module-network))
  (define-values (imp-old1 _co) (module-network-add-definition imp-old0 'shared (cons 'Int 'old)))
  (define imp-new0 (make-module-network))
  (define-values (imp-new1 _cn) (module-network-add-definition imp-new0 'shared (cons 'Int 'new)))
  (define local0 (make-module-network))
  (define local1 (module-network-add-import local0 imp-old1))  ;; older first
  (define local2 (module-network-add-import local1 imp-new1))  ;; newer cons-front
  ;; list-order walk hits imp-new1 (front) first → 'new wins (last-write-wins)
  (check-equal? (module-network-cascading-lookup local2 'shared) (cons 'Int 'new)))

;; ========================================
;; 2b-cascade. Cascade materialize/names (PPN 4C Addendum Phase 4A.c-ii-a, D2 Path Y)
;; ========================================
;; module-network-cascade-materialize = VALUES view of own cells + imports
;; (recursive); module-network-cascade-names = keys-only counterpart. Shadowing
;; matches module-network-cascading-lookup. Backs external-definitions-snapshot
;; / external-definition-names (excludes the LOCAL caller's own cells, applied
;; one level up — these helpers materialize a GIVEN mnr in full).

(define (sorted-syms xs) (sort xs symbol<?))

(test-case "cascade-materialize: local only == module-network-materialize"
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'foo (cons 'Int 1)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'bar (cons 'String "hi")))
  (check-equal? (module-network-cascade-materialize mnr2)
                (module-network-materialize mnr2)))

(test-case "cascade-materialize: one-level import merges own + imported"
  (define imp0 (make-module-network))
  (define-values (imp1 _ci) (module-network-add-definition imp0 'ibar (cons 'String "imp")))
  (define local0 (make-module-network))
  (define-values (local1 _cl) (module-network-add-definition local0 'lfoo (cons 'Int 1)))
  (define local2 (module-network-add-import local1 imp1))
  (check-equal? (module-network-cascade-materialize local2)
                (hasheq 'lfoo (cons 'Int 1) 'ibar (cons 'String "imp"))))

(test-case "cascade-materialize: transitive (two-level) flattens all"
  (define gp0 (make-module-network))
  (define-values (gp1 _cg) (module-network-add-definition gp0 'deep (cons 'Bool #t)))
  (define parent0 (make-module-network))
  (define-values (parent1 _cp) (module-network-add-definition parent0 'mid (cons 'Int 5)))
  (define parent2 (module-network-add-import parent1 gp1))
  (define local0 (make-module-network))
  (define-values (local1 _cl) (module-network-add-definition local0 'top (cons 'Int 9)))
  (define local2 (module-network-add-import local1 parent2))
  (check-equal? (module-network-cascade-materialize local2)
                (hasheq 'top (cons 'Int 9) 'mid (cons 'Int 5) 'deep (cons 'Bool #t))))

(test-case "cascade-materialize: local shadows import (same name → local value)"
  (define imp0 (make-module-network))
  (define-values (imp1 _ci) (module-network-add-definition imp0 'dup (cons 'Int 'from-import)))
  (define local0 (make-module-network))
  (define-values (local1 _cl) (module-network-add-definition local0 'dup (cons 'Int 'from-local)))
  (define local2 (module-network-add-import local1 imp1))
  (check-equal? (hash-ref (module-network-cascade-materialize local2) 'dup)
                (cons 'Int 'from-local)))

(test-case "cascade-materialize: newest import shadows older (cons-prepend order)"
  (define imp-old0 (make-module-network))
  (define-values (imp-old1 _co) (module-network-add-definition imp-old0 'shared (cons 'Int 'old)))
  (define imp-new0 (make-module-network))
  (define-values (imp-new1 _cn) (module-network-add-definition imp-new0 'shared (cons 'Int 'new)))
  (define local0 (make-module-network))
  (define local1 (module-network-add-import local0 imp-old1))  ;; older first
  (define local2 (module-network-add-import local1 imp-new1))  ;; newer cons-front
  (check-equal? (hash-ref (module-network-cascade-materialize local2) 'shared)
                (cons 'Int 'new)))

(test-case "cascade-names: keys match cascade-materialize keys (transitive)"
  (define gp0 (make-module-network))
  (define-values (gp1 _cg) (module-network-add-definition gp0 'deep (cons 'Bool #t)))
  (define parent0 (make-module-network))
  (define-values (parent1 _cp) (module-network-add-definition parent0 'mid (cons 'Int 5)))
  (define parent2 (module-network-add-import parent1 gp1))
  (define local0 (make-module-network))
  (define-values (local1 _cl) (module-network-add-definition local0 'top (cons 'Int 9)))
  (define local2 (module-network-add-import local1 parent2))
  (check-equal? (sorted-syms (module-network-cascade-names local2))
                (sorted-syms (hash-keys (module-network-cascade-materialize local2))))
  (check-equal? (sorted-syms (module-network-cascade-names local2))
                (sorted-syms '(top mid deep))))

(test-case "cascade-names: dedups a name present in both local and import"
  (define imp0 (make-module-network))
  (define-values (imp1 _ci) (module-network-add-definition imp0 'dup (cons 'Int 'i)))
  (define local0 (make-module-network))
  (define-values (local1 _cl) (module-network-add-definition local0 'dup (cons 'Int 'l)))
  (define local2 (module-network-add-import local1 imp1))
  (check-equal? (module-network-cascade-names local2) '(dup)))

(test-case "cascade-names/materialize: empty mnr → empty"
  (define mnr (make-module-network))
  (check-equal? (module-network-cascade-names mnr) '())
  (check-equal? (module-network-cascade-materialize mnr) (hasheq)))

;; ========================================
;; 2e. external-definitions view (PPN 4C Addendum Phase 4A.c-ii-a, D2 Path Y)
;; ========================================
;; external-definitions-snapshot (values) / external-definition-names (keys),
;; defined in global-env.rkt: Layer-2 base (prelude ∪ module-defs) overlaid by
;; current-file-mnr's IMPORTS cascade, EXCLUDING the file's own (local) cells.
;; The exclusion is the defining (Y) property — these consumers must see only
;; EXTERNAL defs (prelude + imported), never the file's own mid-elaboration defs.

(test-case "external-definitions-snapshot: pre-flip = Layer-2, EXCLUDES local mnr cells"
  ;; local mnr has its own def 'localdef + EMPTY imports (the pre-flip state)
  (define-values (local1 _cl)
    (module-network-add-definition (make-module-network) 'localdef (cons 'Int 99)))
  (parameterize ([current-prelude-env (hasheq 'p1 (cons 'Int 1))]
                 [current-module-definitions-content (hasheq 'm1 (cons 'Int 2))]
                 [current-file-module-network-ref local1])
    ;; = prelude ∪ module-defs; 'localdef EXCLUDED (the (Y) property)
    (check-equal? (external-definitions-snapshot)
                  (hasheq 'p1 (cons 'Int 1) 'm1 (cons 'Int 2)))
    (check-equal? (sorted-syms (external-definition-names)) (sorted-syms '(p1 m1)))))

(test-case "external-definitions-snapshot: imports cascade overlays Layer-2, still excludes local"
  (define-values (imp1 _ci)
    (module-network-add-definition (make-module-network) 'impdef (cons 'String "imp")))
  (define-values (local1 _cl)
    (module-network-add-definition (make-module-network) 'localdef (cons 'Int 99)))
  (define local2 (module-network-add-import local1 imp1))
  (parameterize ([current-prelude-env (hasheq 'p1 (cons 'Int 1))]
                 [current-module-definitions-content (hasheq)]
                 [current-file-module-network-ref local2])
    ;; prelude p1 + import's impdef; localdef EXCLUDED
    (check-equal? (external-definitions-snapshot)
                  (hasheq 'p1 (cons 'Int 1) 'impdef (cons 'String "imp")))
    (check-equal? (sorted-syms (external-definition-names)) (sorted-syms '(p1 impdef)))))

(test-case "external-definition-names: keys match external-definitions-snapshot"
  (define-values (imp1 _ci)
    (module-network-add-definition (make-module-network) 'impdef (cons 'Int 7)))
  (define local2 (module-network-add-import (make-module-network) imp1))
  (parameterize ([current-prelude-env (hasheq 'p1 (cons 'Int 1) 'p2 (cons 'Int 2))]
                 [current-module-definitions-content (hasheq 'm1 (cons 'Int 3))]
                 [current-file-module-network-ref local2])
    (check-equal? (sorted-syms (external-definition-names))
                  (sorted-syms (hash-keys (external-definitions-snapshot))))))

(test-case "external-definitions-snapshot: no current-file-mnr → Layer-2 only"
  (parameterize ([current-prelude-env (hasheq 'p1 (cons 'Int 1))]
                 [current-module-definitions-content (hasheq 'm1 (cons 'Int 2))]
                 [current-file-module-network-ref #f])
    (check-equal? (external-definitions-snapshot)
                  (hasheq 'p1 (cons 'Int 1) 'm1 (cons 'Int 2)))))

;; ========================================
;; 2c. Reconstruction from snapshot (PPN 4C Addendum Phase 4A.c-i, RISK 1)
;; ========================================
;; module-network-from-snapshot rebuilds an mnr from a flat env-snapshot
;; (the .pnet-cache restore shape) so share-by-reference can reference it.

(test-case "module-network-from-snapshot: round-trips a snapshot"
  (define snap (hasheq 'foo (cons 'Int 1) 'bar (cons 'String "hi") 'baz (cons 'Bool #t)))
  (define mnr (module-network-from-snapshot snap))
  ;; materialize back == original snapshot (all cells reconstructed)
  (check-equal? (module-network-materialize mnr) snap)
  ;; reconstructed module is loaded
  (check-equal? (module-network-status mnr) mod-loaded)
  ;; cascading-lookup finds reconstructed entries
  (check-equal? (module-network-cascading-lookup mnr 'foo) (cons 'Int 1))
  (check-equal? (module-network-cascading-lookup mnr 'absent) #f))

(test-case "module-network-from-snapshot: empty snapshot → empty mnr (loaded)"
  (define mnr (module-network-from-snapshot (hasheq)))
  (check-equal? (module-network-materialize mnr) (hasheq))
  (check-equal? (module-network-status mnr) mod-loaded))

;; ========================================
;; 3. Shadow-Cell Cross-Network Prototype
;; ========================================
;;
;; Validates the core architectural pattern for Track 5:
;; Two independent prop-networks (simulating two modules).
;; A shadow cell in network B is initialized from a cell in network A.
;; Propagation within B works from the shadow cell.
;; "Reload" of A is simulated by writing to B's shadow cell.

(test-case "shadow-cell: cross-network read via shadow initialization"
  ;; Network A: module "bar" with a definition cell
  (define net-a0 (make-prop-network))
  (define-values (net-a1 bar-cell) (net-new-cell net-a0 (cons 'Int 42) merge-replace))

  ;; Network B: file "foo" creates a shadow cell initialized from A's value
  (define bar-value (net-cell-read net-a1 bar-cell))
  (define net-b0 (make-prop-network))
  (define-values (net-b1 shadow-cell) (net-new-cell net-b0 bar-value merge-replace))

  ;; Verify: shadow cell in B has bar's value
  (check-equal? (net-cell-read net-b1 shadow-cell) (cons 'Int 42)))

(test-case "shadow-cell: propagation within B from shadow cell"
  ;; Network A: module "bar"
  (define net-a0 (make-prop-network))
  (define-values (net-a1 bar-cell) (net-new-cell net-a0 (cons 'Int 42) merge-replace))

  ;; Network B: shadow cell + downstream cell + propagator
  (define net-b0 (make-prop-network))
  (define bar-val (net-cell-read net-a1 bar-cell))
  (define-values (net-b1 shadow) (net-new-cell net-b0 bar-val merge-replace))
  (define-values (net-b2 result) (net-new-cell net-b1 'infra-bot merge-replace))

  ;; Propagator: when shadow changes, write its cdr (the value part) to result
  ;; fire-fn contract: (prop-network → prop-network)
  (define (extract-value-prop net)
    (define shadow-val (net-cell-read net shadow))
    (if (and shadow-val (pair? shadow-val))
        (net-cell-write net result (cdr shadow-val))
        net))

  (define-values (net-b3 _pid)
    (net-add-propagator net-b2 (list shadow) (list result) extract-value-prop))
  (define net-b4 (run-to-quiescence net-b3))

  ;; Result cell should have the extracted value
  (check-equal? (net-cell-read net-b4 result) 42))

(test-case "shadow-cell: simulated reload updates propagation"
  ;; Network A: module "bar" — initial value
  (define net-a0 (make-prop-network))
  (define-values (net-a1 bar-cell) (net-new-cell net-a0 (cons 'Int 42) merge-replace))

  ;; Network B: shadow + downstream
  (define net-b0 (make-prop-network))
  (define bar-val (net-cell-read net-a1 bar-cell))
  (define-values (net-b1 shadow) (net-new-cell net-b0 bar-val merge-replace))
  (define-values (net-b2 result) (net-new-cell net-b1 'infra-bot merge-replace))

  (define (extract-value-prop net)
    (define shadow-val (net-cell-read net shadow))
    (if (and shadow-val (pair? shadow-val))
        (net-cell-write net result (cdr shadow-val))
        net))

  (define-values (net-b3 _pid)
    (net-add-propagator net-b2 (list shadow) (list result) extract-value-prop))
  (define net-b4 (run-to-quiescence net-b3))
  (check-equal? (net-cell-read net-b4 result) 42)

  ;; Simulate "bar reloads": A gets new value, we update B's shadow
  (define net-a2 (net-cell-write net-a1 bar-cell (cons 'Int 99)))
  (define new-bar-val (net-cell-read net-a2 bar-cell))

  ;; Write new value to B's shadow cell, re-propagate
  (define net-b5 (net-cell-write net-b4 shadow new-bar-val))
  (define net-b6 (run-to-quiescence net-b5))

  ;; Result should reflect the new value
  (check-equal? (net-cell-read net-b6 result) 99))

(test-case "shadow-cell: multiple shadows from different modules"
  ;; Module A: definition x = 10
  (define net-a0 (make-prop-network))
  (define-values (net-a1 x-cell) (net-new-cell net-a0 (cons 'Int 10) merge-replace))

  ;; Module C: definition y = 20
  (define net-c0 (make-prop-network))
  (define-values (net-c1 y-cell) (net-new-cell net-c0 (cons 'Int 20) merge-replace))

  ;; File B: shadows both, combines them
  (define net-b0 (make-prop-network))
  (define-values (net-b1 shadow-x) (net-new-cell net-b0 (net-cell-read net-a1 x-cell) merge-replace))
  (define-values (net-b2 shadow-y) (net-new-cell net-b1 (net-cell-read net-c1 y-cell) merge-replace))
  (define-values (net-b3 sum-cell) (net-new-cell net-b2 'infra-bot merge-replace))

  ;; Propagator: sum = x + y (extract cdr from both shadows)
  (define (sum-prop net)
    (define xv (net-cell-read net shadow-x))
    (define yv (net-cell-read net shadow-y))
    (if (and xv (pair? xv) yv (pair? yv))
        (net-cell-write net sum-cell (+ (cdr xv) (cdr yv)))
        net))

  (define-values (net-b4 _pid)
    (net-add-propagator net-b3 (list shadow-x shadow-y) (list sum-cell) sum-prop))
  (define net-b5 (run-to-quiescence net-b4))

  (check-equal? (net-cell-read net-b5 sum-cell) 30))

(test-case "module-network-ref: full lifecycle (create, populate, finalize)"
  ;; Simulate loading a module: create network, add defs, mark loaded
  (define mnr0 (make-module-network))
  (check-equal? (module-network-status mnr0) mod-loading)

  ;; Add definitions
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'add (cons 'fn 'add-impl)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'zero (cons 'Nat 'zero-val)))
  (define-values (mnr3 _c3) (module-network-add-definition mnr2 'suc (cons 'fn 'suc-impl)))

  ;; Mark loaded
  (define mnr4 (module-network-set-status mnr3 mod-loaded))
  (check-equal? (module-network-status mnr4) mod-loaded)

  ;; All definitions accessible
  (check-equal? (module-network-lookup mnr4 'add) (cons 'fn 'add-impl))
  (check-equal? (module-network-lookup mnr4 'zero) (cons 'Nat 'zero-val))
  (check-equal? (module-network-lookup mnr4 'suc) (cons 'fn 'suc-impl))

  ;; Materialize matches
  (define snap (module-network-materialize mnr4))
  (check-equal? (hash-count snap) 3))

;; ============================================================
;; Phase 4: Cross-module dependency edges
;; ============================================================

(test-case "module-network-ref: dep-edges populated from cross-module deps"
  ;; Simulate what driver.rkt does: accumulate cross-module deps during
  ;; module loading, then populate dep-edges in the module-network-ref.
  (define mnr0 (make-module-network))
  (define-values (mnr1 _c1) (module-network-add-definition mnr0 'add (cons 'fn 'add-impl)))
  (define-values (mnr2 _c2) (module-network-add-definition mnr1 'double (cons 'fn 'double-impl)))
  (define mnr3 (module-network-set-status mnr2 mod-loaded))

  ;; Simulate cross-module deps: double depends on add (same-file)
  ;; and on nat::zero (from module)
  (define deps '((double add same-file)
                 (double nat::zero module)))

  ;; Build dep-edge hash (same logic as driver.rkt)
  (define dep-edge-hash
    (for/fold ([h (hasheq)])
              ([dep (in-list deps)])
      (define dst-name (car dep))
      (define src-name (cadr dep))
      (define source (caddr dep))
      (hash-set h dst-name
                (cons (cons src-name source)
                      (hash-ref h dst-name '())))))

  ;; Attach to module-network-ref
  (define mnr4 (struct-copy module-network-ref mnr3
                  [dep-edges dep-edge-hash]))

  ;; Verify dep-edges
  (check-equal? (hash-count (module-network-ref-dep-edges mnr4)) 1)
  (define double-deps (hash-ref (module-network-ref-dep-edges mnr4) 'double '()))
  (check-equal? (length double-deps) 2)
  ;; Both edges present (order depends on fold)
  (check-not-false (member (cons 'add 'same-file) double-deps))
  (check-not-false (member (cons 'nat::zero 'module) double-deps))

  ;; 'add has no recorded deps
  (check-equal? (hash-ref (module-network-ref-dep-edges mnr4) 'add '()) '()))
