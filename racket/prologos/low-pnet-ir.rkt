#lang racket/base

;; low-pnet-ir.rkt — Low-PNet IR Phase 2.A: data structures + parse + pp + validate.
;;
;; Per docs/tracking/2026-05-02_LOW_PNET_IR_TRACK2.md, Low-PNet is the
;; explicit lowering layer between propagator network and LLVM IR. This
;; module implements the data model: 8 node kinds, sexp-form parser,
;; pretty-printer, and basic well-formedness validator.
;;
;; Phase 2.A scope: data shape only. No translation passes (.pnet → Low-PNet
;; or Low-PNet → LLVM) — those are Phases 2.B and 2.C respectively.

(require racket/match
         racket/list
         racket/format)

(provide
 ;; Top-level program structure
 (struct-out low-pnet)

 ;; Node kinds
 (struct-out cell-decl)
 (struct-out propagator-decl)
 (struct-out domain-decl)
 (struct-out write-decl)
 (struct-out dep-decl)
 (struct-out stratum-decl)
 (struct-out entry-decl)
 (struct-out iter-block-decl)
 (struct-out meta-decl)

 ;; Errors
 (struct-out low-pnet-parse-error)
 (struct-out low-pnet-validate-error)

 ;; API
 parse-low-pnet
 pp-low-pnet
 validate-low-pnet

 ;; Constants
 LOW_PNET_FORMAT_VERSION)

