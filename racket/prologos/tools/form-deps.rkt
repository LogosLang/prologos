#lang racket/base

;; form-deps.rkt — Form-level dependency analysis for the Prologos stdlib.
;;
;; Reads .prologos book chapters via the WS reader, splits at module
;; boundaries, and extracts defines/references for each form. Builds
;; a form-level dependency graph and computes SCCs to identify genuine
;; vs spurious module-level cycles.
;;
;; Usage:
;;   racket tools/form-deps.rkt                  — analyze all chapters
;;   racket tools/form-deps.rkt --verbose        — show per-module details
;;   racket tools/form-deps.rkt --chapter NAME   — analyze one chapter

(require racket/list
         racket/set
         racket/string
         racket/path
         racket/file
         racket/cmdline
         racket/format
         "../parse-reader.rkt"
         "../stratify.rkt")

;; ============================================================
;; Configuration
;; ============================================================

(define project-root
  (simplify-path (build-path (path-only (syntax-source #'here)) "..")))

(define book-dir
  (build-path project-root "lib" "prologos" "book"))

;; Syntax keywords/builtins that are never cross-form references.
(define syntax-keywords
  (seteq 'match 'fn 'if 'the 'let 'do 'def 'defn 'spec 'data 'trait 'impl
         'deftype 'defmacro 'bundle 'property 'functor 'check 'eval 'infer
         'expand 'foreign 'require 'provide 'ns 'module 'subtype
         'specialize 'schema 'solver 'defr 'precedence-group 'with-transient
         '-> '=> ': ':= ':doc ':no-prelude ':refer ':as ':refer-all
         '$pipe '$angle-type '$brace-params '$quote '$dot-access '$dot-key
         '$mixfix '$pipe-gt '$compose
         'where 'of 'refl 'J
         'Type 'Unit 'unit))

;; ============================================================
;; Data Structures
;; ============================================================

;; A parsed form from a module.
(struct form-node
  (module-name   ;; symbol — fully qualified module name
   index         ;; nat — position within module
   kind          ;; symbol — 'data, 'trait, 'impl, 'defn, 'def, 'spec, etc.
   defines       ;; (setof symbol) — names this form introduces
   references    ;; (setof symbol) — names this form uses (conservative superset)
   raw)          ;; datum — original parsed form (for diagnostics)
  #:transparent)

;; A parsed module with its forms.
(struct module-info
  (name          ;; symbol — fully qualified module name
   requires      ;; (listof symbol) — required module names
   forms)        ;; (listof form-node)
  #:transparent)

;; ============================================================
;; OUTLINE reader
;; ============================================================

(define (read-outline)
  (define outline-path (build-path book-dir "OUTLINE"))
  (define lines (file->lines outline-path))
  (filter-map
   (lambda (line)
     (define stripped (string-trim line))
     (cond
       [(string=? stripped "") #f]
       [(string-prefix? stripped ";;") #f]
       [else stripped]))
   lines))

;; ============================================================
;; Chapter parsing: split at module boundaries
;; ============================================================

(define (parse-chapter chapter-name)
  (define chapter-path (build-path book-dir (format "~a.prologos" chapter-name)))
  (define content (file->string chapter-path))
  (define all-forms (read-all-forms-string content))
  ;; Split into modules at (module ...) directives
  (split-at-modules all-forms))

;; Split a flat list of forms into (listof module-info).
;; Each (module name ...) starts a new module section.
(define (split-at-modules forms)
  (define modules '())
  (define current-name #f)
  (define current-requires '())
  (define current-forms '())
  (define current-idx 0)

  (define (flush!)
    (when current-name
      (set! modules
            (cons (module-info current-name
                              (reverse current-requires)
                              (reverse current-forms))
                  modules))))

  (for ([form (in-list forms)])
    (cond
      [(and (pair? form) (eq? (car form) 'module))
       ;; Flush previous module
       (flush!)
       ;; Start new module
       (set! current-name (cadr form))
       (set! current-requires '())
       (set! current-forms '())
       (set! current-idx 0)]
      [(and (pair? form) (eq? (car form) 'require) current-name)
       ;; Extract required module name
       (define req-spec (cadr form))
       (when (and (pair? req-spec) (symbol? (car req-spec)))
         (set! current-requires (cons (car req-spec) current-requires)))]
      [current-name
       ;; A declaration form inside a module
       (define node (analyze-form current-name current-idx form))
       (when node
         (set! current-forms (cons node current-forms))
         (set! current-idx (add1 current-idx)))]))

  (flush!)
  (reverse modules))

;; ============================================================
;; Form analysis: extract defines and references
;; ============================================================

(define (analyze-form module-name idx form)
  (cond
    [(not (pair? form)) #f]
    [else
     (define head (car form))
     (case head
       [(data)     (analyze-data module-name idx form)]
       [(trait)    (analyze-trait module-name idx form)]
       [(impl)    (analyze-impl module-name idx form)]
       [(defn)    (analyze-defn module-name idx form)]
       [(def)     (analyze-def module-name idx form)]
       [(spec)    (analyze-spec module-name idx form)]
       [(deftype) (analyze-deftype module-name idx form)]
       [(bundle property functor)
        (analyze-simple-decl module-name idx form head)]
       [(subtype) (analyze-subtype module-name idx form)]
       [(foreign) (analyze-foreign module-name idx form)]
       [else #f])]))

;; --- data ---
;; (data T {params} (ctor1 : Field1 -> Field2) (ctor2) ...)
(define (analyze-data mod idx form)
  (define rest (cdr form))
  ;; Type name: first symbol (skip $brace-params)
  (define type-name
    (cond
      [(symbol? (car rest)) (car rest)]
      [(and (pair? (car rest)) (eq? (caar rest) '$brace-params))
       (if (and (pair? (cdr rest)) (symbol? (cadr rest)))
           (cadr rest)
           #f)]
      [else #f]))
  (unless type-name (error 'analyze-data "cannot extract type name: ~a" form))

  ;; Constructor names: symbols that are the first element of sub-lists
  ;; after the type name (and optional brace-params)
  (define ctor-names
    (for/fold ([names '()])
              ([item (in-list rest)])
      (cond
        [(and (pair? item) (symbol? (car item))
              (not (eq? (car item) '$brace-params)))
         (cons (car item) names)]
        [else names])))

  ;; References: all type names used in constructor fields
  (define refs (collect-symbols-from-list rest))

  (form-node mod idx 'data
             (list->seteq (cons type-name ctor-names))
             (set-subtract refs (list->seteq (cons type-name ctor-names)) syntax-keywords)
             form))

;; --- trait ---
;; (trait Tr {A} (method1 : A -> B) ...)
(define (analyze-trait mod idx form)
  (define rest (cdr form))
  ;; Trait name
  (define trait-head (car rest))
  (define trait-name
    (cond
      [(symbol? trait-head) trait-head]
      [(and (pair? trait-head) (symbol? (car trait-head)))
       (car trait-head)]
      [else (error 'analyze-trait "cannot extract trait name: ~a" form)]))

  ;; Method names: symbols before ':' in the remaining items
  (define method-names
    (for/fold ([names '()])
              ([item (in-list (cdr rest))])
      (cond
        [(and (pair? item) (symbol? (car item))
              (memq ': item))
         (cons (car item) names)]
        [else names])))

  ;; Accessor names: Trait-method
  (define accessor-names
    (map (lambda (m) (string->symbol
                      (format "~a-~a" trait-name m)))
         method-names))

  (define refs (collect-symbols-from-list rest))
  (define defines (list->seteq (append (list trait-name) method-names accessor-names)))

  (form-node mod idx 'trait defines
             (set-subtract refs defines syntax-keywords)
             form))

;; --- impl ---
;; (impl Tr Ty (defn method1 (params) body) ...)
;; (impl Tr (Ty A) where (Constraint A) (defn ...) ...)
(define (analyze-impl mod idx form)
  (define rest (cdr form))
  (define trait-name (car rest))
  ;; Type arg(s): second element
  (define type-arg (cadr rest))
  (define type-arg-str
    (cond
      [(symbol? type-arg) (symbol->string type-arg)]
      [(pair? type-arg)
       (string-join (map (lambda (x) (format "~a" x))
                         (filter symbol? type-arg))
                    "-")]
      [else "unknown"]))

  ;; Dict name
  (define dict-name
    (string->symbol
     (format "~a--~a--dict" type-arg-str trait-name)))

  ;; Method helper names
  (define method-defns
    (filter (lambda (item)
              (and (pair? item) (eq? (car item) 'defn)))
            rest))
  (define helper-names
    (for/list ([d (in-list method-defns)])
      (define mname (cadr d))
      (string->symbol
       (format "~a--~a--~a" type-arg-str trait-name mname))))

  (define refs (collect-symbols-from-list rest))
  (define defines (list->seteq (cons dict-name helper-names)))

  (form-node mod idx 'impl defines
             (set-subtract refs defines syntax-keywords)
             form))

;; --- defn ---
;; (defn name (params) body)
;; (defn name (params) ($angle-type RetType) body)
(define (analyze-defn mod idx form)
  (define name (cadr form))
  (define rest (cddr form))

  ;; Extract param names (first list in rest)
  (define param-names
    (cond
      [(and (pair? rest) (pair? (car rest)))
       (extract-binder-names (car rest))]
      [else '()]))

  ;; References: all symbols in body, minus params and name
  (define refs (collect-symbols-from-list rest))
  (define locals (list->seteq (cons name param-names)))

  (form-node mod idx 'defn (seteq name)
             (set-subtract refs locals syntax-keywords)
             form))

;; --- def ---
;; (def name : Type body) or (def name := body)
(define (analyze-def mod idx form)
  (define name (cadr form))
  (define refs (collect-symbols-from-list (cddr form)))

  (form-node mod idx 'def (seteq name)
             (set-subtract refs (seteq name) syntax-keywords)
             form))

;; --- spec ---
;; (spec name Type1 -> Type2 ...) — doesn't define a new name, but associates a type
(define (analyze-spec mod idx form)
  (define name (cadr form))
  ;; For dependency purposes, treat as defining `name` (spec stores it)
  ;; and referencing all type names in the signature
  (define refs (collect-symbols-from-list (cddr form)))

  (form-node mod idx 'spec (seteq name)
             (set-subtract refs (seteq name) syntax-keywords)
             form))

;; --- deftype ---
(define (analyze-deftype mod idx form)
  (define name (cadr form))
  (define refs (collect-symbols-from-list (cddr form)))
  (form-node mod idx 'deftype (seteq name)
             (set-subtract refs (seteq name) syntax-keywords)
             form))

;; --- simple declarations (bundle, property, functor) ---
(define (analyze-simple-decl mod idx form head)
  (define name (cadr form))
  (define refs (collect-symbols-from-list (cddr form)))
  (form-node mod idx head (seteq name)
             (set-subtract refs (seteq name) syntax-keywords)
             form))

;; --- subtype ---
(define (analyze-subtype mod idx form)
  (define refs (collect-symbols-from-list (cdr form)))
  (form-node mod idx 'subtype (seteq)
             (set-subtract refs syntax-keywords)
             form))

;; --- foreign ---
(define (analyze-foreign mod idx form)
  ;; (foreign racket "..." ((name1 Type1) ...))
  (define bindings (if (>= (length form) 4) (cadddr form) '()))
  (define names
    (for/list ([b (in-list (if (pair? bindings) bindings '()))]
               #:when (and (pair? b) (symbol? (car b))))
      (car b)))
  (form-node mod idx 'foreign (list->seteq names) (seteq) form))

;; ============================================================
;; Symbol collection: conservative extraction of all referenced names
;; ============================================================

;; Recursively collect all symbols from a datum tree.
(define (collect-symbols datum)
  (cond
    [(symbol? datum) (seteq datum)]
    [(pair? datum) (set-union (collect-symbols (car datum))
                              (collect-symbols (cdr datum)))]
    [else (seteq)]))

(define (collect-symbols-from-list items)
  (for/fold ([syms (seteq)])
            ([item (in-list items)])
    (set-union syms (collect-symbols item))))

;; Extract binder names from a parameter list.
;; Handles: (x y z), (x : T y : T), (x <T> y <T>), (dict x y)
(define (extract-binder-names params)
  (cond
    [(null? params) '()]
    [(not (pair? params)) '()]
    [else
     (for/list ([item (in-list params)]
                #:when (symbol? item)
                #:when (not (eq? item ':))
                #:when (not (eq? item '->))
                #:when (not (string-prefix? (symbol->string item) "$")))
       item)]))

;; ============================================================
;; Dependency graph construction
;; ============================================================

;; Build a mapping from defined name → form-node (which module + form defines it)
(define (build-name-registry modules)
  (define registry (make-hasheq))
  (for* ([mod (in-list modules)]
         [node (in-list (module-info-forms mod))])
    (for ([name (in-set (form-node-defines node))])
      (hash-set! registry name node)))
  registry)

;; Build module-level dependency graph from requires.
(define (build-module-dep-graph modules)
  (define mod-names (list->seteq (map module-info-name modules)))
  (define graph (make-hasheq))
  (for ([mod (in-list modules)])
    (define deps
      (filter (lambda (r) (set-member? mod-names r))
              (module-info-requires mod)))
    (hash-set! graph (module-info-name mod) deps))
  graph)

;; Compute module-level SCCs using tarjan-scc from stratify.rkt.
(define (find-module-sccs modules)
  (define mod-graph (build-module-dep-graph modules))
  ;; Convert to dep-info for stratify.rkt
  (define dep-infos
    (for/list ([(name deps) (in-hash mod-graph)])
      (dep-info name deps '())))
  (define graph (build-dependency-graph dep-infos))
  (define sccs (tarjan-scc graph))
  ;; Filter to multi-node SCCs (genuine module-level cycles)
  (filter (lambda (scc) (> (length scc) 1)) sccs))

;; ============================================================
;; Form-level cycle analysis within a module SCC
;; ============================================================

;; For a set of modules that form a module-level SCC, check if the
;; cycle can be broken at the form level.
(define (analyze-module-scc scc-mod-names all-modules name-registry)
  (define scc-set (list->seteq scc-mod-names))
  ;; Collect all forms from modules in this SCC
  (define scc-mods
    (filter (lambda (m) (set-member? scc-set (module-info-name m)))
            all-modules))
  (define all-forms
    (apply append (map module-info-forms scc-mods)))

  ;; For each form, find which OTHER forms in the SCC it depends on.
  ;; A form F depends on form G if F references a name defined by G,
  ;; and G is in a DIFFERENT module from F (cross-module dependency).
  (define form-deps
    (for/list ([node (in-list all-forms)])
      (define cross-deps
        (for/fold ([deps (seteq)])
                  ([ref (in-set (form-node-references node))])
          (define target (hash-ref name-registry ref #f))
          (cond
            [(and target
                  (not (eq? (form-node-module-name target)
                            (form-node-module-name node))))
             (set-add deps (form-node-key target))]
            [else deps])))
      (cons (form-node-key node) cross-deps)))

  ;; Build dep-infos for tarjan-scc
  (define dep-infos
    (for/list ([fd (in-list form-deps)])
      (dep-info (car fd) (set->list (cdr fd)) '())))
  (define graph (build-dependency-graph dep-infos))
  (define sccs (tarjan-scc graph))
  ;; Multi-node SCCs are genuine form-level cycles
  (filter (lambda (scc) (> (length scc) 1)) sccs))

;; Unique key for a form-node (for use in dep-info)
(define (form-node-key node)
  (string->symbol
   (format "~a/~a" (form-node-module-name node) (form-node-index node))))

;; ============================================================
;; Reporting
;; ============================================================

(define (report-analysis modules name-registry verbose?)
  (define total-modules (length modules))
  (define total-forms
    (apply + (map (lambda (m) (length (module-info-forms m))) modules)))

  (printf "\n=== Form-Level Dependency Analysis ===\n\n")
  (printf "Chapters analyzed: ~a\n" (length (read-outline)))
  (printf "Modules: ~a\n" total-modules)
  (printf "Forms: ~a\n" total-forms)

  ;; Module-level SCCs
  (define mod-sccs (find-module-sccs modules))
  (printf "\nModule-level cycles: ~a\n" (length mod-sccs))

  (when verbose?
    (printf "\n--- Per-module details ---\n")
    (for ([mod (in-list modules)])
      (printf "  ~a: ~a forms, ~a requires\n"
              (module-info-name mod)
              (length (module-info-forms mod))
              (length (module-info-requires mod)))))

  (cond
    [(null? mod-sccs)
     (printf "\nNo module-level cycles found. Module DAG is clean.\n")]
    [else
     (for ([scc (in-list mod-sccs)] [i (in-naturals 1)])
       (printf "\n--- Module cycle ~a: ~a modules ---\n" i (length scc))
       (for ([mod-name (in-list scc)])
         (printf "  ~a\n" mod-name))

       ;; Analyze at form level
       (define form-sccs (analyze-module-scc scc modules name-registry))
       (cond
         [(null? form-sccs)
          (printf "  → SPURIOUS: forms can be reordered to break this cycle\n")]
         [else
          (printf "  → GENUINE: ~a form-level cycle(s)\n" (length form-sccs))
          (for ([fscc (in-list form-sccs)])
            (printf "    Cycle: ~a\n" (string-join (map symbol->string fscc) " ↔ ")))]))]))

;; ============================================================
;; Main
;; ============================================================

(define verbose? (make-parameter #f))
(define chapter-filter (make-parameter #f))

(command-line
 #:program "form-deps"
 #:once-each
 ["--verbose" "Show per-module details" (verbose? #t)]
 ["--chapter" name "Analyze only this chapter" (chapter-filter name)]
 #:args ()
 (void))

(define chapter-names
  (if (chapter-filter)
      (list (chapter-filter))
      (read-outline)))

(define all-modules
  (apply append
         (for/list ([ch (in-list chapter-names)])
           (with-handlers ([exn:fail?
                            (lambda (e)
                              (eprintf "Warning: failed to parse chapter ~a: ~a\n"
                                       ch (exn-message e))
                              '())])
             (parse-chapter ch)))))

(define name-registry (build-name-registry all-modules))

(report-analysis all-modules name-registry (verbose?))
