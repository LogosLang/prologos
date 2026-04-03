#lang racket/base

;;;
;;; PPN Track 3 Phase 6+3a: Per-Form Cells + Spec Cells
;;;
;;; Phase 6: Each top-level source form gets ONE cell on the elaboration network.
;;; The cell value is a form-pipeline-value (Pocket Universe from Phase 5).
;;; The merge function is set-union on transforms (Boolean lattice).
;;;
;;; Phase 3a: Per-function spec cells. When a spec form is processed,
;;; the spec entry is written to a spec cell keyed by function name.
;;; Defn forms can read the spec cell to get their type annotation.
;;; Ordering emerges from cell dependency — no two-pass ordering.
;;;

(require racket/set
         racket/list
         "elaborator-network.rkt"
         "elab-network-types.rkt"
         "parse-reader.rkt"
         "surface-rewrite.rkt"
         "tree-parser.rkt"
         "infra-cell.rkt"
         "source-location.rkt"
         "rrb.rkt"
         "surface-syntax.rkt"
         ;; Phase 4 (big-bang): consumed form processing
         "macros.rkt"
         "parser.rkt"
         "errors.rkt")

(provide
 ;; Phase 6: Cell creation
 create-form-cells-from-tree
 ;; Phase 6: Cell access
 form-cell-ref
 ;; Phase 6: Production dispatch
 dispatch-form-productions
 ;; Phase 7: Extract surfs from completed form cells
 extract-surfs-from-form-cells
 ;; Phase 3a completion: annotate defn surfs with spec types
 annotate-surfs-with-specs
 ;; Phase 6: Merge function (exposed for testing / validation)
 form-cell-merge-fn
 ;; Phase 3a: Spec cells
 (struct-out spec-cell-value)
 spec-cell-merge-fn
 create-spec-cell
 write-spec-cell
 read-spec-cell
 extract-specs-from-form-cells)

;; ========================================
;; Form cell merge function
;; ========================================

;; form-cell-merge-fn: installed on each per-form cell.
;; This IS form-pipeline-merge from surface-rewrite.rkt (Phase 5).
;; Both pipelines can write to the same cell; the merge resolves.
(define (form-cell-merge-fn old new)
  (form-pipeline-merge old new))

;; ========================================
;; Cell creation: one cell per top-level form
;; ========================================

