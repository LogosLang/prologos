#lang racket/base

;;;
;;; PROLOGOS .PNET SERIALIZATION
;;; Serialize and deserialize module network state to/from disk.
;;;
;;; Track 10 Phase 1b: The highest-value mechanism — eliminates 20s cold-start
;;; by serializing elaboration results (cell values, registries, metadata)
;;; and deserializing on subsequent loads (~735ms).
;;;
;;; Mechanism: struct->vector + write/read + tag dispatch reconstruction.
;;; Handles: gensyms (symbol$$N tagging), foreign procs (dynamic-require),
;;; preparse expanders (dynamic-require).
;;;
;;; See: docs/tracking/2026-03-24_PM_TRACK10_DESIGN.md §2.7
;;;

(require racket/match
         racket/hash
         racket/file
         racket/path
         racket/string
         racket/list
         "prelude.rkt"
         "syntax.rkt"
         "namespace.rkt"
         "source-location.rkt"
         ;; Session type nodes. Added 2026-08-05 — the WHOLE family, not the
         ;; one that detonated. `sessions.rkt` depends only on
         ;; prelude/syntax/substitution, so there is no cycle.
         "sessions.rkt"
         (only-in "propagator.rkt" cell-id
                  prop-network prop-network? make-prop-network
                  prop-net-hot prop-net-warm prop-net-cold
                  prop-cell)
         (only-in "elab-network-types.rkt" elab-network elab-network? elab-cell-info contradiction-info)
         (only-in "macros.rkt" spec-entry preparse-macro ctor-meta
                  trait-meta trait-method impl-entry param-impl-entry
                  current-preparse-registry current-ctor-registry
                  current-type-meta
                  current-subtype-registry current-coercion-registry
                  current-capability-registry
                  current-trait-registry current-impl-registry
                  current-param-impl-registry
                  current-specialization-registry
                  current-bundle-registry bundle-entry
                  current-trait-laws current-property-store
                  current-functor-store
                  ;; #78 P2: the 7 registries that were never serialized
                  current-schema-registry schema-entry schema-field
                  current-selection-registry selection-entry
                  current-session-registry session-entry
                  current-strategy-registry strategy-entry
                  current-process-registry process-entry
                  current-user-operators op-info
                  current-user-precedence-groups prec-group)
         (only-in "global-env.rkt" current-defn-param-names)
         (only-in "multi-dispatch.rkt" current-multi-defn-registry)
         (only-in "foreign.rkt" parse-foreign-type make-marshaller-pair)
         ;; POL.10: reconstructive champ serialization (def binds reduced values,
         ;; so champ-bearing rows now reach module env-snapshots)
         (only-in "champ.rkt" champ-empty champ-insert champ-entries
                  champ-transient tchamp-freeze)
         ;; SolveCarrier: the PVec carrier a POL.10 `def` can bind (see the
         ;; rrb-sentinel arms). Leaf data module, cycle-free — same as champ.
         (only-in "rrb.rkt" rrb-to-list rrb-from-list rrb-transient trrb-freeze))