;; ============================================================
;; Format version
;; ============================================================
;;
;; Mirrors the .pnet format-2 wrapper (commit 65312be): a (major minor) pair.
;; Major bump = breaking; minor bump = additive. Phase 2.A starts at 1.0.
;;
;; Version history:
;;   1.0 — initial Phase 2.A IR (8 node kinds, no mode tag on write-decl)
;;   1.1 — kernel-pocket-universes Phase 3 Day 8: write-decl gains optional
;;         mode tag (`'merge` default, `'reset` for non-merging replacement
;;         writes that map to prologos_cell_reset). Back-compat: 3-arg
;;         (write-decl cid value tag) parses as (write-decl cid value tag 'merge).

(define LOW_PNET_FORMAT_VERSION '(1 1))

;; ============================================================
;; Node kinds (per design doc § 3)
;; ============================================================

;; cell-decl   : (cell-decl id domain-id init-value)
;;   id          : exact-nonnegative-integer
;;   domain-id   : exact-nonnegative-integer (references a domain-decl)
;;   init-value  : Any (the cell's initial lattice value)
(struct cell-decl (id domain-id init-value) #:transparent)

;; propagator-decl : (propagator-decl id input-cells output-cells fire-fn-tag flags)
;;   id           : exact-nonnegative-integer
;;   input-cells  : (Listof cell-decl-id)
;;   output-cells : (Listof cell-decl-id)
;;   fire-fn-tag  : symbol — resolved at LLVM lowering against runtime kernel
;;                  or per-program .o (see design doc § 8.1)
;;   flags        : exact-nonnegative-integer (scheduler hints)
(struct propagator-decl (id input-cells output-cells fire-fn-tag flags) #:transparent)

;; domain-decl : (domain-decl id name merge-fn-tag bot contradiction-pred-tag)
;;   id                    : exact-nonnegative-integer
;;   name                  : symbol (human-readable; debug)
;;   merge-fn-tag          : symbol
;;   bot                   : Any (lattice bottom value)
;;   contradiction-pred-tag : symbol (use 'never if not applicable)
(struct domain-decl (id name merge-fn-tag bot contradiction-pred-tag) #:transparent)

;; write-decl : (write-decl cell-id value tag mode)
;;   cell-id : exact-nonnegative-integer (references a cell-decl)
;;   value   : Any
;;   tag     : exact-nonnegative-integer (worldview bitmask; 0 = default)
;;   mode    : 'merge | 'reset
;;             - 'merge (default): apply the cell's domain merge function and
;;               schedule subscribers if the value changes. Maps to
;;               prologos_cell_write at LLVM lowering.
;;             - 'reset: privileged non-merging replacement; bypasses merge,
;;               does NOT enqueue subscribers (caller is responsible for
;;               re-enqueuing). Maps to prologos_cell_reset at LLVM lowering.
;;               Used for substrate iteration (state-cell advance), NAF, and
;;               other non-monotone operations. Rev 2.1 of
;;               docs/tracking/2026-05-02_KERNEL_POCKET_UNIVERSES.md § 5.5.
;;
;; Back-compat: V1.0 IR (3-arg sexp form) parses as mode='merge.
(struct write-decl (cell-id value tag mode) #:transparent)

;; dep-decl : (dep-decl prop-id cell-id paths)
;;   prop-id : exact-nonnegative-integer (references a propagator-decl)
;;   cell-id : exact-nonnegative-integer (references a cell-decl)
;;   paths   : 'all | (Listof path) — component paths or 'all
(struct dep-decl (prop-id cell-id paths) #:transparent)

;; stratum-decl : (stratum-decl id name handler-tag)
;;   id          : exact-nonnegative-integer
;;   name        : symbol
;;   handler-tag : symbol
(struct stratum-decl (id name handler-tag) #:transparent)

;; entry-decl : (entry-decl main-cell-id)
;;   main-cell-id : exact-nonnegative-integer
(struct entry-decl (main-cell-id) #:transparent)

;; iter-block-decl (Sprint G, 2026-05-02): declares an iteration loop in
;; the generated @main. The LLVM lowering wraps the program's
;; run_to_quiescence + cell_read sequence in a loop:
;;
;;   loop:
;;     run_to_quiescence
;;     cond_val = cell_read(cond-cell)
;;     if halt-when=#t and cond_val != 0: break
;;     if halt-when=#f and cond_val == 0: break
;;     for each (state, next) in zip(state-cells, next-cells):
;;       cell_write(state, cell_read(next))
;;     goto loop
;;   <after loop: read entry-decl's result cell>
;;
;; This realizes "iteration as its own stratum" (per CALM): the body's
;; S0 (one iteration's run_to_quiescence) is fully monotone; the
;; non-monotone state advance lives in the loop control flow.
;;
;;   state-cells : (Listof cell-id)  — the recurrence's state binders
;;   next-cells  : (Listof cell-id)  — parallel: step expressions' result cells
;;   cond-cell   : cell-id           — Bool cell controlling iteration
;;   halt-when   : Bool              — #t halts when cond=1; #f halts when cond=0
;;
;; Length(state-cells) = Length(next-cells) (one next-cell per state slot).
(struct iter-block-decl (state-cells next-cells cond-cell halt-when) #:transparent)

;; meta-decl : (meta-decl key value)
;;   key   : symbol
;;   value : Any
(struct meta-decl (key value) #:transparent)

;; Top-level: a Low-PNet program.
;; version : (list major minor)
;; nodes   : (Listof <any decl>)
(struct low-pnet (version nodes) #:transparent)

;; ============================================================
;; Errors
;; ============================================================

(struct low-pnet-parse-error exn:fail (form hint) #:transparent)
(struct low-pnet-validate-error exn:fail (issue) #:transparent)

(define (parse-error! form hint)
  (raise (low-pnet-parse-error
          (format "low-pnet parse error: ~a (form: ~v)" hint form)
          (current-continuation-marks)
          form
          hint)))

(define (validate-error! issue)
  (raise (low-pnet-validate-error
          (format "low-pnet validate error: ~a" issue)
          (current-continuation-marks)
          issue)))

;; ============================================================
;; Parser: sexp-form → low-pnet structure
;; ============================================================
;;
;; Top-level shape:
;;   (low-pnet
;;    :version (1 0)
;;    (cell-decl 0 0 (i64 0))
;;    (propagator-decl 0 (0 1) (2) 'int-add 0)
;;    ...)
;;
;; Keyword args (`:version`, `:substrate`) appear before positional decls.
;; Order of decls is preserved in the resulting nodes list.

(define (parse-low-pnet sexp)
  (match sexp
    [(cons 'low-pnet rest)
     (parse-toplevel rest)]
    [_ (parse-error! sexp "top-level form must start with 'low-pnet")]))

(define (parse-toplevel rest)
  ;; Eat keyword args, then positional decls.
  (define-values (version-pair body) (eat-version rest))
  (define-values (_extra-kw decls) (eat-extra-keywords body))
  (low-pnet version-pair (map parse-decl decls)))

(define (eat-version rest)
  (match rest
    [(list-rest ':version v more)
     (unless (and (list? v) (= (length v) 2)
                  (exact-nonnegative-integer? (car v))
                  (exact-nonnegative-integer? (cadr v)))
       (parse-error! v ":version must be a (major minor) pair"))
     (values v more)]
    [_ (values LOW_PNET_FORMAT_VERSION rest)]))

(define (eat-extra-keywords rest)
  ;; For now we accept (and ignore) further keyword pairs like :substrate.
  ;; Future minor versions can record them.
  (let loop ([acc '()] [rs rest])
    (match rs
      [(list-rest (? (lambda (x) (and (symbol? x) (regexp-match? #px"^:" (symbol->string x)))) k) v more)
       (loop (cons (cons k v) acc) more)]
      [_ (values (reverse acc) rs)])))

(define (parse-decl form)
  (match form
    [(list 'cell-decl id dom init)
     (unless (exact-nonnegative-integer? id) (parse-error! form "cell-decl id must be non-negative integer"))
     (unless (exact-nonnegative-integer? dom) (parse-error! form "cell-decl domain-id must be non-negative integer"))
     (cell-decl id dom init)]

    [(list 'propagator-decl id ins outs tag flags)
     (unless (exact-nonnegative-integer? id) (parse-error! form "propagator-decl id must be non-negative integer"))
     (unless (and (list? ins) (andmap exact-nonnegative-integer? ins))
       (parse-error! form "propagator-decl input-cells must be a list of non-negative integers"))
     (unless (and (list? outs) (andmap exact-nonnegative-integer? outs))
       (parse-error! form "propagator-decl output-cells must be a list of non-negative integers"))
     (unless (symbol? tag) (parse-error! form "propagator-decl fire-fn-tag must be a symbol"))
     (unless (exact-nonnegative-integer? flags)
       (parse-error! form "propagator-decl flags must be non-negative integer"))
     (propagator-decl id ins outs tag flags)]

    [(list 'domain-decl id name merge-tag bot contra-tag)
     (unless (exact-nonnegative-integer? id) (parse-error! form "domain-decl id must be non-negative integer"))
     (unless (symbol? name) (parse-error! form "domain-decl name must be a symbol"))
     (unless (symbol? merge-tag) (parse-error! form "domain-decl merge-fn-tag must be a symbol"))
     (unless (symbol? contra-tag) (parse-error! form "domain-decl contradiction-pred-tag must be a symbol"))
     (domain-decl id name merge-tag bot contra-tag)]

    [(list 'write-decl cid value tag)
     ;; V1.0 back-compat shape: 3-arg form defaults mode to 'merge.
     (unless (exact-nonnegative-integer? cid) (parse-error! form "write-decl cell-id must be non-negative integer"))
     (unless (exact-nonnegative-integer? tag) (parse-error! form "write-decl tag must be non-negative integer"))
     (write-decl cid value tag 'merge)]

    [(list 'write-decl cid value tag mode)
     ;; V1.1 shape: explicit mode tag.
     (unless (exact-nonnegative-integer? cid) (parse-error! form "write-decl cell-id must be non-negative integer"))
     (unless (exact-nonnegative-integer? tag) (parse-error! form "write-decl tag must be non-negative integer"))
     (unless (or (eq? mode 'merge) (eq? mode 'reset))
       (parse-error! form "write-decl mode must be 'merge or 'reset"))
     (write-decl cid value tag mode)]

    [(list 'dep-decl pid cid paths)
     (unless (exact-nonnegative-integer? pid) (parse-error! form "dep-decl prop-id must be non-negative integer"))
     (unless (exact-nonnegative-integer? cid) (parse-error! form "dep-decl cell-id must be non-negative integer"))
     (unless (or (eq? paths 'all) (list? paths))
       (parse-error! form "dep-decl paths must be 'all or a list"))
     (dep-decl pid cid paths)]

    [(list 'stratum-decl id name handler-tag)
     (unless (exact-nonnegative-integer? id) (parse-error! form "stratum-decl id must be non-negative integer"))
     (unless (symbol? name) (parse-error! form "stratum-decl name must be a symbol"))
     (unless (symbol? handler-tag) (parse-error! form "stratum-decl handler-tag must be a symbol"))
     (stratum-decl id name handler-tag)]

    [(list 'entry-decl mid)
     (unless (exact-nonnegative-integer? mid)
       (parse-error! form "entry-decl main-cell-id must be non-negative integer"))
     (entry-decl mid)]

    [(list 'iter-block-decl state-cells next-cells cond-cell halt-when)
     (unless (and (list? state-cells) (andmap exact-nonnegative-integer? state-cells))
       (parse-error! form "iter-block-decl state-cells must be a list of non-negative integers"))
     (unless (and (list? next-cells) (andmap exact-nonnegative-integer? next-cells))
       (parse-error! form "iter-block-decl next-cells must be a list of non-negative integers"))
     (unless (= (length state-cells) (length next-cells))
       (parse-error! form "iter-block-decl state-cells and next-cells must have same length"))
     (unless (exact-nonnegative-integer? cond-cell)
       (parse-error! form "iter-block-decl cond-cell must be non-negative integer"))
     (unless (boolean? halt-when)
       (parse-error! form "iter-block-decl halt-when must be a boolean"))
     (iter-block-decl state-cells next-cells cond-cell halt-when)]

    [(list 'meta-decl key value)
     (unless (symbol? key) (parse-error! form "meta-decl key must be a symbol"))
     (meta-decl key value)]

    [_ (parse-error! form "unknown decl head; expected one of: cell-decl, propagator-decl, domain-decl, write-decl, dep-decl, stratum-decl, entry-decl, iter-block-decl, meta-decl")]))

;; ============================================================
;; Pretty-printer: low-pnet structure → sexp-form (round-trips with parse-low-pnet)
;; ============================================================

(define (pp-low-pnet p)
  (match p
    [(low-pnet version nodes)
     (cons 'low-pnet
           (cons ':version
                 (cons version
                       (map pp-decl nodes))))]))

(define (pp-decl d)
  (match d
    [(cell-decl id dom init)             (list 'cell-decl id dom init)]
    [(propagator-decl id ins outs tag fl) (list 'propagator-decl id ins outs tag fl)]
    [(domain-decl id name mtag bot ctag) (list 'domain-decl id name mtag bot ctag)]
    [(write-decl cid value tag mode)
     ;; Round-trip: emit the V1.0 3-arg shape when mode is the default
     ;; ('merge); emit the V1.1 4-arg shape only when mode is non-default
     ;; ('reset). Keeps existing IR fixtures (n0, one-prop, etc.) byte-stable.
     (if (eq? mode 'merge)
         (list 'write-decl cid value tag)
         (list 'write-decl cid value tag mode))]
    [(iter-block-decl scs ncs cc hw)     (list 'iter-block-decl scs ncs cc hw)]
    [(dep-decl pid cid paths)            (list 'dep-decl pid cid paths)]
    [(stratum-decl id name htag)         (list 'stratum-decl id name htag)]
    [(entry-decl mid)                    (list 'entry-decl mid)]
    [(meta-decl key value)               (list 'meta-decl key value)]))

;; ============================================================
;; Validator: structural well-formedness checks
;; ============================================================
;;
;; Checks:
;;  V1. Every cell-decl id is unique.
;;  V2. Every propagator-decl id is unique.
;;  V3. Every domain-decl id is unique.
;;  V4. Every stratum-decl id is unique.
;;  V5. Every cell-decl's domain-id references an existing domain-decl.
;;  V6. Every propagator-decl's input-cells and output-cells are existing cell-decl ids.
;;  V7. Every write-decl's cell-id references an existing cell-decl.
;;  V8. Every dep-decl's prop-id and cell-id reference existing decls.
;;  V9. Exactly one entry-decl exists; its main-cell-id references an existing cell-decl.
;;  V10. Order: domain-decls precede the cell-decls that reference them
;;       (since lowering instantiates domains first). Same for: cell-decls
;;       precede write-decls / propagator-decls / dep-decls / entry-decls
;;       that reference them.
;;  V11. iter-block-decl references existing state/next/cond cells
;;       (Sprint G; retired by kernel-PU Phase 6).
;;  V12. write-decl mode tag is 'merge or 'reset (kernel-PU Phase 3 Day 8).
;;       Defensive: parse-decl already enforces this, but a separate validator
;;       pass catches programmatically-constructed write-decls with bad modes.

(define (validate-low-pnet p)
  (match p
    [(low-pnet _version nodes)
     (define cells (filter cell-decl? nodes))
     (define props (filter propagator-decl? nodes))
     (define doms  (filter domain-decl? nodes))
     (define strata (filter stratum-decl? nodes))
     (define entries (filter entry-decl? nodes))

     ;; V1-V4: id uniqueness
     (check-unique! "cell-decl" (map cell-decl-id cells))
     (check-unique! "propagator-decl" (map propagator-decl-id props))
     (check-unique! "domain-decl" (map domain-decl-id doms))
     (check-unique! "stratum-decl" (map stratum-decl-id strata))

     (define domain-ids (apply seteq (map domain-decl-id doms)))
     (define cell-ids   (apply seteq (map cell-decl-id cells)))
     (define prop-ids   (apply seteq (map propagator-decl-id props)))

     ;; V5: cell domain references
     (for ([c (in-list cells)])
       (unless (set-member? domain-ids (cell-decl-domain-id c))
         (validate-error! (format "cell-decl ~a references unknown domain-id ~a"
                                  (cell-decl-id c) (cell-decl-domain-id c)))))

     ;; V6: propagator input/output references
     (for ([p (in-list props)])
       (for ([cid (in-list (propagator-decl-input-cells p))])
         (unless (set-member? cell-ids cid)
           (validate-error! (format "propagator-decl ~a references unknown input cell-id ~a"
                                    (propagator-decl-id p) cid))))
       (for ([cid (in-list (propagator-decl-output-cells p))])
         (unless (set-member? cell-ids cid)
           (validate-error! (format "propagator-decl ~a references unknown output cell-id ~a"
                                    (propagator-decl-id p) cid)))))

     ;; V7: write-decl cell references
     ;; V12: write-decl mode well-formedness (defensive; parser also checks)
     (for ([w (in-list (filter write-decl? nodes))])
       (unless (set-member? cell-ids (write-decl-cell-id w))
         (validate-error! (format "write-decl references unknown cell-id ~a"
                                  (write-decl-cell-id w))))
       (define m (write-decl-mode w))
       (unless (or (eq? m 'merge) (eq? m 'reset))
         (validate-error! (format "write-decl on cell-id ~a has invalid mode ~v (must be 'merge or 'reset)"
                                  (write-decl-cell-id w) m))))

     ;; V8: dep-decl references
     (for ([d (in-list (filter dep-decl? nodes))])
       (unless (set-member? prop-ids (dep-decl-prop-id d))
         (validate-error! (format "dep-decl references unknown prop-id ~a"
                                  (dep-decl-prop-id d))))
       (unless (set-member? cell-ids (dep-decl-cell-id d))
         (validate-error! (format "dep-decl references unknown cell-id ~a"
                                  (dep-decl-cell-id d)))))

     ;; V9: exactly one entry-decl pointing at a real cell
     (cond
       [(null? entries) (validate-error! "no entry-decl: program has no result cell")]
       [(> (length entries) 1) (validate-error! (format "multiple entry-decls: ~a" (length entries)))]
       [else
        (define mid (entry-decl-main-cell-id (car entries)))
        (unless (set-member? cell-ids mid)
          (validate-error! (format "entry-decl references unknown cell-id ~a" mid)))])

     ;; V11: iter-block-decl references (Sprint G)
     (for ([ib (in-list (filter iter-block-decl? nodes))])
       (for ([cid (in-list (iter-block-decl-state-cells ib))])
         (unless (set-member? cell-ids cid)
           (validate-error! (format "iter-block-decl references unknown state-cell ~a" cid))))
       (for ([cid (in-list (iter-block-decl-next-cells ib))])
         (unless (set-member? cell-ids cid)
           (validate-error! (format "iter-block-decl references unknown next-cell ~a" cid))))
       (unless (set-member? cell-ids (iter-block-decl-cond-cell ib))
         (validate-error! (format "iter-block-decl references unknown cond-cell ~a"
                                  (iter-block-decl-cond-cell ib)))))

     ;; V10: declaration order — for each declaration that references something,
     ;; check that the referenced node appeared earlier in the list.
     (validate-declaration-order! nodes)

     #t]))

(define (check-unique! kind ids)
  (define seen (make-hasheq))
  (for ([id (in-list ids)])
    (when (hash-ref seen id #f)
      (validate-error! (format "duplicate ~a id: ~a" kind id)))
    (hash-set! seen id #t)))

(define (validate-declaration-order! nodes)
  (define seen-cells (make-hasheq))
  (define seen-props (make-hasheq))
  (define seen-doms (make-hasheq))
  (for ([n (in-list nodes)])
    (match n
      [(domain-decl id _ _ _ _) (hash-set! seen-doms id #t)]
      [(cell-decl id dom _)
       (unless (hash-ref seen-doms dom #f)
         (validate-error! (format "cell-decl ~a references domain-id ~a declared later" id dom)))
       (hash-set! seen-cells id #t)]
      [(propagator-decl id ins outs _ _)
       (for ([c (in-list ins)])
         (unless (hash-ref seen-cells c #f)
           (validate-error! (format "propagator-decl ~a references cell-id ~a declared later" id c))))
       (for ([c (in-list outs)])
         (unless (hash-ref seen-cells c #f)
           (validate-error! (format "propagator-decl ~a references cell-id ~a declared later" id c))))
       (hash-set! seen-props id #t)]
      [(write-decl cid _ _ _)
       (unless (hash-ref seen-cells cid #f)
         (validate-error! (format "write-decl references cell-id ~a declared later" cid)))]
      [(dep-decl pid cid _)
       (unless (hash-ref seen-props pid #f)
         (validate-error! (format "dep-decl references prop-id ~a declared later" pid)))
       (unless (hash-ref seen-cells cid #f)
         (validate-error! (format "dep-decl references cell-id ~a declared later" cid)))]
      [(entry-decl mid)
       (unless (hash-ref seen-cells mid #f)
         (validate-error! (format "entry-decl references cell-id ~a declared later" mid)))]
      [_ (void)])))  ;; meta-decl, stratum-decl: no order constraints

;; ============================================================
;; Local helpers
;; ============================================================

(define (seteq . xs)
  (define h (make-hasheq))
  (for ([x (in-list xs)]) (hash-set! h x #t))
  h)

(define (set-member? h x) (hash-ref h x #f))