;; Given a parse-tree (from read-to-tree) and the current elab-network,
;; creates one cell per top-level form node.
;; Each cell starts with (seteq) transforms and the raw tree-node.
;;
;; Returns: (values updated-enet (hasheq source-line -> cell-id) (hasheq source-line -> raw-node))
(define (create-form-cells-from-tree pt enet)
  (define top-forms (tree-top-level-forms pt))

  (let loop ([remaining top-forms]
             [current-enet enet]
             [cell-map (hasheq)]
             [raw-map (hasheq)])
    (if (null? remaining)
        (values current-enet cell-map raw-map)
        (let* ([node (car remaining)]
               [loc (and (parse-tree-node? node)
                         (parse-tree-node-srcloc node))]
               ;; parse-tree-node srcloc is (line col start-pos end-pos) — first element is line
               [line (cond
                       [(srcloc? loc) (srcloc-line loc)]
                       [(and (list? loc) (pair? loc) (number? (car loc))) (car loc)]
                       [else #f])]
               [pv (form-pipeline-value
                    (seteq) node '() loc)])
          (define-values (new-enet cell-id)
            (elab-new-infra-cell current-enet pv form-cell-merge-fn))
          (loop (cdr remaining)
                new-enet
                (if line (hash-set cell-map line cell-id) cell-map)
                (if line (hash-set raw-map line node) raw-map))))))

;; ========================================
;; Cell access
;; ========================================

;; Read a form cell's value from the elab-network
(define (form-cell-ref enet cell-id)
  (elab-cell-read enet cell-id))

;; ========================================
;; Production dispatch
;; ========================================

;; Run the full tree pipeline on each form cell:
;; read tree-node → run-form-pipeline → write completed result
;;
;; This is the production dispatch: for each form, the pipeline
;; (G(0) grouping → T(0) tagging → rewrites → parse) produces
;; the final form-pipeline-value with 'done in transforms.
;;
;; Returns: updated elab-network with all form cells at 'done
(define (dispatch-form-productions enet cell-map)
  (for/fold ([current-enet enet])
            ([(line cell-id) (in-hash cell-map)])
    (define pv (elab-cell-read current-enet cell-id))
    (define node (form-pipeline-value-tree-node pv))
    (if (not node)
        current-enet
        ;; Run the full pipeline on this form's tree node
        (let ([result (run-form-pipeline node)])
          ;; Write the completed pipeline value to the cell
          (elab-cell-write current-enet cell-id result)))))

;; ========================================
;; Phase 4 (big-bang): Extract surfs from form cells
;; ========================================

;; After dispatch-form-productions completes, each form cell holds a
;; completed form-pipeline-value with a rewritten tree-node.
;;
;; For non-consumed forms: parse-form-tree produces a surf-* directly.
;; For consumed forms (data/trait/impl/etc.): parse-form-tree returns
;; an error stub. We convert the tree-node to a datum, call the
;; appropriate process-* function (which also performs registration),
;; and parse each generated def through parse-datum.
;;
;; Returns: list of surf-* structs (in source-line order, with
;; consumed forms expanded to their generated defs), suitable for
;; passing to process-surfs.

;; Helper: convert tree-node args (token-entries + parse-tree-nodes) to flat datum list
(define (tree-args-to-datums args)
  (for/list ([a (in-list args)])
    (cond
      [(token-entry? a)
       (define lex (token-entry-lexeme a))
       (or (string->number lex) (string->symbol lex))]
      [(parse-tree-node? a)
       (define children
         (for/list ([c (in-list (rrb-to-list (parse-tree-node-children a)))]
                    #:when (token-entry? c))
           (define cl (token-entry-lexeme c))
           (or (string->number cl) (string->symbol cl))))
       (cond
         [(null? children) '()]
         [(= (length children) 1) (car children)]
         [(eq? (car children) '$brace-params) children]
         [else children])]
      [else a])))

;; Helper: get args from a tree-node (children after the keyword token)
(define (node-args-for-datum node)
  (define children (rrb-to-list (parse-tree-node-children node)))
  (if (and (pair? children) (token-entry? (car children)))
      (cdr children)  ;; skip keyword token
      children))

;; The consumed form handlers: tag → (datum → list-of-generated-defs)
;; Each returns a list of sexp defs. Registration happens as a side effect.
;;
;; Two categories:
;; 1. Forms that produce GENERATED DEFS (data, trait, impl): return sexp def lists
;; 2. Forms that are SIDE-EFFECT-ONLY (deftype, bundle, etc.): return '()
;; 3. Forms that have SURF-* structs but tree-parser stubs: convert to datum,
;;    call parse-datum directly to produce the surf.
(define (process-consumed-form tag node)
  (define args (node-args-for-datum node))
  (define arg-datums (tree-args-to-datums args))
  (define datum (cons tag arg-datums))
  (with-handlers ([exn:fail? (lambda (e) '())])  ;; on error, produce no defs
    (case tag
      ;; Category 1: produce generated defs (registration + N defs)
      [(data)     (process-data datum)]
      [(trait)    (process-trait datum)]
      [(impl)     (let ([defs (process-impl datum)])
                    (for/list ([d (in-list defs)])
                      (preparse-expand-form d)))]
      ;; Category 2: side-effect-only (registration, no defs returned)
      [(deftype)  (process-deftype datum) '()]
      [(bundle)   (process-bundle (rewrite-implicit-map datum)) '()]
      [(defmacro) (process-defmacro datum) '()]
      [(property) (process-property (rewrite-implicit-map datum)) '()]
      [(functor)  (process-functor (rewrite-implicit-map datum)) '()]
      [(precedence-group) '()]  ;; registration only
      [(specialize) '()]  ;; registration only
      ;; Category 3: forms that USED to be in consumed-form but now go through
      ;; the general single-parser path (raw node → datum → expand → parse).
      ;; Returning '() makes them fall through to the general handler.
      ;; ns/imports/exports: consumed, no surfs produced
      ;; Their side effects (namespace setup, module loading) happen in preparse
      [(ns imports exports) '()]
      [else '()])))

;; Convert generated defs to surfs via parse-datum
(define (defs-to-surfs defs)
  (for/list ([d (in-list defs)]
             #:when (pair? d))
    (parse-datum (datum->syntax #f d))))

;; Helper: restructure infix = in a top-level datum.
;; (add ?a 3N = 5N) → (= (add ?a 3N) 5N)
;; Same as macros.rkt's maybe-restructure-infix-eq (not exported).
;; §11: restructure-infix-eq, flatten-ws-datum, normalize-ws-tokens
;; are now in tree-parser.rkt (imported above) to avoid circular dependency.

;; flatten-ws-datum, normalize-ws-tokens: imported from tree-parser.rkt

;; Helper: convert a tree-node to a datum for preparse-expand-form fallback.
;; Uses tree-node->stx-form which produces a single syntax object
;; representing the entire form (grouped, like the compat reader output).
(define (tree-node-to-datum node source-str)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (define stx (tree-node->stx-form node "<cell>" (or source-str "")))
    (if stx (syntax->datum stx) #f)))

;; §11.5 Opt-in: form tags where parse-form-tree is VERIFIED to produce
;; correct surfs (semantically identical to parse-datum, modulo srcloc format).
;; Each tag added here means that form type is ON-NETWORK via tree-parser.
;; Start empty; add forms as parity is verified per-test.
;; §11.5: Form tags where tree-parser surfs are verified correct.
;; Empty for now — datum-always is the proven path.
;; Each form migrates here individually after verification.
;; The GOAL is to move ALL forms here, making datum path unnecessary.
;; But each form requires parse-form-tree to replicate parser.rkt's
;; keyword-specific logic (motive annotations, multiplicity, etc.)
;; §11.5: start empty (datum-always), opt-in verified forms
;; TOP-LEVEL form tags where parse-form-tree uses datum conversion on
;; the whole node (via parse-eval-tree-for-cell). ON-NETWORK dispatch.
;; Expression-level tags (bracket-group, etc.) are NOT here — they're
;; handled by form parsers' recursive descent via datum path.
;; VERIFIED forms: these produce correct surfs via parse-form-tree
;; with datum conversion on whole node. Each verified by targeted tests.
;; §11: Verified forms use parse-form-tree dispatch (ON-NETWORK).
;; eval/check/infer: single-expression forms that convert cleanly via
;; parse-eval-tree-for-cell (whole node → datum → normalize → expand → parse).
;; ALL OTHER forms use datum-always path in extract-surfs (raw node → datum).
;; Both paths produce identical surfs via parse-datum — the difference is
;; WHETHER form dispatch goes through parse-form-tree (on-network) or not.
;; §11: eval/check/infer ON-NETWORK. Rest datum-always.
;; Full on-network pending fix for Hole diagnostic in cond (batch runner false positive).
;; ALL top-level forms ON-NETWORK
(define tree-parser-verified-tags
  '(eval check infer def defn defn-multi spec
    strategy session defproc defr solver subtype selection capability foreign))

;; §11 TREE-CANONICAL extraction rewrite
(define (extract-surfs-from-form-cells enet cell-map
                                        #:source-str [source-str #f]
                                        #:raw-map [raw-map (hasheq)])
  ;; §11: current-source-str is set via parameterize in process-string-ws-inner
  (define pairs
    (for/fold ([acc '()])
              ([(line cell-id) (in-hash cell-map)])
      (define pv (elab-cell-read enet cell-id))
      (define node (form-pipeline-value-tree-node pv))
      (if (not node) acc
          (let ([tag (parse-tree-node-tag node)])
            ;; §11: set raw-node for datum conversion in parse-eval-tree-for-cell
            (current-raw-node (hash-ref raw-map line #f))
            (cond
              ;; Side-effect-only: no surfs
              [(memq tag '(ns imports exports spec deftype bundle defmacro property
                           functor schema precedence-group specialize))
               acc]
              ;; Generated-def forms: process-consumed-form returns sexp lists
              [(memq tag '(data trait impl))
               (define gen-defs (process-consumed-form tag node))
               (if (null? gen-defs) acc
                   (let ([surfs (defs-to-surfs gen-defs)])
                     (if (null? surfs) acc
                         (cons (cons line surfs) acc))))]
              ;; §11 opt-in: verified forms use tree-parser, rest datum
              [(memq tag tree-parser-verified-tags)
               (define surf (parse-form-tree node))
               (if (not (prologos-error? surf))
                   (cons (cons line (list surf)) acc)
                   acc)]
              ;; Datum conversion for unverified forms
              [else
               (let* ([raw-node (hash-ref raw-map line #f)]
                      [use-node (or raw-node node)]
                      [datum (tree-node-to-datum use-node source-str)])
                 (if (not datum) acc
                     (with-handlers ([exn:fail? (lambda (e) acc)])
                       (define flat-datum (flatten-ws-datum datum))
                       (define session-datum
                         (cond
                           [(and (pair? flat-datum) (eq? (car flat-datum) 'session))
                            (desugar-session-ws flat-datum)]
                           [(and (pair? flat-datum) (eq? (car flat-datum) 'defproc))
                            (desugar-defproc-ws flat-datum)]
                           [else flat-datum]))
                       (define eq-datum (restructure-infix-eq session-datum))
                       (define norm-datum (normalize-ws-tokens eq-datum))
                       (define expanded (preparse-expand-single norm-datum))
                       (define s (parse-datum (datum->syntax #f expanded)))
                       (if (prologos-error? s) acc
                           (cons (cons line (list s)) acc)))))])))))  ;; close
  ;; Sort by source line, flatten surf lists
  (define sorted (sort pairs < #:key car))
  (apply append (map cdr sorted)))

;; ========================================
;; Phase 3a completion: Annotate defn surfs with spec types
;; ========================================
;;
;; After extract-surfs-from-form-cells produces surfs, defn forms
;; may lack type annotations (surf-defn-type = #f for bare-param defns).
;; If a matching spec exists in current-spec-store, we inject the type.
;;
;; This replaces preparse's maybe-inject-spec which modifies datums.
;; Here we modify surfs directly — post-parse annotation.
;;
;; Handles:
;;   - surf-defn with type=#f and bare params → inject spec type
;;   - surf-defn with existing type → leave unchanged (user annotation wins)
;;   - surf-defn-multi → leave unchanged (pattern compilation handles types)
;;   - Non-defn forms → pass through

(define (annotate-surfs-with-specs surfs)
  (for/list ([s (in-list surfs)])
    (cond
      ;; surf-defn — check if spec should replace/augment type
      [(surf-defn? s)
       (define name (surf-defn-name s))
       (define spec (lookup-spec name))
       (if (not spec)
           s  ;; no spec → leave as-is
           ;; Has spec → parse spec type and replace the defn's type
           ;; The tree-parser produces Pi chains with holes for bare params.
           ;; The spec type is the correct, fully-typed Pi chain.
           (let ([type-datums (spec-entry-type-datums spec)])
             (if (or (null? type-datums) (spec-entry-multi? spec))
                 s  ;; multi-arity spec or empty → leave for expand-top-level
                 ;; Parse the spec type tokens to a surf type expression
                 (let* ([tokens (car type-datums)]
                        [type-datum `($angle-type ,@tokens)]
                        [type-surf (parse-datum (datum->syntax #f type-datum))])
                   (if (prologos-error? type-surf)
                       s  ;; parse error → leave as-is
                       (struct-copy surf-defn s [type type-surf]))))))]
      ;; Everything else passes through unchanged
      [else s])))

;; ========================================
;; Phase 3a: Spec Cells
;; ========================================
;;
;; Per-function spec cells: when a spec form is processed, the spec
;; entry (type signature + metadata) is written to a cell keyed by
;; function name. Defn forms read spec cells to get type annotations.
;;
;; This replaces the two-pass ordering in preparse-expand-all:
;; - OLD: Pass 1 scans all specs → Pass 2 injects into defns
;; - NEW: Spec cell written by spec production → defn reads cell
;;        If spec not yet written, defn proceeds without annotation.
;;        When spec cell is written later, re-fire annotates the defn.
;;
;; For Phase 3a, spec cells are CREATED and POPULATED from tree-parser
;; output. The consumption (defn reading spec cells) is Phase 7 scope.

;; Spec cell value: holds the parsed spec information for one function.
;; D.5 fix (F4): collision = top (error), not first-write-wins.
(struct spec-cell-value
  (name         ;; symbol — function name
   type-surf    ;; surf-* — parsed type expression (or #f if bot)
   metadata     ;; hash or #f — spec metadata (:mixfix, :doc, etc.)
   top?)        ;; boolean — #t if collision detected (two specs for same name)
  #:transparent)

;; Bot value for spec cells
(define spec-cell-bot (spec-cell-value #f #f #f #f))

;; Merge function for spec cells:
;; - bot ⊔ x = x
;; - x ⊔ bot = x
;; - x ⊔ x = x (idempotent)
;; - x ⊔ y = top when x ≠ y (collision = error, D.5 F4)
(define (spec-cell-merge-fn old new)
  (cond
    ;; bot cases
    [(not (spec-cell-value-type-surf old)) new]
    [(not (spec-cell-value-type-surf new)) old]
    ;; Already top → stays top
    [(spec-cell-value-top? old) old]
    [(spec-cell-value-top? new) new]
    ;; Same name + same type → idempotent
    [(and (eq? (spec-cell-value-name old) (spec-cell-value-name new))
          (equal? (spec-cell-value-type-surf old) (spec-cell-value-type-surf new)))
     old]
    ;; Collision: two different specs for the same function → top (error)
    [else (spec-cell-value (spec-cell-value-name old)
                           (spec-cell-value-type-surf old)
                           (spec-cell-value-metadata old)
                           #t)]))

;; Create a spec cell for a function name.
;; Returns: (values updated-enet cell-id)
(define (create-spec-cell enet)
  (elab-new-infra-cell enet spec-cell-bot spec-cell-merge-fn))

;; Write a spec entry to a spec cell.
;; Returns: updated enet
(define (write-spec-cell enet cell-id name type-surf metadata)
  (elab-cell-write enet cell-id
                   (spec-cell-value name type-surf metadata #f)))

;; Read a spec cell's value.
(define (read-spec-cell enet cell-id)
  (elab-cell-read enet cell-id))

;; Extract spec entries from completed form cells.
;; Scans all form cells for spec forms, creates spec cells, and populates them.
;; Returns: (values updated-enet (hasheq function-name -> spec-cell-id))
(define (extract-specs-from-form-cells enet cell-map)
  (for/fold ([current-enet enet]
             [spec-map (hasheq)]
             #:result (values current-enet spec-map))
            ([(line cell-id) (in-hash cell-map)])
    (define pv (elab-cell-read current-enet cell-id))
    (define node (form-pipeline-value-tree-node pv))
    ;; Check if this form is a spec (tag = 'spec after pipeline)
    (if (and node (parse-tree-node? node)
             (eq? (parse-tree-node-tag node) 'spec))
        ;; Extract function name from the spec tree node.
        ;; Spec form's children: [keyword-token, name-token, type-tokens...]
        ;; First token after the "spec" keyword is the function name.
        (let* ([children (rrb-to-list (parse-tree-node-children node))]
               [args (if (and (pair? children) (token-entry? (car children)))
                         (cdr children)  ;; skip keyword token
                         children)]
               [name-token (and (pair? args) (car args))]
               [name (and (token-entry? name-token)
                          (string->symbol (token-entry-lexeme name-token)))])
          (if name
              (let-values ([(enet* scid) (create-spec-cell current-enet)])
                (define enet** (write-spec-cell enet* scid name #f #f))
                (values enet** (hash-set spec-map name scid)))
              (values current-enet spec-map)))
        (values current-enet spec-map))))
