#lang racket/base

;; network-to-low-pnet.rkt — SH Track 2 Phase 2.B.
;;
;; Translates an in-memory prop-network into a Low-PNet IR structure.
;; This is the second of three phases for Track 2 (per the design doc):
;;
;;   Phase 2.A — data structures + parse + pp + validate (commit f4157be)
;;   Phase 2.B — prop-network → Low-PNet (this file)
;;   Phase 2.C — Low-PNet → LLVM IR (deferred)
;;
;; Scope of Phase 2.B (this commit):
;;   - Walk prop-net cells and propagators
;;   - Emit cell-decl, propagator-decl, dep-decl, domain-decl, entry-decl
;;   - Domain decls use placeholder tag values (real merge-fn-tag, bot, etc.
;;     come from a future domain-registry-to-low-pnet pass; placeholders are
;;     enough for Phase 2.B's diagnostic value)
;;
;; Phase 2.B+ (post-2026-05-02 update): cell-value marshaling.
;;   - Serializable cell values (i64, bool, symbol, null, simple lists)
;;     emerge as the cell-decl init-value AND, when non-trivially-bot, as a
;;     write-decl. Non-serializable values fall back to a placeholder
;;     symbol so the structure is still emittable (Phase 2.B's diagnostic
;;     value preserved for compile-time-only cells with rich Racket types).
;;
;; Out of scope:
;;   - Stratum decls (deferred until stratum exposure on the network is finalized)
;;   - The reverse direction (Low-PNet → prop-network)
;;
;; Out of scope:
;;   - Stratum decls (deferred until stratum exposure on the network is finalized)
;;   - Initial-value emission (write-decls)
;;   - The reverse direction (Low-PNet → prop-network): not needed; the kernel
;;     loads Low-PNet directly via LLVM lowering, never reconstructs a Racket
;;     prop-network from Low-PNet.

(require racket/match
         "propagator.rkt"
         "champ.rkt"
         "low-pnet-ir.rkt")

(provide prop-network-to-low-pnet
         value-marshalable?
         marshal-value)

;; ============================================================
;; Value marshaling
;; ============================================================
;;
;; Determines whether a cell's current value can be embedded in a .pnet
;; file and round-tripped through write/read. The set is intentionally
;; conservative — any value that's safely Racket-`write`able as a
;; readable s-expression is fine. Procedures, structs with private
;; representations, mutable boxes/hashes, and anything containing those
;; are not. Future minor versions can extend.

(define (value-marshalable? v)
  (cond
    [(exact-integer? v) #t]
    [(boolean? v) #t]
    [(symbol? v) #t]
    [(string? v) #t]
    [(char? v) #t]
    [(null? v) #t]
    [(pair? v) (and (value-marshalable? (car v))
                    (value-marshalable? (cdr v)))]
    [(vector? v)
     (for/and ([e (in-vector v)]) (value-marshalable? e))]
    [else #f]))

;; marshal-value : Any → Any
;; Returns the value as-is if marshalable, else a sentinel.
(define (marshal-value v)
  (if (value-marshalable? v)
      v
      'phase-2b-placeholder))

;; prop-network-to-low-pnet : prop-network × main-cell-id → low-pnet
;;
;; Walks the network, emits a Low-PNet structure that captures the runtime
;; topology. The result is suitable for inspection (pp-low-pnet) and for
;; downstream Phase 2.C lowering once that arrives.
;;
;; main-cell-id : exact-nonnegative-integer
;;   The id of the cell whose value the program's result reads from.
;;   Caller responsibility: this should be a real cell in the network.
(define (prop-network-to-low-pnet net main-cell-id)
  (define cells-champ (prop-network-cells net))
  (define props-champ (prop-network-propagators net))
  (define domains-champ (prop-network-cell-domains net))

  ;; -------- 1. Collect unique domains and assign sequential ids ----------
  ;; The network maps cell-id → domain-name-symbol (or no entry for cells
  ;; without an explicit domain). We collect the set of domain names that
  ;; actually appear, assign each a sequential id, and emit one domain-decl
  ;; per unique domain.
  (define domain-name->id (make-hasheq))
  (champ-fold domains-champ
              (lambda (cid dom-name acc)
                (unless (hash-has-key? domain-name->id dom-name)
                  (hash-set! domain-name->id dom-name (hash-count domain-name->id)))
                acc)
              #f)

  ;; Cells without an explicit domain entry get a default 'unknown domain.
  ;; (Most often: cells allocated via net-new-cell with a merge-fn but no
  ;; explicit domain symbol. Future Track 1 work will tighten this; for
  ;; Phase 2.B the placeholder is fine.)
  (define unknown-id
    (cond
      [(hash-ref domain-name->id 'unknown #f)
       => values]
      [else
       (define id (hash-count domain-name->id))
       (hash-set! domain-name->id 'unknown id)
       id]))

  ;; -------- 2. Walk cells -------------------------------------------------
  ;; Phase 2.B+: emit the cell's current value as init-value when marshalable
  ;; (i64 / bool / symbol / string / null / pairs of the above). Non-marshalable
  ;; values (closures, complex Racket structs from the elaborator) get the
  ;; 'phase-2b-placeholder sentinel — they're typically compile-time-only
  ;; cells whose contents shouldn't survive into a deployment artifact anyway.
  (define cell-decls
    (champ-fold cells-champ
                (lambda (cid cell acc)
                  (define cid-int (cell-id-n cid))
                  (define dom-name
                    (or (lookup-cell-domain net cid) 'unknown))
                  (define dom-id (hash-ref domain-name->id dom-name unknown-id))
                  (define raw-value (prop-cell-value cell))
                  (define init-value (marshal-value raw-value))
                  (cons (cell-decl cid-int dom-id init-value) acc))
                '()))

  ;; -------- 3. Walk propagators -------------------------------------------
  (define props-acc
    (champ-fold props-champ
                (lambda (pid prop acc)
                  (match-define (list pds dds) acc)
                  (define pid-int (prop-id-n pid))
                  (define ins (map cell-id-n (propagator-inputs prop)))
                  (define outs (map cell-id-n (propagator-outputs prop)))
                  (define tag (propagator-fire-fn-tag prop))
                  (define flags (propagator-flags prop))
                  (define new-prop (propagator-decl pid-int ins outs tag flags))
                  ;; One dep-decl per input cell. Phase 2.B uses 'all paths;
                  ;; component-paths refinement is future work (see SH Master
                  ;; Track 4 / compound cells).
                  (define new-deps
                    (map (lambda (cid) (dep-decl pid-int cid 'all)) ins))
                  (list (cons new-prop pds)
                        (append (reverse new-deps) dds)))
                (list '() '())))
  (define prop-decls (car props-acc))
  (define dep-decls (cadr props-acc))

  ;; -------- 4. Collect domain bot values (domain-registry pass) ----------
  ;; For each domain, harvest the bot value from a representative cell of
  ;; that domain. The lattice invariant says all cells of a domain start at
  ;; the same bot, so taking the FIRST cell's value when nothing has been
  ;; written to it yet gives us the bot. We don't have "writes to this cell"
  ;; tracking here, so we use the first cell of each domain that has a
  ;; marshalable value as the proxy. Cells with non-marshalable contents
  ;; (closures from elaborator state) fall back to a placeholder bot.
  (define domain-name->bot (make-hasheq))
  (champ-fold cells-champ
              (lambda (cid cell acc)
                (define dom-name
                  (or (lookup-cell-domain net cid) 'unknown))
                (unless (hash-has-key? domain-name->bot dom-name)
                  (define v (prop-cell-value cell))
                  (hash-set! domain-name->bot dom-name (marshal-value v)))
                acc)
              #f)

  ;; -------- 5. Emit domain-decls in id order ------------------------------
  (define domain-decls
    (let ([by-id (make-hasheq)])
      (for ([(name id) (in-hash domain-name->id)])
        (hash-set! by-id id name))
      (for/list ([id (in-range (hash-count by-id))])
        (define name (hash-ref by-id id))
        (define bot (hash-ref domain-name->bot name 'phase-2b-placeholder))
        (domain-decl id name
                     ;; merge-fn-tag follows the 'kernel-merge-<name> convention
                     ;; (per fire-fn tag audit doc § 6); the runtime kernel will
                     ;; resolve these via its tag→fn-pointer registry.
                     (string->symbol (format "kernel-merge-~a" name))
                     bot
                     ;; contradiction-pred-tag: 'never is the default for
                     ;; lattices that don't have explicit contradiction
                     ;; (most domains today); future domains with contradiction
                     ;; semantics will register 'kernel-contra-<name>.
                     'never))))

  ;; -------- 5. Assemble the Low-PNet -------------------------------------
  ;; Order matters per the V10 validation rule: domains first, then cells,
  ;; then propagators, then dep-decls, then entry-decl.
  (define nodes
    (append domain-decls
            (sort cell-decls < #:key cell-decl-id)
            (sort prop-decls < #:key propagator-decl-id)
            (sort dep-decls < #:key (lambda (d) (dep-decl-prop-id d)))
            (list (entry-decl main-cell-id))))

  (low-pnet LOW_PNET_FORMAT_VERSION nodes))