;; Lib dir for resolving relative .rkt paths in foreign function re-linking
(define pnet-lib-dir (simplify-path (build-path (syntax-source #'here) ".." "lib")))

;; Resolve a `foreign racket "…"` module-path string to a dynamic-require
;; spec. THE canonical resolver — used by BOTH resolution sites: fresh
;; elaboration (driver.rkt handle-foreign-decl) and the .pnet re-link below.
;; The two sites drifting apart is how the worktree defect stayed hidden.
;;
;; - "….rkt"      → file relative to the RUNNING compiler's source directory
;; - "prologos/X" → the RUNNING compiler's own X.rkt — NEVER the installed
;;   collection. The collection resolves to the MAIN checkout, so in a git
;;   worktree it instantiates a SECOND compiler (its own syntax.rkt struct
;;   identities) and IR passthrough values fail the foreign module's own
;;   predicates ("keyword-name: expected a Keyword value, got
;;   #(struct:expr-keyword …)"). Two-instance class, 3rd sighting 2026-07-26;
;;   cf. testing.md "relative path, never prologos/X". In the main checkout
;;   the rewrite resolves to the identical file — no behavior change there.
;; - anything else ("racket/base", "racket/math") → collection path, unchanged.
(define (foreign-module-path->require-spec module-path-str)
  (cond
    [(regexp-match? #rx"\\.rkt$" module-path-str)
     (simplify-path (build-path pnet-lib-dir ".." module-path-str))]
    [(regexp-match? #rx"^prologos/" module-path-str)
     (simplify-path
      (build-path pnet-lib-dir ".."
                  (string-append (substring module-path-str
                                            (string-length "prologos/"))
                                 ".rkt")))]
    [else (string->symbol module-path-str)]))

(provide serialize-module-state
         deserialize-module-state
         relink-foreign-marshallers!
         foreign-module-path->require-spec
         pnet-stale?
         reset-lib-source-staleness-cache!
         pnet-path-for-module
         ;; The format's shape, exported so a test can pin it — it was a bare
         ;; literal inside two functions that disagreed by construction (31 on
         ;; the write side, a `>= 14` minimum on the read side).
         PNET_VERSION
         PNET_SLOT_COUNT
         ;; For testing
         make-serializer
         deep-struct->serializable
         deep-serializable->struct
         make-tag-constructor-table)

;; ============================================================
;; .pnet format version
;; ============================================================

;; CIU T6 F1a.2 p1b: 1→2 in the SAME commit as the Open mint-flip — every cache
;; regenerates Open-free, so the :579 wildcard + the 9 Open-scrutinee arms are
;; dead code from here and no stale cache can re-inject the deleted-at-p2 tag
;; (the expr-p*-if-nar months-latent class, pipeline.md).
;; 2→3 at POL.10 (2026-07-24): env-snapshots may now carry whnf-reduced def
;; values (incl. champ-sentinels) — bump forces clean regeneration everywhere
;; so no pre-POL.10 reader ever meets the new shapes (the F1a.2 precedent).
;; 3→4 at GitHub #78 P2 (2026-07-27): TWO independent reasons.
;;   (a) FORMAT — 7 registry slots added (indices 24-30: schema, selection,
;;       session, strategy, process, user-operators, user-precedence-groups),
;;       which were never serialized at all, so a cache hit supplied them via
;;       neither parameter nor cell. That is what made a schema SEAL over a
;;       cached module fail as `imports: Error loading module <M>: Type
;;       mismatch` (#78 severity 3).
;;   (b) POISON INVALIDATION — pre-fix caches can contain a module that was
;;       elaborated while a dependency's registries were invisible, i.e. with
;;       constructor patterns silently degraded to catch-all variables. Those
;;       files are WRONG on disk and must not be read again. `infrastructure-
;;       stale?` cannot be relied on to sweep them: it requires
;;       compiled/driver_rkt.zo to EXIST (see below), so with no compiled dir it
;;       reports "not stale" and a poisoned cache stays live. The version gate
;;       is exact equality, so the bump is the only reliable sweep.
;;
;; v4 -> v5 (2026-07-27, the prelude-snapshot test migration): 34 test files moved
;; from reloading the prelude per test case to seeding from test-support.rkt's
;; once-per-subprocess snapshot. Existing local caches written under the old
;; per-test-fresh-registry regime do NOT survive that change — both the main
;; checkout and the worktree had a green suite before the migration and a failing
;; test-io-session-01.rkt after it, purely from a stale cache; deleting the cache
;; fixed both, and two consecutive runs then stayed green. `pnet-stale?` did not
;; catch it, and the cache is gitignored/local, so no one would pull a good one.
;; The version gate is exact equality, so the bump is the reliable sweep — same
;; reasoning as the v3 -> v4 bump for #78. Costs one ~3s regeneration per machine.
;; v5 -> v6 (CIU T6 P2.b slice 4): expr-get/expr-map-get gained the strictness
;; field — the on-disk vector width changed; exact-equality is the only
;; reliable sweep (a v5 cache's 2-element vectors would (apply ctor) at the
;; wrong arity, or worse, silently mismatch downstream).
;; v6 -> v7 (QTT P2, 2026-07-30): pattern matching is now multiplicity-checked.
;; This is a SEMANTIC-VALIDITY change to already-cached modules, the same class
;; as (b) POISON INVALIDATION above: every .pnet on disk was written while
;; `contains-unsupported-qtt?` returned #t for expr-reduce, i.e. while every
;; `match` body SKIPPED checkQ-top. On a cache hit the driver deserializes and
;; never elaborates, so the QTT gate does not run at all — a module that should
;; now fail keeps loading from cache, and the suite can be green on a warm tree
;; while a cold clone or CI hits the new errors. `pnet-stale?` /
;; `infrastructure-stale?` cannot sweep this class; exact equality can.
;; v7 -> v8 (QTT P5, 2026-07-30): `contains-unsupported-qtt?` is DELETED, so the
;; driver no longer skips multiplicity checking for defs containing Vec/Fin
;; constructors, their eliminators, or a foreign-fn value. Same SEMANTIC-VALIDITY
;; class as v6->v7 and as (b) POISON INVALIDATION above: on a cache HIT the driver
;; deserializes and never elaborates, so the QTT gate never runs — 24 of the 40
;; .pnet files on disk carry serialized expr-foreign-fn structs (including modules
;; with no foreign decl of their own, via env snapshots), every one written while
;; those bodies were QTT-SKIPPED. Without the bump a module that should newly fail
;; keeps loading from cache, and the suite is green on a warm tree while a cold
;; clone or CI hits the new errors. Exact equality is the only reliable sweep.
;; v8 -> v9 (SolveCarrier spin-out, 2026-07-31): `solve`/`explain` now return a
;; PVec, so the whnf-reduced value a POL.10 `def` binds is `(expr-rrb …)` rather
;; than a cons spine. That reaches env-snapshots exactly the way champ-bearing
;; rows did at v2->v3 — and hit the SAME defect for the same reason: an rrb-root's
;; `tail` is a RAW RACKET VECTOR, and `deep-s->v` has no `vector?` arm, so the
;; champ rows inside it fell through `[else v]` and were written out VERBATIM,
;; persisting their `equal-hash-code` values. Those are process-stable only —
;; precisely what the champ-sentinel arm exists to prevent. The rrb-sentinel arm
;; below closes it reconstructively (elements serialized, tree rebuilt at read).
;; The bump is what stops a v8 cache written under the broken path from being
;; read back with cross-process hashes baked in.
;; v9 -> v10 (2026-07-31): the FOUR remaining container wrappers gain sentinels —
;; `expr-hset` (Set) plus the three transient builders `expr-trrb` / `expr-tchamp`
;; / `expr-thset` (TVec/TMap/TSet). An audit of every wrapper struct holding a raw
;; persistent/transient structure found all four had NO sentinel and NO reg entry.
;; Details for the Set case (the others are identical in shape): It
;; wraps a CHAMP but is not the `expr-champ` struct, so it fell to the generic
;; struct walk and hit BOTH the hash-persistence defect the champ-sentinel arm
;; exists to prevent AND the unregistered-node defect (no reg entry either, so
;; the reader handed back a raw vector that PRINTS like the struct). Same
;; POISON-INVALIDATION reasoning as v3->v4 and v8->v9: any v9-or-earlier cache
;; holding a Set has cross-process hashes baked in, and exact equality is the
;; only reliable sweep.
(define PNET_VERSION 10)

;; How many slots the positional payload has, for THIS version.
;;
;; `serialize-module-state` and `deserialize-module-state` exchange a bare
;; positional list and driver.rkt's cache-hit arm is its only consumer, so
;; nothing named the slots or checked the count. Appending is safe; INSERTING a
;; slot anywhere before the tail shifts every later position — and because
;; almost every slot is a hasheq, the types are indistinguishable. The failure
;; mode is silent wrong registries, which is the #78 severity class exactly.
;;
;; Checked on BOTH sides. The writer asserts before it writes, so a mis-ordered
;; build fails at the machine that made it rather than at whoever reads the
;; cache; the reader requires exact equality, so a short or long payload is a
;; cache miss instead of a shifted read.
;;
;; Bump this with PNET_VERSION whenever the payload gains or loses a slot.
(define PNET_SLOT_COUNT 31)

;; ============================================================
;; Serialization: struct->vector + gensym tagging + foreign-proc
;; ============================================================

;; Create a serializer with its own gensym table (per-module)
(define (make-serializer)
  (define gensym-table (make-hash))   ;; gensym → unique-id
  (define gensym-counter 0)

  (define (serialize-sym s)
    (cond
      [(symbol-interned? s) s]
      [else
       (define uid
         (hash-ref! gensym-table s
           (lambda ()
             (set! gensym-counter (add1 gensym-counter))
             gensym-counter)))
       (string->symbol (format "~a$$~a" (symbol->string s) uid))]))

  (define has-foreign-procs? (box #f))  ;; Track if any procedures found

  (define (deep-s->v v)
    (cond
      [(procedure? v)
       ;; Procedures can't be serialized. Record for tracking.
       ;; Foreign functions with source-module are re-linked via dynamic-require.
       ;; Other procedures (preparse expanders, marshallers) get stubs.
       (set-box! has-foreign-procs? #t)
       (define name (or (object-name v) 'anonymous))
       (list 'foreign-proc name)]
      [(symbol? v) (serialize-sym v)]
      ;; Track 10 Phase 3c: prop-network and elab-network contain internal
      ;; CHAMP nodes that aren't exported and can't be properly reconstructed.
      ;; Replace with sentinels — these are runtime values, not module state.
      [(prop-network? v) '(runtime-prop-network)]
      [(elab-network? v) '(runtime-elab-network)]
      ;; POL.10 (2026-07-24, landed second pass): `def` binds WHNF-reduced
      ;; values, so champ-bearing solution rows CAN reach module env-snapshots. CHAMP internal
      ;; nodes are implementation-private (the same class as the network
      ;; sentinels above), so serialize RECONSTRUCTIVELY as the entries list;
      ;; the reader rebuilds via champ-insert with hashes RECOMPUTED —
      ;; equal-hash-code is process-stable only and must never be persisted.
      [(expr-champ? v)
       (list 'champ-sentinel
             (for/list ([kv (in-list (champ-entries (expr-champ-racket-champ v)))])
               (cons (deep-s->v (car kv)) (deep-s->v (cdr kv)))))]
      ;; A SET value. `expr-hset` wraps a CHAMP (keys with a `#t` sentinel value),
      ;; but the `expr-champ?` arm above does not see through the wrapper, so
      ;; before this arm an hset fell to the generic `[(struct? v) …]` walk and
      ;; hit BOTH failure modes at once:
      ;;   (1) HASH PERSISTENCE — the walk descends into champ-root/champ-node,
      ;;       whose entry vectors carry `equal-hash-code` values. Those are
      ;;       process-stable ONLY; a cache written by one process and read by
      ;;       another has stale hashes baked in, so `champ-lookup` — which
      ;;       navigates BY the stored hash — silently misses. Exactly what the
      ;;       champ-sentinel arm exists to prevent, one wrapper up.
      ;;   (2) NO RECONSTRUCTION — `expr-hset` is not in the reg0!/reg1!/regN!
      ;;       tables either, so the reader's unknown-tag fallback returned the
      ;;       raw VECTOR. That is the pipeline.md failure verbatim, down to the
      ;;       symptom: the value PRINTS as `#(struct:expr-hset …)` and then
      ;;       fails the first struct match to touch it, arbitrarily far away.
      ;; Verified by probe, not inferred: round-tripping an `expr-hset` returned
      ;; a vector, and `expr-hset-racket-champ` raised a contract violation on it.
      ;; The sentinel fixes both — reconstructive, hashes RECOMPUTED at read.
      [(expr-hset? v)
       (list 'hset-sentinel
             (for/list ([kv (in-list (champ-entries (expr-hset-racket-champ v)))])
               (cons (deep-s->v (car kv)) (deep-s->v (cdr kv)))))]
      ;; SolveCarrier (2026-07-31): the same argument one container up. Since
      ;; solve/explain return a PVec, a POL.10 `def` can bind an rrb of solution
      ;; rows into a module env-snapshot. rrb-root's `tail` is a RAW RACKET VECTOR
      ;; and deep-s->v has no `vector?` arm, so a structural walk leaks its
      ;; contents through `[else v]` UNCHANGED — champ rows with their
      ;; equal-hash-codes baked in, which must never be persisted. Serialize
      ;; RECONSTRUCTIVELY as the element list (each element still routed through
      ;; deep-s->v, so nested rows get the champ-sentinel); the reader rebuilds
      ;; the tree with rrb-from-list.
      [(expr-rrb? v)
       (list 'rrb-sentinel
             (for/list ([e (in-list (rrb-to-list (expr-rrb-racket-rrb v)))])
               (deep-s->v e)))]
      ;; THE TRANSIENT BUILDERS (TVec / TMap / TSet). Same two defects as their
      ;; persistent siblings — raw struct walk, no reconstruction — and reachable
      ;; the same way: `def ts := (transient s)` binds a TSet, and POL.10 puts the
      ;; reduced value in the module env-snapshot (probe-verified: `ts : [TSet Int]
      ;; defined.`). A `tchamp-root`'s entries are `(cons hash value)` pairs, so
      ;; the hash-persistence half applies here too.
      ;;
      ;; Serialize through the FREEZE — both `trrb-freeze` and `tchamp-freeze` are
      ;; NON-DESTRUCTIVE (they build a fresh persistent structure and leave the
      ;; transient untouched; verified by reading them), so this is a read, not a
      ;; consume. The reader re-transients, which is also the semantically right
      ;; answer: a MUTABLE builder must never be shared across module loads, so
      ;; each load getting its own is a feature rather than a compromise.
      [(expr-trrb? v)
       (list 'trrb-sentinel
             (for/list ([e (in-list (rrb-to-list (trrb-freeze (expr-trrb-racket-trrb v))))])
               (deep-s->v e)))]
      [(expr-tchamp? v)
       (list 'tchamp-sentinel
             (for/list ([kv (in-list (champ-entries (tchamp-freeze (expr-tchamp-racket-tchamp v))))])
               (cons (deep-s->v (car kv)) (deep-s->v (cdr kv)))))]
      [(expr-thset? v)
       (list 'thset-sentinel
             (for/list ([kv (in-list (champ-entries (tchamp-freeze (expr-thset-racket-tchamp v))))])
               (cons (deep-s->v (car kv)) (deep-s->v (cdr kv)))))]
      [(struct? v)
       (for/vector ([e (in-vector (struct->vector v))]) (deep-s->v e))]
      [(pair? v)
       (cons (deep-s->v (car v)) (deep-s->v (cdr v)))]
      [(list? v) (map deep-s->v v)]
      [(hash? v)
       (for/hasheq ([(k val) (in-hash v)])
         (values (if (symbol? k) (serialize-sym k) k)
                 (deep-s->v val)))]
      [(void? v) '(void-sentinel)]
      [(box? v) (list 'box-sentinel (deep-s->v (unbox v)))]
      [else v]))  ;; numbers, strings, booleans, keywords: pass-through

  (values deep-s->v has-foreign-procs?))

(define (deep-struct->serializable v)
  (define-values (f _) (make-serializer))
  (f v))

;; ============================================================
;; Deserialization: read + tag dispatch reconstruction
;; ============================================================

;; ============================================================
;; Dynamic tag→constructor dispatch
;; ============================================================
;; Instead of maintaining a manual table of 326+ struct types,
;; use Racket's struct-type introspection to reconstruct structs
;; dynamically. This eliminates the pipeline-exhaustiveness problem.

;; Registry: populated at require-time from syntax.rkt's provide.
;; Key = tag symbol (e.g., 'struct:expr-Pi), Value = constructor procedure.
(define tag-table (make-hash))

(define (make-tag-constructor-table) tag-table)

;; Register a struct type for deserialization.
;; Called at module load time for each struct we need to reconstruct.
(define (register-pnet-struct! tag-sym constructor)
  (hash-set! tag-table tag-sym constructor))

;; Auto-register: given a struct predicate and a sample instance,
;; extract the tag from struct->vector and register the constructor.
(define-syntax-rule (auto-register-struct! ctor pred sample-args ...)
  (let ([inst (ctor sample-args ...)])
    (define tag (vector-ref (struct->vector inst) 0))
    (register-pnet-struct! tag ctor)))

;; Helper: register a tag→constructor pair by making a dummy instance.
;; Zero-arg constructors get a thunk wrapper.
(define-syntax-rule (reg0! ctor)
  (let ([tag (vector-ref (struct->vector (ctor)) 0)])
    (hash-set! tag-table tag (lambda () (ctor)))))

(define-syntax-rule (reg1! ctor dummy)
  (let ([tag (vector-ref (struct->vector (ctor dummy)) 0)])
    (hash-set! tag-table tag ctor)))

(define-syntax-rule (reg2! ctor d1 d2)
  (let ([tag (vector-ref (struct->vector (ctor d1 d2)) 0)])
    (hash-set! tag-table tag ctor)))

(define-syntax-rule (reg3! ctor d1 d2 d3)
  (let ([tag (vector-ref (struct->vector (ctor d1 d2 d3)) 0)])
    (hash-set! tag-table tag ctor)))

(define-syntax-rule (regN! ctor args ...)
  (let ([tag (vector-ref (struct->vector (ctor args ...)) 0)])
    (hash-set! tag-table tag ctor)))

;; Dynamic constructor cache: maps struct-name-symbol → constructor.
;; Built at module load time from all required modules.
;; Used as fallback when a tag isn't in the static tag table.
(define dynamic-ctor-cache (make-hash))

(define-syntax-rule (cache-ctor! name ctor)
  (hash-set! dynamic-ctor-cache 'name ctor))

;; Phase 2e: Register all struct types dynamically.
;; Instead of hand-coding 149 entries, auto-register by creating a dummy
;; instance of each exported struct and extracting its tag.
;; Unknown tags gracefully degrade to raw vectors.
(define (register-all-pnet-structs!)
  ;; --- Zero-arg (atoms) ---
  (reg0! expr-zero) (reg0! expr-refl) (reg0! expr-Nat) (reg0! expr-Bool)
  (reg0! expr-true) (reg0! expr-false) (reg0! expr-Unit) (reg0! expr-unit)
  (reg0! expr-Nil) (reg0! expr-nil) (reg0! expr-hole) (reg0! expr-error)
  ;; --- session types (2026-08-05) ---
  ;; UNREGISTERED until now, and the failure was the one `pipeline.md` warns
  ;; about: an unregistered node does NOT error at cache read — the unknown-tag
  ;; fallback returns a raw VECTOR that PRINTS like the struct, and it fails the
  ;; first predicate to touch it, arbitrarily far away. Here that was
  ;; `sess-mu-body: contract violation; expected sess-mu?; given
  ;; '#(struct:sess-mu …)` — a value that looks exactly like what it is being
  ;; told it is not. The quote is the tell.
  ;;
  ;; `lib/prologos/core/io-protocols.prologos` declares FOUR recursive session
  ;; protocols, so this broke the STANDARD LIBRARY for anyone with a warm
  ;; `.pnet` cache, while passing for anyone whose cache was cold. Found by a
  ;; cache-state change, not by a code change — which is why it had survived.
  ;;
  ;; The whole family is registered, not just `sess-mu`: registering only the
  ;; node that detonated is the "registration-by-detonation" pattern this file
  ;; has already been swept for once this session.
  (reg0! sess-end)
  (reg1! sess-mu (sess-end))
  (reg1! sess-svar 0)
  (reg1! sess-choice '())
  (reg1! sess-offer '())
  (reg2! sess-send (expr-Nat) (sess-end))
  (reg2! sess-recv (expr-Nat) (sess-end))
  (reg2! sess-dsend (expr-Nat) (sess-end))
  (reg2! sess-drecv (expr-Nat) (sess-end))
  (reg2! sess-async-send (expr-Nat) (sess-end))
  (reg2! sess-async-recv (expr-Nat) (sess-end))
  (reg0! sess-branch-error)
  (reg0! expr-Int) (reg0! expr-Rat) (reg0! expr-Char) (reg0! expr-String)
  (reg0! expr-Keyword) (reg0! lzero)

  ;; --- One-arg ---
  (reg1! expr-bvar 0) (reg1! expr-fvar 'x) (reg1! expr-suc (expr-zero))
  (reg1! expr-nat-val 0) (reg1! expr-fst (expr-unit)) (reg1! expr-snd (expr-unit))
  (reg1! expr-Type (lzero)) (reg1! expr-typed-hole (expr-Nat))
  (reg1! expr-int 0) (reg1! expr-rat 1/2)
  (reg1! expr-char #\a) (reg1! expr-string "")
  (reg1! expr-keyword 'k) (reg1! expr-PVec (expr-Nat))
  (reg1! expr-tycon 'T)
  (reg1! expr-panic "err") (reg1! lsuc (lzero)) (reg1! level-meta 'l)
  (reg1! cell-id 0)

  ;; --- Two-arg ---
  (reg2! expr-app (expr-fvar 'f) (expr-fvar 'x))
  (reg2! expr-pair (expr-unit) (expr-unit))
  (reg2! expr-ann (expr-unit) (expr-Unit))
  (reg2! expr-Sigma (expr-Nat) (expr-Nat))
  (reg2! expr-meta 'test-meta #f)
  (regN! expr-num-lit 1/2 #f 'fraction #f)  ;; N4: transient numeric literal (rarely serialized); N6b: +origin
  (reg2! expr-Map (expr-Nat) (expr-Nat))
  ;; CIU T6 F1: the structural-row type + its field struct. BOTH must register
  ;; (F2 vector-impostor detonates on a MISSING registration under a stale .pnet cache).
  (reg2! record-field (expr-Nat) 'present)
  (reg3! expr-Record 'keyword '() 'closed)
  ;; CIU T6 F1b.5-s2: the validate tabulation node — SAME-COMMIT registration
  ;; (the vector-impostor rule). Payload = symbols/booleans/sexps/exprs only
  ;; (preds are expr-lams, NEVER Racket closures — those serialize to stubs).
  (regN! expr-validate 'S #f '() (expr-unit) '())
  ;; CIU T6 D4.P3a: the select-block node — SAME-COMMIT registration (the
  ;; vector-impostor rule). Payload = subject expr + branches (nested lists of
  ;; symbols — plain sexp data). NO PNET bump: the tag table is symbol-keyed,
  ;; so a new struct is purely additive (§8 R6 as corrected 2026-07-29).
  (regN! expr-select (expr-unit) '() #f)
  ;; CIU T6 D4.P4b-ii-1: THE SELECTOR CARRIER gained its `sort` field, so it
  ;; MOVES here from auto-cache! (ruling C4). auto-cache! wraps its body in an
  ;; exception-swallowing handler — a stale-arity call there voids the
  ;; registration with ZERO signal and the node returns from a `.pnet` as a
  ;; raw vector (pipeline.md § New AST Node item 6, the "misleading failure"
  ;; class). regN! errors LOUDLY on arity drift instead. Payload = branches
  ;; (nested lists of bare symbols + tagged sexps) + a sort SYMBOL — plain
  ;; sexp data. NO PNET bump needed: `infrastructure-stale?` invalidates every
  ;; `.pnet` on any syntax.rkt edit (the rebuilt driver `.zo`'s mtime), which
  ;; is what actually makes "no bump" true here — §8 R6's symbol-keyed/additive
  ;; argument covers struct ADDITION only, and this is an ARITY CHANGE.
  (regN! expr-path '() 'path)
  (reg0! expr-Path)
  (reg1! expr-Set (expr-Nat))
  (reg2! expr-union (expr-Nat) (expr-Int))
  ;; CIU T6 P2.b slice 4: both projection nodes gained the strictness field
  ;; (arity 3). expr-map-get MOVES here from auto-cache! deliberately —
  ;; auto-cache!'s body is wrapped in an exception-swallowing handler, so a
  ;; stale-arity call there VOIDS silently and the node vanishes from the
  ;; cache with zero signal (audit G4). The regN! route errors LOUDLY at
  ;; module load, which is what an arity change must do.
  (regN! expr-get (expr-unit) (expr-keyword 'k) #f)
  (regN! expr-map-get (expr-unit) (expr-keyword 'k) #f)
  ;; lmax is a smart function, not a struct — no registration needed

  ;; --- Three-arg ---
  (reg3! expr-Pi 'mw (expr-Nat) (expr-Nat))
  (reg3! expr-lam 'mw (expr-Nat) (expr-unit))
  (reg3! expr-reduce (expr-unit) '() #t)
  (reg3! expr-reduce-arm 'ctor 0 (expr-unit))
  (reg3! expr-Eq (expr-Nat) (expr-zero) (expr-zero))

  ;; QTT P5 residual 2: the Vec/Fin family — 9 nodes, ZERO registrations until
  ;; 2026-08-03. Harmless only while no cached module contains one, and P5 is
  ;; exactly what changed that: it made Vec/Fin defs pass the QTT gate for the
  ;; first time, so they can now reach a library body and be cached.
  ;;
  ;; The failure this prevents does not look like a missing registration. An
  ;; unregistered tag does not error at cache read — the reader's unknown-tag
  ;; fallback returns a raw VECTOR, which then fails the first struct `match`
  ;; to touch it, arbitrarily far away, with an error that PRINTS like the real
  ;; struct (`#(struct:expr-vcons …)`). See `pipeline.md` item 6.
  (reg2! expr-Vec (expr-Nat) (expr-zero))
  (reg1! expr-Fin (expr-zero))
  (reg1! expr-vnil (expr-Nat))
  (regN! expr-vcons (expr-Nat) (expr-zero) (expr-unit) (expr-unit))
  (reg1! expr-fzero (expr-zero))
  (reg2! expr-fsuc (expr-zero) (expr-unit))
  (reg3! expr-vhead (expr-Nat) (expr-zero) (expr-unit))
  (reg3! expr-vtail (expr-Nat) (expr-zero) (expr-unit))
  (regN! expr-vindex (expr-Nat) (expr-zero) (expr-unit) (expr-unit))

  ;; --- Four-arg ---
  (regN! expr-natrec (expr-Nat) (expr-unit) (expr-unit) (expr-zero))
  (regN! expr-boolrec (expr-Bool) (expr-unit) (expr-unit) (expr-true))

  ;; --- Five-arg ---
  (regN! expr-J (expr-Nat) (expr-unit) (expr-zero) (expr-zero) (expr-refl))

  ;; --- Network types (0-arg) ---
  (reg0! expr-net-type) (reg0! expr-cell-id-type)

  ;; --- Network constructors ---
  (reg3! expr-net-new-cell (expr-unit) (expr-unit) (expr-unit))
  (regN! expr-net-new-cell-widen (expr-unit) (expr-unit) (expr-unit) (expr-unit) (expr-unit))

  ;; --- Numeric conversions ---
  (reg1! expr-from-nat (expr-zero))
  (reg1! expr-from-int (expr-zero))

  ;; --- spec-entry (8 fields: type-datums docstring multi? srcloc where-constraints implicit-binders rest-type metadata) ---
  (regN! spec-entry '() #f #f #f '() '() #f #f)

  ;; --- GitHub #78 P2: the registry value structs for the 7 registries that
  ;; were never serialized. REQUIRED, not optional: an unregistered tag does NOT
  ;; error at cache read — the reader's unknown-tag fallback silently returns a
  ;; raw VECTOR, which then fails the first struct `match` to touch it,
  ;; arbitrarily far from here, with an error that PRINTS like the real struct.
  ;; (pipeline.md § "New AST Node" item 6 documents this failure mode.)
  ;; NESTED value structs count too — registering the entry alone is NOT enough.
  ;; schema-entry's `fields` holds schema-field structs; leaving that one out
  ;; produced exactly the documented symptom: `schema-field-check-pred:
  ;; contract violation … given: '#(struct:schema-field name String #f #f)` —
  ;; a raw vector that PRINTS like the struct it impersonates.
  (regN! schema-field    #f #f #f #f)           ;; keyword type-datum default-val check-pred
  (regN! schema-entry    #f '() #f #f)          ;; name fields closed? srcloc
  (regN! selection-entry #f #f '() '() '() #f #f)  ;; name schema-name requires-paths provides-paths includes-names srcloc stub?
  (regN! session-entry   #f #f #f)              ;; name session-type srcloc
  (regN! strategy-entry  #f '() #f)             ;; name properties srcloc
  (regN! process-entry   #f #f #f '() #f)       ;; name session-type proc-body caps srcloc
  (regN! op-info         #f #f #f #f 0 0 #f)    ;; symbol fn-name group assoc left-bp right-bp swap?
  (regN! prec-group      #f #f '())             ;; name assoc tighter-than

  ;; --- Special: expr-foreign-fn with dynamic re-linking ---
  ;; Override the auto-registered constructor with one that re-links the proc
  ;; from source-module + racket-name via dynamic-require.
  (hash-set! tag-table 'struct:expr-foreign-fn
    (lambda (name proc arity args marshal-in marshal-out source-module racket-name)
      ;; Re-link the proc if source-module is available
      (define real-proc
        (if (and source-module racket-name
                 (not (eq? source-module #f))
                 (not (eq? racket-name #f)))
            (with-handlers ([exn? (lambda (_) proc)])  ;; fallback to stub
              (dynamic-require (foreign-module-path->require-spec source-module)
                               racket-name))
            proc))  ;; no source-module → keep the stub
      ;; Check if the re-linked proc has fewer args than arity.
      ;; This happens when :requires (Cap) adds capability token args.
      ;; Wrap the raw proc to accept the extra capability args and drop them.
      (define wrapped-proc
        (if (and (procedure? real-proc) (number? arity))
            (let ([raw-arity (procedure-arity real-proc)])
              (if (and (integer? raw-arity)
                       (integer? arity)
                       (> arity raw-arity))
                  ;; Capability-wrapped: extra args are cap tokens, drop them
                  (let ([n-caps (- arity raw-arity)])
                    (case n-caps
                      [(1) (lambda (cap . rest) (apply real-proc rest))]
                      [(2) (lambda (c1 c2 . rest) (apply real-proc rest))]
                      [else (lambda args (apply real-proc (drop args n-caps)))]))
                  real-proc))
            real-proc))
      (expr-foreign-fn name wrapped-proc arity args marshal-in marshal-out
                       source-module racket-name)))

  ;; --- Additional types from frequency analysis ---
  ;; Posit types
  (when (with-handlers ([exn? (lambda (_) #f)]) (expr-Posit8) #t)
    (reg0! expr-Posit8) (reg0! expr-Posit16) (reg0! expr-Posit32) (reg0! expr-Posit64)
    (reg0! expr-Float32) (reg0! expr-Float64))

  ;; Int/Rat operations (appear in foreign function types)
  (when (with-handlers ([exn? (lambda (_) #f)]) (expr-int-add (expr-zero) (expr-zero)) #t)
    (reg2! expr-int-add (expr-zero) (expr-zero))
    (reg2! expr-int-sub (expr-zero) (expr-zero))
    (reg2! expr-int-lt (expr-zero) (expr-zero))
    (reg2! expr-int-eq (expr-zero) (expr-zero)))

  ;; Spec entries (appear in module-info specs)
  (when (with-handlers ([exn? (lambda (_) #f)]) (spec-entry '() (expr-Nat) '() '() #f #f) #t)
    (regN! spec-entry '() (expr-Nat) '() '() #f #f))

  ;; Source locations (appear in definition-locations)
  (when (with-handlers ([exn? (lambda (_) #f)]) (srcloc "" 0 0 0) #t)
    (regN! srcloc "" 0 0 0))

  ;; ns-context
  (regN! ns-context 'test (hasheq) (hasheq) '() '() '())

  ;; preparse-macro (user-defined macros from defmacro — stored in preparse registry)
  (reg3! preparse-macro 'test '() '())

  ;; trait-meta + trait-method + impl-entry (stored in trait/impl registries)
  (regN! trait-meta 'T '() '() (hasheq))
  (reg2! trait-method 'test '())
  (reg3! impl-entry 'T '() 'dict)

  ;; bundle-entry (stored in bundle-registry)
  (regN! bundle-entry 'test '() '() (hasheq))

  ;; param-impl-entry (stored in param-impl-registry)
  (regN! param-impl-entry 'T '() '() 'dict '())

  ;; ctor-meta (stored in ctor-registry)
  (when (with-handlers ([exn? (lambda (_) #f)]) (ctor-meta 'T '() 0 #f #f #f) #t)
    (regN! ctor-meta 'T '() 0 #f #f #f))

  ;; Phase 2e: populate dynamic-ctor-cache with ALL constructors from syntax.rkt.
  ;; This is the fallback for tags not in the static table above.
  ;; Uses struct->vector on dummy instances to discover tags, then maps tag-name → ctor.
  (define (auto-cache! ctor . args)
    (with-handlers ([exn? (lambda (_) (void))])
      (define inst (apply ctor args))
      (when (struct? inst)
        (define tag (vector-ref (struct->vector inst) 0))
        (define name (string->symbol (substring (symbol->string tag) 7)))
        (hash-set! dynamic-ctor-cache name ctor))))

  (define d (expr-zero))  ;; universal dummy
  ;; Posit types + ops (4 widths)
  (auto-cache! expr-Posit8) (auto-cache! expr-Posit16) (auto-cache! expr-Posit32) (auto-cache! expr-Posit64)
  (auto-cache! expr-posit8 0) (auto-cache! expr-posit16 0) (auto-cache! expr-posit32 0) (auto-cache! expr-posit64 0)
  ;; Float (Numerics N3)
  (auto-cache! expr-Float32) (auto-cache! expr-Float64)
  (auto-cache! expr-float32 0) (auto-cache! expr-float64 0)
  (for ([ops (list (list expr-p8-add expr-p8-sub expr-p8-mul expr-p8-div expr-p8-eq expr-p8-lt expr-p8-le expr-p8-neg expr-p8-abs expr-p8-from-int expr-p8-from-rat expr-p8-to-rat)
                   (list expr-p16-add expr-p16-sub expr-p16-mul expr-p16-div expr-p16-eq expr-p16-lt expr-p16-le expr-p16-neg expr-p16-abs expr-p16-from-int expr-p16-from-rat expr-p16-to-rat)
                   (list expr-p32-add expr-p32-sub expr-p32-mul expr-p32-div expr-p32-eq expr-p32-lt expr-p32-le expr-p32-neg expr-p32-abs expr-p32-from-int expr-p32-from-rat expr-p32-to-rat)
                   (list expr-p64-add expr-p64-sub expr-p64-mul expr-p64-div expr-p64-eq expr-p64-lt expr-p64-le expr-p64-neg expr-p64-abs expr-p64-from-int expr-p64-from-rat expr-p64-to-rat)
                   ;; Float ops (Numerics N3b)
                   (list expr-f32-add expr-f32-sub expr-f32-mul expr-f32-div expr-f32-eq expr-f32-lt expr-f32-le expr-f32-neg expr-f32-abs expr-f32-sqrt)
                   (list expr-f64-add expr-f64-sub expr-f64-mul expr-f64-div expr-f64-eq expr-f64-lt expr-f64-le expr-f64-neg expr-f64-abs expr-f64-sqrt))])
    (for ([op ops])
      (auto-cache! op d) (auto-cache! op d d)))
  ;; Cross-width Float conversions (Numerics N3e-rest) — unary
  (for ([op (list expr-float-finite expr-float-to-rat expr-float-to-int expr-float-to-float32)])
    (auto-cache! op d))
  ;; Posit if-nar eliminators (Numerics Q11) — arity 4: (tp nar-case val-case v).
  ;; First library use is conversions.prologos; without this registration the
  ;; .pnet reader's unknown-tag fallback returns a raw VECTOR that then fails
  ;; every struct match downstream (subst is the first to throw).
  (for ([op (list expr-p8-if-nar expr-p16-if-nar expr-p32-if-nar expr-p64-if-nar)])
    (auto-cache! op d d d d))
  ;; Generic conversion dispatch nodes (Numerics N3e Path B) — arity 2:
  ;; (target-type arg). Same landmine class as if-nar above: first INVOKED
  ;; library use is the Q11 Posit->Float instances.
  (for ([op (list expr-generic-from-rat expr-generic-from-int)])
    (auto-cache! op d d))
  ;; …and the TWELVE SIBLINGS of those two, unregistered until 2026-08-03.
  ;; This is `pipeline.md`'s "a fix applied to one member of a family but not
  ;; its siblings" verbatim: from-rat/from-int were registered because they
  ;; detonated (the Q11 Posit→Float instances), and the arithmetic and
  ;; comparison nodes right beside them were left. Same landmine, same family,
  ;; and these are the ones a user actually writes — every `+` `-` `*` `/` `<`
  ;; in a generic context elaborates to one.
  (for ([op (list expr-generic-add expr-generic-sub expr-generic-mul expr-generic-div
                  expr-generic-lt expr-generic-le expr-generic-gt expr-generic-ge
                  expr-generic-eq expr-generic-mod)])
    (auto-cache! op d d))
  (for ([op (list expr-generic-negate expr-generic-abs)])
    (auto-cache! op d))
  ;; Posit sqrt + from-nat: the Float lists below carry `sqrt`, the Posit lists
  ;; above do not, and neither carries `from-nat`. Same sibling gap.
  (for ([op (list expr-p8-sqrt expr-p16-sqrt expr-p32-sqrt expr-p64-sqrt
                  expr-p8-from-nat expr-p16-from-nat expr-p32-from-nat expr-p64-from-nat)])
    (auto-cache! op d))
  ;; Int ops
  (for ([op (list expr-int-add expr-int-sub expr-int-mul expr-int-div expr-int-lt expr-int-eq
                  ;; `le` and `mod` were missing while `lt` and `eq` were present.
                  expr-int-le expr-int-mod)])
    (auto-cache! op d d))
  (for ([op (list expr-int-neg expr-int-abs)])
    (auto-cache! op d))
  (for ([op (list expr-rat-add expr-rat-sub expr-rat-mul expr-rat-div expr-rat-lt expr-rat-le expr-rat-eq)])
    (auto-cache! op d d))
  (for ([op (list expr-rat-neg expr-rat-abs)])
    (auto-cache! op d))
  ;; Rat projections (Numerics N6d-ii: first cached-lib-body use via to-int/to-rat
  ;; Rat leg [int/ [rat-numer x] [rat-denom x]]; unregistered => raw-vector impostor
  ;; landmine, pipeline.md item 6).
  (for ([op (list expr-rat-numer expr-rat-denom)])
    (auto-cache! op d))
  ;; Collection ops
  (auto-cache! expr-set-empty d) (auto-cache! expr-set-insert d d) (auto-cache! expr-set-member d d)
  (auto-cache! expr-set-delete d d) (auto-cache! expr-set-union d d) (auto-cache! expr-set-diff d d)
  (auto-cache! expr-set-fold d d d) (auto-cache! expr-set-to-list d)
  (auto-cache! expr-map-empty d d) (auto-cache! expr-map-assoc d d d)
  (auto-cache! expr-map-dissoc d d)  ;; expr-map-get: explicit regN! above (P2.b slice 4)
  (auto-cache! expr-map-has-key d d) (auto-cache! expr-map-keys d) (auto-cache! expr-map-vals d)
  (auto-cache! expr-map-fold-entries d d d) (auto-cache! expr-map-filter-entries d d)
  (auto-cache! expr-pvec-empty d) (auto-cache! expr-pvec-push d d)
  (auto-cache! expr-pvec-literal (list d))  ;; CIU T6 F1a-col: literal-extent node (elems list)
  (auto-cache! expr-list-literal (list d) d)  ;; CIU T6 F1a-col-2: elems list + chain
  (auto-cache! expr-map-literal (list d) (list d) d)  ;; CIU T6 F1a.2 p1b-pre: keys + vals + chain
  (auto-cache! expr-pvec-nth d d) (auto-cache! expr-pvec-update d d d)
  (auto-cache! expr-pvec-length d) (auto-cache! expr-pvec-fold d d d)
  (auto-cache! expr-pvec-map d d) (auto-cache! expr-pvec-from-list d) (auto-cache! expr-pvec-to-list d)
  ;; Path algebra + first-class path values (pipeline.md item 6 — were UNREGISTERED →
  ;; raw-vector impostor crash when a cached library body carries them; CIU Track 6 F2)
  (auto-cache! expr-get-in d d) (auto-cache! expr-update-in d d d)
  ;; expr-path / expr-Path: MOVED to the explicit regN!/reg0! route above
  ;; (D4.P4b-ii-1, ruling C4) — auto-cache!'s body swallows exceptions, so the
  ;; arity change this slice makes would have VOIDED the registration silently
  ;; and returned a raw-vector impostor from any cached body carrying a
  ;; selector. Same move, same reason, as expr-map-get at P2.b slice 4.
  ;; Other
  (auto-cache! expr-from-int d d) (auto-cache! expr-from-nat d d)
  (auto-cache! expr-Symbol)
  (auto-cache! expr-nil-check d)
  ;; macros.rkt structs
  (auto-cache! ctor-meta 'x 'y (list) #f 0)
  ;; Network types
  (with-handlers ([exn? void])
    (auto-cache! expr-net-type d)
    (auto-cache! expr-net-new-cell d d)
    (auto-cache! expr-net-new-cell-widen d d d))
  ;; expr-cell-id-type
  (with-handlers ([exn? void])
    (auto-cache! expr-cell-id-type d d))

  ;; Track 10 Phase 3c: prop-network + CHAMP structs (for foreign functions that return networks)
  (with-handlers ([exn? void])
    (auto-cache! prop-network d d)
    (auto-cache! prop-net-hot d d)
    (auto-cache! prop-net-warm d d)
    (auto-cache! prop-net-cold d d)
    (auto-cache! elab-network d d)
    (auto-cache! elab-cell-info d d)
    (auto-cache! contradiction-info d d)
    (auto-cache! prop-cell d d))
  ;; tms-cell-value auto-cache RETIRED 2026-04-22 (PPN 4C 1A-iii-a-wide Step 1
  ;; S1.c): TMS mechanism retired. Old caches with tms-cell-value entries will
  ;; fail to deserialize and invalidate naturally on first load post-retirement.

  (void))

;; Run registration at module load time
(register-all-pnet-structs!)

;; ONE rebuild for every champ-backed sentinel (champ / hset / tchamp / thset).
;; Hashes are RECOMPUTED here and never read from disk — that is the whole point
;; of the sentinel family: `equal-hash-code` is process-stable only, and
;; `champ-lookup` navigates BY the stored hash, so a persisted one silently
;; misses in another process. Four arms, one derivation, no drift.
(define (rebuild-champ-from-entries entries)
  (for/fold ([c champ-empty]) ([kv (in-list entries)])
    (define k (deep-serializable->struct (car kv)))
    (define val (deep-serializable->struct (cdr kv)))
    (champ-insert c (equal-hash-code k) k val)))

(define (deep-serializable->struct v)
  (cond
    ;; Tagged vector: reconstruct struct
    [(and (vector? v) (> (vector-length v) 0)
          (symbol? (vector-ref v 0))
          (let ([s (symbol->string (vector-ref v 0))])
            (and (>= (string-length s) 7)
                 (string=? (substring s 0 7) "struct:"))))
     (define tag (vector-ref v 0))
     (define fields
       (for/list ([i (in-range 1 (vector-length v))])
         (deep-serializable->struct (vector-ref v i))))
     (define ctor (hash-ref tag-table tag #f))
     (cond
       [ctor (apply ctor fields)]
       [else
        ;; Unknown tag — try dynamic constructor lookup from cache.
        (define ctor-name (string->symbol (substring (symbol->string tag) 7)))
        (define dynamic-ctor (hash-ref dynamic-ctor-cache ctor-name #f))
        (cond
          [dynamic-ctor
           (hash-set! tag-table tag dynamic-ctor)  ;; cache for future
           (apply dynamic-ctor fields)]
          [else v])])]  ;; truly unknown — return as vector
    ;; Sentinel markers
    [(and (list? v) (= (length v) 1) (eq? (car v) 'void-sentinel))
     (void)]
    ;; Track 10 Phase 3c: runtime network sentinels → fresh networks
    [(and (list? v) (= (length v) 1) (eq? (car v) 'runtime-prop-network))
     (make-prop-network)]
    [(and (list? v) (= (length v) 1) (eq? (car v) 'runtime-elab-network))
     (make-prop-network)]  ;; elab-network → fresh prop-network (no elab state needed)
    [(and (list? v) (= (length v) 2) (eq? (car v) 'box-sentinel))
     (box (deep-serializable->struct (cadr v)))]
    ;; POL.10: reconstruct an expr-champ from its serialized entries list —
    ;; hashes recomputed at read (never persisted; see the serializer arm).
    [(and (list? v) (= (length v) 2) (eq? (car v) 'champ-sentinel))
     (expr-champ (rebuild-champ-from-entries (cadr v)))]
    ;; SolveCarrier: rebuild the PVec carrier from its elements (see the
    ;; serializer arm — the tree shape is derived, never persisted).
    [(and (list? v) (= (length v) 2) (eq? (car v) 'rrb-sentinel))
     (expr-rrb (rrb-from-list (map deep-serializable->struct (cadr v))))]
    ;; …and the Set, same argument: hashes RECOMPUTED at read, never persisted.
    [(and (list? v) (= (length v) 2) (eq? (car v) 'hset-sentinel))
     (expr-hset (rebuild-champ-from-entries (cadr v)))]
    ;; The transient builders: rebuild the persistent form (hashes recomputed),
    ;; then re-transient. Each module load gets its OWN builder.
    [(and (list? v) (= (length v) 2) (eq? (car v) 'trrb-sentinel))
     (expr-trrb (rrb-transient (rrb-from-list (map deep-serializable->struct (cadr v)))))]
    [(and (list? v) (= (length v) 2) (eq? (car v) 'tchamp-sentinel))
     (expr-tchamp (champ-transient (rebuild-champ-from-entries (cadr v))))]
    [(and (list? v) (= (length v) 2) (eq? (car v) 'thset-sentinel))
     (expr-thset (champ-transient (rebuild-champ-from-entries (cadr v))))]
    [(and (list? v) (= (length v) 2) (eq? (car v) 'foreign-proc))
     ;; Re-link foreign procedure. For most procs, the expr-foreign-fn struct
     ;; that contains this proc also has source-module + racket-name fields.
     ;; The struct reconstruction will call dynamic-require using those fields.
     ;; For standalone procs (marshallers, expanders), return a stub.
     (lambda args (error 'foreign-proc "deserialized stub for ~a — needs re-link" (cadr v)))]
    ;; Recursive cases
    [(pair? v)
     (cons (deep-serializable->struct (car v))
           (deep-serializable->struct (cdr v)))]
    [(list? v) (map deep-serializable->struct v)]
    [(hash? v)
     (for/hasheq ([(k val) (in-hash v)])
       (values k (deep-serializable->struct val)))]
    [else v]))

;; ============================================================
;; File operations
;; ============================================================

;; Track 10 Phase 2e: absolute path, relative to THIS module's location.
;; Prevents working-directory sensitivity (batch workers run from project root).
(define pnet-cache-dir
  (simplify-path (build-path (path-only (syntax-source #'here)) "data" "cache" "pnet")))

(define (pnet-path-for-module ns-sym)
  (define ns-str (symbol->string ns-sym))
  (define path-str (string-replace ns-str "::" "/"))
  (build-path pnet-cache-dir (string-append path-str ".pnet")))

(define (source-hash-for-module ns-sym source-path)
  ;; Simple hash: file modification time + size
  ;; Full implementation would hash file contents + transitive deps
  (if (and source-path (file-exists? source-path))
      (let ([stat (file-or-directory-modify-seconds source-path)])
        (format "~a:~a" source-path stat))
      "unknown"))

;; Track 10B: infrastructure .zo timestamp. If driver_rkt.zo is newer than
;; any .pnet file, the Racket infrastructure changed and all .pnet files
;; are stale (elaboration output may differ). Simple timestamp comparison.
(define driver-zo-path
  (simplify-path (build-path (path-only (syntax-source #'here)) "compiled" "driver_rkt.zo")))

(define (infrastructure-stale? pnet-path)
  (and (file-exists? driver-zo-path)
       (file-exists? pnet-path)
       (> (file-or-directory-modify-seconds driver-zo-path)
          (file-or-directory-modify-seconds pnet-path))))

;; ============================================================
;; Transitive-source staleness (2026-08-03)
;; ============================================================
;;
;; `source-hash-for-module` compares ONE file's mtime — the module's own — so a
;; module whose DEPENDENCY changed is reported fresh, and its cached env
;; snapshot still carries the dependency's OLD contributions. That is not a
;; freshness nicety; it is a silent WRONG ANSWER. Verified before fixing:
;;
;;   base:  defn basev [x] [int+ x 1]
;;   mid:   imports base;  defn midv [x] [basev x]
;;   user:  imports mid;   def r := [midv 10]        => 11
;;
;; edit `base` to `[int+ x 100]`, re-run the USER file only:
;;   cache ON, mid.pnet present  -> 11   ← the pre-edit answer
;;   cache OFF                   -> 110
;;   cache ON, mid.pnet deleted  -> 110
;;
;; This is the SAME SHAPE as the driver.zo check directly above, applied to the
;; second input class: a `.pnet` is a function of the Racket compiler AND of
;; every `.prologos` source that fed it. The zo check already answers "the
;; compiler changed"; this answers "a library source changed".
;;
;; DELIBERATELY BLUNT — newest mtime across ALL library sources, not a
;; per-module dependency set. The precise alternative is to record each
;; module's dep list in its `.pnet` and walk it, which is better and which the
;; dep-edges field once existed for; it was RETIRED as write-only (PPN 4C
;; Addendum Phase 4B.1), so the precise version means re-adding it with a
;; consumer. Choosing correct-and-slightly-blunt over correct-with-bookkeeping
;; follows the driver.zo precedent rather than inventing a policy. The cost is
;; paid ONLY when a `.prologos` under a lib path is edited, and is one cache
;; regeneration sweep (~3-4 s for the ~55 prelude modules, per the v4->v5 note).
;;
;; MEMOIZED per process, KEYED BY THE LIB PATHS. The scan is one
;; `directory-list` walk and a load of N modules would otherwise repeat it N
;; times — but `current-lib-paths` genuinely varies within a process (every
;; test that builds a temp lib rebinds it), so a single unkeyed box answers for
;; the WRONG directory set. That is not theoretical: the first cut used one box
;; and turned `test-pnet-registry-restore`'s intended cache HITS into misses,
;; failing two assertions written precisely to catch "a MISS produces the
;; correct answer and proves nothing".
(define lib-sources-newest-cache (make-hash))

(define (newest-lib-source-seconds)
  (define key (map (lambda (p) (if (path? p) (path->string p) (format "~a" p)))
                   (current-lib-paths)))
  (cond
    [(hash-ref lib-sources-newest-cache key #f) => values]
    [else
     (define newest
       (for*/fold ([acc 0])
                  ([root (in-list (current-lib-paths))]
                   #:when (and (path-string? root) (directory-exists? root)))
         (let walk ([dir root] [acc acc])
           (for/fold ([acc acc])
                     ([p (in-list (with-handlers ([exn:fail? (lambda (_) '())])
                                    (directory-list dir #:build? #t)))])
             (cond
               [(directory-exists? p) (walk p acc)]
               [(regexp-match? #rx"[.]prologos$" (path->string p))
                (max acc (with-handlers ([exn:fail? (lambda (_) 0)])
                           (file-or-directory-modify-seconds p)))]
               [else acc])))))
     (hash-set! lib-sources-newest-cache key newest)
     newest]))

;; Exported so a test can force a re-scan after writing a source file; also the
;; honest escape hatch for a long-lived process that DOES edit lib sources.
(define (reset-lib-source-staleness-cache!)
  (hash-clear! lib-sources-newest-cache))

(define (lib-sources-stale? pnet-path)
  (and (file-exists? pnet-path)
       (> (newest-lib-source-seconds)
          (file-or-directory-modify-seconds pnet-path))))

(define (pnet-stale? ns-sym source-path)
  (define pnet-path (pnet-path-for-module ns-sym))
  (or (not (file-exists? pnet-path))
      ;; Track 10B: check infrastructure staleness (Racket code changed)
      (infrastructure-stale? pnet-path)
      ;; …and library-source staleness (a `.prologos` this module may depend on
      ;; changed). Without this a dependency edit returns the PRE-EDIT answer.
      (lib-sources-stale? pnet-path)
      (let ([cached-data (with-handlers ([exn? (lambda (_) #f)])
                           (call-with-input-file pnet-path read))])
        (or (not cached-data)
            (not (list? cached-data))
            (not (= (car cached-data) PNET_VERSION))
            (not (equal? (cadr cached-data)
                         (source-hash-for-module ns-sym source-path)))))))

(define (serialize-module-state ns-sym source-path module-info)
  (define-values (serialize! has-foreign?) (make-serializer))
  (define env (module-info-env-snapshot module-info))
  (define specs (module-info-specs module-info))
  (define locs (module-info-definition-locations module-info))

  (define s-env (serialize! env))
  (define s-specs (serialize! specs))
  (define s-locs (serialize! locs))

  ;; Phase 2b: serialize all 7 registries alongside env/specs/locs.
  ;; These are the module's accumulated contributions (including transitive deps).
  ;; Read from current parameters (in scope when called from load-module).
  (define s-preparse-reg (serialize! (current-preparse-registry)))
  (define s-ctor-reg     (serialize! (current-ctor-registry)))
  (define s-type-meta    (serialize! (current-type-meta)))
  (define s-multi-defn   (serialize! (current-multi-defn-registry)))
  (define s-subtype-reg  (serialize! (current-subtype-registry)))
  (define s-coercion-reg (serialize! (current-coercion-registry)))
  (define s-capability-reg (serialize! (current-capability-registry)))
  ;; Phase 2e: ALSO serialize trait + impl + param-impl registries (indices 14-16)
  (define s-trait-reg     (serialize! (current-trait-registry)))
  (define s-impl-reg      (serialize! (current-impl-registry)))
  (define s-param-impl-reg (serialize! (current-param-impl-registry)))
  (define s-specialization-reg (serialize! (current-specialization-registry)))
  (define s-tycon-arity (serialize! (current-tycon-arity-extension)))
  (define s-bundle-reg (serialize! (current-bundle-registry)))
  (define s-defn-params (serialize! (current-defn-param-names)))
  (define s-trait-laws (serialize! (current-trait-laws)))
  (define s-property (serialize! (current-property-store)))
  (define s-functor (serialize! (current-functor-store)))
  ;; #78 P2: the 7 formerly-unserialized registries. Like every registry above,
  ;; these read the PARAMETER, which load-module parameterizes — so what is
  ;; captured is the MODULE-SCOPED view (this module's contributions plus its
  ;; dependencies'), not the process-global accumulation. Reading the cells
  ;; here instead would serialize every other module's entries into this
  ;; module's cache file and make .pnet content load-order dependent.
  (define s-schema     (serialize! (current-schema-registry)))
  (define s-selection  (serialize! (current-selection-registry)))
  (define s-session    (serialize! (current-session-registry)))
  (define s-strategy   (serialize! (current-strategy-registry)))
  (define s-process    (serialize! (current-process-registry)))
  (define s-user-ops   (serialize! (current-user-operators)))
  (define s-user-precs (serialize! (current-user-precedence-groups)))

  (let ()
     (define hash-val (source-hash-for-module ns-sym source-path))
     (define pnet-data
       (list PNET_VERSION               ;; 0: version
             hash-val                    ;; 1: source hash
             s-env                       ;; 2: env-snapshot
             s-specs                     ;; 3: specs
             s-locs                      ;; 4: definition-locations
             (module-info-exports module-info)  ;; 5: exports
             (symbol->string ns-sym)     ;; 6: namespace
             ;; Phase 2b: 7 registries
             s-preparse-reg              ;; 7
             s-ctor-reg                  ;; 8
             s-type-meta                 ;; 9
             s-multi-defn                ;; 10
             s-subtype-reg               ;; 11
             s-coercion-reg              ;; 12
             s-capability-reg            ;; 13
             ;; Phase 2e: trait + impl registries
             s-trait-reg                ;; 14
             s-impl-reg                 ;; 15
             s-param-impl-reg           ;; 16
             s-specialization-reg      ;; 17
             s-tycon-arity            ;; 18
             s-bundle-reg            ;; 19
             s-defn-params          ;; 20
             s-trait-laws           ;; 21
             s-property             ;; 22
             s-functor              ;; 23
             ;; #78 P2 (v4): the 7 formerly-unserialized registries
             s-schema               ;; 24
             s-selection            ;; 25
             s-session              ;; 26
             s-strategy             ;; 27
             s-process              ;; 28
             s-user-ops             ;; 29
             s-user-precs           ;; 30
             ))
     ;; The count is part of the format, so a mismatch here is a bug in THIS
     ;; function, caught at write time rather than becoming a shifted read.
     (unless (= (length pnet-data) PNET_SLOT_COUNT)
       (error 'serialize-module-state
              "payload has ~a slots, PNET_SLOT_COUNT is ~a — a slot was added or removed without bumping the constant (and PNET_VERSION)"
              (length pnet-data) PNET_SLOT_COUNT))
     (define pnet-path (pnet-path-for-module ns-sym))
     (make-directory* (path-only pnet-path))
     ;; Atomic write: write to temp, then rename
     (define tmp-path (make-temporary-file "pnet-~a" #f (path-only pnet-path)))
     (call-with-output-file tmp-path
       (lambda (out) (write pnet-data out))
       #:exists 'replace)
     (rename-file-or-directory tmp-path pnet-path #t)
     pnet-path))

(define (deserialize-module-state ns-sym source-path)
  (define pnet-path (pnet-path-for-module ns-sym))
  (and (file-exists? pnet-path)
       (let ([raw (with-handlers ([exn? (lambda (_) #f)])
                    (call-with-input-file pnet-path read))])
         (and raw
              (list? raw)
              (= (car raw) PNET_VERSION)
              (equal? (cadr raw) (source-hash-for-module ns-sym source-path))
              ;; Valid — reconstruct.
              ;; EXACT length, not a minimum. The version gate above already
              ;; requires an exact match, so a payload of this version always
              ;; has every slot; a `>=` here let a short or mis-ordered file
              ;; through to a shifted read instead of failing as a cache miss.
              (and (= (length raw) PNET_SLOT_COUNT)
                   (let ([s-env   (list-ref raw 2)]
                         [s-specs (list-ref raw 3)]
                         [s-locs  (list-ref raw 4)]
                         [exports (list-ref raw 5)]
                         [s-preparse (list-ref raw 7)]
                         [s-ctor    (list-ref raw 8)]
                         [s-tmeta   (list-ref raw 9)]
                         [s-multi   (list-ref raw 10)]
                         [s-sub     (list-ref raw 11)]
                         [s-coerce  (list-ref raw 12)]
                         [s-cap     (list-ref raw 13)])
                     ;; Phase 2e: also extract trait + impl registries if present
                     (define s-trait (list-ref raw 14))
                     (define s-impl  (list-ref raw 15))
                     (define s-pimpl (list-ref raw 16))
                     (define s-spec-reg (list-ref raw 17))
                     (define s-tycon-a  (list-ref raw 18))
                     (define s-bundle  (list-ref raw 19))
                     (define s-dparam (list-ref raw 20))
                     (define s-tlaws  (list-ref raw 21))
                     (define s-props  (list-ref raw 22))
                     (define s-funcs  (list-ref raw 23))
                     ;; #78 P2 (v4): indices 24-30.
                     (define s-schema    (list-ref raw 24))
                     (define s-selection (list-ref raw 25))
                     (define s-session   (list-ref raw 26))
                     (define s-strategy  (list-ref raw 27))
                     (define s-process   (list-ref raw 28))
                     (define s-userops   (list-ref raw 29))
                     (define s-userprecs (list-ref raw 30))
                     (list (deep-serializable->struct s-env)
                           (deep-serializable->struct s-specs)
                           (deep-serializable->struct s-locs)
                           exports
                           ;; 7 original registries
                           (deep-serializable->struct s-preparse)
                           (deep-serializable->struct s-ctor)
                           (deep-serializable->struct s-tmeta)
                           (deep-serializable->struct s-multi)
                           (deep-serializable->struct s-sub)
                           (deep-serializable->struct s-coerce)
                           (deep-serializable->struct s-cap)
                           ;; The "or empty if old .pnet format" fallbacks that
                           ;; used to guard these are gone with the length
                           ;; guards: an exact-length payload of this version
                           ;; always has every slot, so the fallbacks were
                           ;; unreachable — a second mechanism standing in front
                           ;; of the version gate and hiding what it does.
                           (deep-serializable->struct s-trait)
                           (deep-serializable->struct s-impl)
                           (deep-serializable->struct s-pimpl)
                           (deep-serializable->struct s-spec-reg)
                           (deep-serializable->struct s-tycon-a)
                           (deep-serializable->struct s-bundle)
                           (deep-serializable->struct s-dparam)
                           (deep-serializable->struct s-tlaws)
                           (deep-serializable->struct s-props)
                           (deep-serializable->struct s-funcs)
                           ;; #78 P2 (v4) — returned positions 21-27.
                           (deep-serializable->struct s-schema)
                           (deep-serializable->struct s-selection)
                           (deep-serializable->struct s-session)
                           (deep-serializable->struct s-strategy)
                           (deep-serializable->struct s-process)
                           (deep-serializable->struct s-userops)
                           (deep-serializable->struct s-userprecs)
                           )))))))

;; ============================================================
;; Post-deserialization: re-link foreign function marshallers
;; ============================================================
;; After deserializing an env-snapshot, walk it and fix any expr-foreign-fn
;; whose marshal-in/marshal-out are stubs. Re-derive from the paired type.
(define (relink-foreign-marshallers! env-hash)
  (for/hasheq ([(name entry) (in-hash env-hash)])
    (values name (relink-entry entry))))

(define (relink-entry entry)
  (cond
    ;; Entry is (type . body) where body is the foreign-fn OR (type . (body ...))
    [(and (pair? entry) (expr-foreign-fn? (cdr entry)))
     ;; Direct pair: (type . foreign-fn)
     (define type-expr (car entry))
     (define ff (cdr entry))
     (relink-ff type-expr ff entry)]
    [(and (pair? entry) (pair? (cdr entry)) (expr-foreign-fn? (cadr entry)))
     ;; List form: (type foreign-fn ...)
     (define type-expr (car entry))
     (define ff (cadr entry))
     (define relinked (relink-ff type-expr ff entry))
     (if (eq? relinked entry)
         entry
         (cons type-expr (cons (cdr relinked) (cddr entry))))]
    [else entry]))

(define (relink-ff type-expr ff fallback)
  (define mi (expr-foreign-fn-marshal-in ff))
  ;; Check if marshallers are stubs
  (define needs-relink?
    (and (list? mi) (not (null? mi))
         (procedure? (car mi))
         (let ([name (object-name (car mi))])
           (or (not name)
               (regexp-match? #rx"pnet-serialize" (format "~a" name))))))
  (if needs-relink?
      (with-handlers ([exn? (lambda (_) fallback)])
        (define parsed (parse-foreign-type type-expr))
        (define-values (new-mi new-mo) (make-marshaller-pair parsed))
        (define new-ff
          (expr-foreign-fn
           (expr-foreign-fn-name ff)
           (expr-foreign-fn-proc ff)
           (expr-foreign-fn-arity ff)
           (expr-foreign-fn-args ff)
           new-mi new-mo
           (expr-foreign-fn-source-module ff)
           (expr-foreign-fn-racket-name ff)))
        (cons type-expr new-ff))
      fallback))
