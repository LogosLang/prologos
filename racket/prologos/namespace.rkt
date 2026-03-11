#lang racket/base

;;;
;;; PROLOGOS NAMESPACE SYSTEM
;;; Module registry, namespace contexts, and name resolution.
;;;
;;; Namespaces use Clojure-style naming:
;;;   prologos::data::nat::add — :: for both hierarchy and qualified names
;;;
;;; The module registry caches loaded modules.
;;; The namespace context tracks per-file imports, aliases, and exports.
;;; Name resolution maps short/aliased names to fully-qualified symbols.
;;;

(require racket/match
         racket/string
         racket/list
         racket/set
         racket/path)

(provide
 ;; Module info
 (struct-out module-info)
 ;; Module registry
 current-module-registry
 register-module!
 lookup-module
 module-loaded?
 ;; Namespace context
 (struct-out ns-context)
 current-ns-context
 make-empty-ns-context
 ns-context-add-alias
 ns-context-add-refer
 ns-context-add-refer-all
 ns-context-set-exports
 ns-context-add-auto-export
 ;; Name resolution
 resolve-name
 qualify-name
 split-qualified-name
 ;; File resolution
 ns->path-segments
 resolve-ns-path
 current-lib-paths
 ;; Cycle detection
 current-loading-set
 ;; Module loader callback (set by driver.rkt)
 current-module-loader
 ;; Pre-parse directive processing
 process-ns-declaration
 process-imports
 process-exports
 ;; Backward-compat aliases
 (rename-out [process-imports process-require]
             [process-exports process-provide])
 ;; Foreign import handler (callback set by driver.rkt)
 current-foreign-handler
 process-foreign
 ;; Spec propagation callback (set by driver.rkt for HKT implicit arg insertion)
 current-spec-propagation-handler)

;; ========================================
;; Module Info — describes a loaded module
;; ========================================

(struct module-info
  (namespace      ; symbol: e.g., 'prologos::data::nat
   exports        ; (listof symbol): short names exported, e.g., '(add mult zero)
   env-snapshot   ; hasheq: fully-qualified-symbol → (cons type value)
   file-path      ; path-string or #f (for built-in modules)
   macros         ; hasheq: short-name → preparse-macro or procedure
   type-aliases   ; hasheq: short-name → alias body
   specs)         ; hasheq: short-name → spec-entry (for implicit arg insertion)
  #:transparent)

;; ========================================
;; Module Registry — caches loaded modules
;; ========================================

;; Maps namespace-symbol → module-info
(define current-module-registry (make-parameter (hasheq)))

;; Register a loaded module in the registry
(define (register-module! ns-sym mod-info)
  (current-module-registry
   (hash-set (current-module-registry) ns-sym mod-info)))

;; Look up a module by namespace symbol
(define (lookup-module ns-sym)
  (hash-ref (current-module-registry) ns-sym #f))

;; Check if a module is already loaded
(define (module-loaded? ns-sym)
  (hash-has-key? (current-module-registry) ns-sym))

;; ========================================
;; Namespace Context — per-file import state
;; ========================================

(struct ns-context
  (current-ns      ; symbol: this file's namespace (e.g., 'prologos::data::nat)
   alias-map       ; hasheq: alias-symbol → namespace-symbol
                   ;   e.g., 'nat → 'prologos::data::nat
   refer-map       ; hasheq: short-name → fully-qualified-name
                   ;   e.g., 'add → 'prologos::data::nat::add
   refer-all-nses  ; (listof symbol): namespaces where all exports are available unqualified
   exports         ; (listof symbol): names this module provides (short names) — from explicit provide
   auto-exports)   ; (listof symbol): names auto-exported by public def/defn/data/deftype/defmacro
  #:transparent)

;; The current namespace context (parameterized per-file)
;; When #f, the system is in legacy mode (no namespace resolution)
(define current-ns-context (make-parameter #f))

;; Create an empty namespace context for a given namespace
(define (make-empty-ns-context ns-sym)
  (ns-context ns-sym (hasheq) (hasheq) '() '() '()))

;; Add an alias: (require [prologos::data::nat :as nat])
;; Maps alias → namespace-symbol
(define (ns-context-add-alias ctx alias ns-sym)
  (struct-copy ns-context ctx
    [alias-map (hash-set (ns-context-alias-map ctx) alias ns-sym)]))

;; Add specific referred names: (require [prologos::data::nat :refer [add mult]])
;; Maps each short name → fully-qualified name
(define (ns-context-add-refer ctx ns-sym names)
  (define new-refer
    (for/fold ([rm (ns-context-refer-map ctx)])
              ([name (in-list names)])
      (hash-set rm name (qualify-name name ns-sym))))
  (struct-copy ns-context ctx [refer-map new-refer]))

;; Add a namespace for :refer-all
(define (ns-context-add-refer-all ctx ns-sym)
  (struct-copy ns-context ctx
    [refer-all-nses (cons ns-sym (ns-context-refer-all-nses ctx))]))

;; Set the exports list
(define (ns-context-set-exports ctx export-names)
  (struct-copy ns-context ctx [exports export-names]))

;; Add a name to the auto-exports list (for public definitions).
;; Avoids duplicates.
(define (ns-context-add-auto-export ctx name)
  (if (memq name (ns-context-auto-exports ctx))
      ctx
      (struct-copy ns-context ctx
        [auto-exports (cons name (ns-context-auto-exports ctx))])))

;; ========================================
;; Name Qualification
;; ========================================

;; Create a fully-qualified name: short-name + namespace → fqn
;; e.g., 'add + 'prologos::data::nat → 'prologos::data::nat::add
(define (qualify-name short-name ns-sym)
  (string->symbol
   (string-append (symbol->string ns-sym) "::" (symbol->string short-name))))

;; Split a qualified name into prefix and short-name
;; Splits on the LAST :: so that hierarchical paths work:
;; 'nat::add → (values 'nat 'add)
;; 'prologos::data::nat::add → (values 'prologos::data::nat 'add)
;; 'add (no ::) → (values #f 'add)
(define (split-qualified-name sym)
  (define s (symbol->string sym))
  (define idx (string-find-last-substring s "::"))
  (if idx
      (values (string->symbol (substring s 0 idx))
              (string->symbol (substring s (+ idx 2))))
      (values #f sym)))

;; Helper: find the index of the FIRST occurrence of a substring, or #f
(define (string-find-substring s sub)
  (define sub-len (string-length sub))
  (define s-len (string-length s))
  (for/first ([i (in-range (+ 1 (- s-len sub-len)))]
              #:when (string=? (substring s i (+ i sub-len)) sub))
    i))

;; Helper: find the index of the LAST occurrence of a substring, or #f
(define (string-find-last-substring s sub)
  (define sub-len (string-length sub))
  (define s-len (string-length s))
  (for/last ([i (in-range (+ 1 (- s-len sub-len)))]
             #:when (string=? (substring s i (+ i sub-len)) sub))
    i))

;; ========================================
;; Name Resolution
;; ========================================

;; Resolve a symbol to its fully-qualified form.
;; Returns the resolved symbol, or #f if unresolvable.
;;
;; Algorithm:
;;   1. If ns-ctx is #f (legacy mode), return sym as-is
;;   2. If symbol contains '/', split into prefix + name:
;;      a. If prefix is an alias → resolve to aliased-ns/name
;;      b. If prefix looks like a full namespace → return as-is
;;   3. Check refer-map for direct import
;;   4. Check refer-all namespaces' exports
;;   5. Qualify with current-ns (own definitions)
;;   6. Return sym as fallback (may be a built-in like Nat, Bool, etc.)
(define (resolve-name sym ns-ctx)
  (cond
    ;; Legacy mode: no namespace resolution
    [(not ns-ctx) sym]
    [else
     (define-values (prefix short-name) (split-qualified-name sym))
     (cond
       ;; Qualified name: prefix/name
       [prefix
        (define aliased-ns (hash-ref (ns-context-alias-map ns-ctx) prefix #f))
        (cond
          ;; Prefix is a known alias
          [aliased-ns (qualify-name short-name aliased-ns)]
          ;; Prefix might be a full namespace name — return as-is
          [else sym])]

       ;; Unqualified name: try various resolution strategies
       [else
        (or
         ;; 1. Check explicit refer-map
         (hash-ref (ns-context-refer-map ns-ctx) sym #f)

         ;; 2. Check refer-all namespaces
         (resolve-in-refer-all sym ns-ctx)

         ;; 3. Qualify with current namespace (own definitions)
         (let ([fqn (qualify-name sym (ns-context-current-ns ns-ctx))])
           ;; We return the fqn but the caller must verify it exists in global-env
           fqn)

         ;; 4. Fallback: return sym as-is (might be a built-in type/keyword)
         sym)])]))

;; Search refer-all namespaces for a name
;; Returns the fqn if found in any module's exports, or #f
(define (resolve-in-refer-all sym ns-ctx)
  (for/or ([ns-sym (in-list (ns-context-refer-all-nses ns-ctx))])
    (define mod (lookup-module ns-sym))
    (and mod
         (member sym (module-info-exports mod))
         (qualify-name sym ns-sym))))

;; ========================================
;; File Resolution
;; ========================================

;; Convert a namespace symbol to path segments
;; 'prologos::data::nat → '("prologos" "data" "nat")
(define (ns->path-segments ns-sym)
  (string-split (symbol->string ns-sym) "::"))

;; Library search paths (list of directories)
;; First path is the standard library, additional paths can be added
(define current-lib-paths (make-parameter '()))

;; Resolve a namespace symbol to an absolute file path
;; Searches:
;;   1. Relative to base-dir (for project-local modules)
;;   2. Each directory in current-lib-paths
;; Returns the absolute path or #f if not found
(define (resolve-ns-path ns-sym base-dir)
  (define segments (ns->path-segments ns-sym))
  (define filename (string-append (last segments) ".prologos"))
  (define dir-segments (drop-right segments 1))

  (define (try-dir root)
    (define candidate
      (apply build-path root (append dir-segments (list filename))))
    (and (file-exists? candidate) candidate))

  ;; Search order: base-dir first, then lib paths
  (or (and base-dir (try-dir base-dir))
      (for/or ([lib-dir (in-list (current-lib-paths))])
        (try-dir lib-dir))))

;; ========================================
;; Cycle Detection
;; ========================================

;; Set of namespace symbols currently being loaded
;; Used to detect circular dependencies
(define current-loading-set (make-parameter (seteq)))

;; ========================================
;; Module Loader Callback
;; ========================================

;; A procedure: (ns-sym base-dir) → module-info
;; Set by driver.rkt to avoid circular dependency.
;; When #f, require will error (module loading not available).
(define current-module-loader (make-parameter #f))

;; Callback for propagating specs from imported modules.
;; Signature: (module-info (listof symbol)) → void
;; Called when :refer or :refer-all imports names that may have specs.
;; Set by driver.rkt to bridge namespace.rkt ↔ current-spec-store.
(define current-spec-propagation-handler (make-parameter #f))

;; ========================================
;; Prelude System
;; ========================================
;; When a user module declares (ns foo), the prelude auto-imports a curated
;; set of modules — data types, list ops, traits, and numeric instances.
;; Library modules (prologos::data::* and prologos::core::*) skip the prelude
;; to avoid circular loading and only get prologos::core::
;;
;; Modeled after: Haskell Prelude, Idris Prelude, Clojure core.
;; Name conflicts resolved: List ops win unqualified; Option/Result via aliases.

;; Modules that are direct/transitive dependencies of the prelude.
;; These must NOT auto-import the prelude (would cause circular loading).
;; They get prologos::core instead (the pre-prelude behavior).
(define (prelude-dependency? ns-sym)
  (define s (symbol->string ns-sym))
  (or (string-prefix? s "prologos::data::")
      (string-prefix? s "prologos::core::")))

;;; ---- BEGIN GENERATED PRELUDE ----
;; The prelude: a curated list of imports specs emitted into user namespaces.
;; Generated from lib/prologos/book/PRELUDE by tools/gen-prelude.rkt.
(define prelude-imports
  '(;; ---- Core combinators (not a book chapter) ----
    (imports [prologos::core :refer-all])

    ;; ---- Foundation data types ----
    (imports [prologos::data::ordering :refer [Ordering lt-ord eq-ord gt-ord]])
    (imports [prologos::data::bool     :refer [not and or xor bool-eq implies nand nor]])
    (imports [prologos::data::nat      :as nat :refer [zero?]])
    (imports [prologos::data::pair     :refer [swap map-fst map-snd bimap dup uncurry]])
    (imports [prologos::data::eq       :refer [sym cong trans]])
    ;; Datum: code-as-data for quote/quasiquote
    (imports [prologos::data::datum   :refer [Datum datum-sym datum-kw datum-nat
                                              datum-int datum-rat datum-bool
                                              datum-nil datum-cons
                                              sym? kw? nat? int? rat? bool? nil? cons?]])

    ;; ---- Char & String data operations ----
    ;; Most operations accessed via module alias: char::code, str::length, etc.
    (imports [prologos::data::char   :as char :refer []])
    (imports [prologos::data::string :as str  :refer []])

    ;; ---- Container data types ----
    ;; Option: types + predicates unqualified; ops via opt:: alias
    (imports [prologos::data::option :as opt :refer [Option none some some? none? flatten]])
    ;; Result: types + predicates unqualified; ops via result:: alias
    (imports [prologos::data::result :as result :refer [Result ok err ok? err?]])
    ;; List: full API unqualified (wins all name-conflict tiebreaks)
    (imports [prologos::data::list :refer [List nil cons foldr reduce length
                                           map filter append head tail singleton
                                           reverse sum product any? all? find
                                           nth last replicate range concat
                                           concat-map take drop split-at
                                           take-while drop-while partition
                                           zip-with zip unzip intersperse sort
                                           elem dedup count scanl iterate-n
                                           intercalate sort-on reduce1 foldr1
                                           init span break prefix-of? suffix-of?
                                           delete find-index]])

    ;; ---- Core traits (type class definitions) ----
    (imports [prologos::core::eq :refer [Eq eq-check eq-neq nat-eq Char--Eq--dict String--Eq--dict]])
    (imports [prologos::core::ord :refer [Ord ord-compare PartialOrd PartialOrd-partial-compare
                                          nat-ord ord-lt ord-le ord-gt ord-ge ord-eq
                                          ord-min ord-max Char--Ord--dict String--Ord--dict]])
    (imports [prologos::core::arithmetic :refer [Add Sub Mul Div Neg Abs String--Add--dict]])
    (imports [prologos::core::conversions :refer [From Into TryFrom FromInt FromRat]])
    (imports [prologos::core::algebra :refer-all])
    (imports [prologos::core::lattice :refer-all])
    (imports [prologos::core::collection-traits :refer [Reducible Collection]])

    ;; ---- Additional container types + operations ----
    (imports [prologos::data::map-entry :refer [MapEntry mk-entry entry-key entry-val]])
    (imports [prologos::data::lseq     :as lseq :refer [LSeq lseq-nil lseq-cell]])
    (imports [prologos::data::lseq-ops :refer [list-to-lseq lseq-to-list lseq-map
                                               lseq-filter lseq-take lseq-drop
                                               lseq-append lseq-fold lseq-length]])
    (imports [prologos::data::set      :refer [set-singleton set-from-list set-symmetric-diff]])

    ;; ---- Identity traits (in algebra module) ----
    ;; AdditiveIdentity, MultiplicativeIdentity, and all instances are in prologos::core::algebra

    ;; ---- String operation module ----
    ;; Most ops via str-ops:: alias to avoid conflicts with List names.
    (imports [prologos::core::string-ops :as str-ops :refer []])

    ;; ---- Collection operation modules (consolidated) ----
    ;; Note: pvec-map, pvec-filter, pvec-fold, set-fold, set-filter,
    ;; map-fold-entries, map-filter-entries, map-map-vals are now native
    ;; parser keywords — no need to import from ops modules.
    ;; pvec: pvec-any?, pvec-all?, pvec-from-list-fn, pvec-to-list-fn
    (imports [prologos::core::pvec :refer [pvec-any? pvec-all?
                                           pvec-from-list-fn pvec-to-list-fn]])
    ;; map: map-filter-vals, map-keys-list, map-vals-list, map-merge,
    ;;      map-to-entry-list, map-seq, map-from-seq
    (imports [prologos::core::map  :refer [map-filter-vals map-keys-list
                                           map-vals-list map-merge
                                           map-to-entry-list map-seq map-from-seq]])
    ;; set: set-map, set-any?, set-all?, set-to-list-fn, set-from-list-fn
    (imports [prologos::core::set  :refer [set-map set-any? set-all?
                                           set-to-list-fn set-from-list-fn]])

    ;; ---- Collection conversions (now in prologos::core::collections) ----

    ;; ---- Generic numeric operations + first-class arithmetic ----
    ;; sum, product, int-range, plus, minus, times, divide, negate-fn, abs-fn
    ;; are now in prologos::core::algebra (loaded via :refer-all above)

    ;; ---- Instance registration (side-effect only, :refer []) ----
    ;; eq-instances + eq-numeric-instances merged into prologos::core::eq
    ;; ord-instances + ord-numeric-instances merged into prologos::core::ord
    ;; add/sub/mul/div/neg/abs traits + instances + add-string-instance merged into prologos::core::arithmetic
    ;; from/tryfrom/into/fromint/fromrat traits + instances merged into prologos::core::conversions

    ;; ---- Char/String trait instances ----
    ;; Dict bindings are referred so they resolve in user code (not just side-effect)
    ;; eq-char-instance merged into prologos::core::eq
    ;; ord-char-instance merged into prologos::core::ord
    ;; hashable-trait + hashable-instances + hashable-char-instance + hashable-string-instance merged into prologos::core::hashable
    (imports [prologos::core::hashable :refer [Char--Hashable--dict String--Hashable--dict]])
    ;; eq-string-instance merged into prologos::core::eq
    ;; ord-string-instance merged into prologos::core::ord
    ;; add-string-instance merged into prologos::core::arithmetic

    ;; ---- Collection trait instances (consolidated by type) ----
    ;; list: Seqable, Buildable, Foldable, Reducible, Indexed, Functor, Seq instances
    (imports [prologos::core::list :refer-all])
    ;; pvec: Seqable, Buildable, Foldable, Reducible, Indexed, Functor instances + ops
    (imports [prologos::core::pvec :refer-all])
    ;; set: Seqable, Buildable, Foldable, Reducible, Setlike instances + ops
    (imports [prologos::core::set  :refer-all])
    ;; lseq: Seqable, Buildable, Foldable, Reducible, Seq instances
    (imports [prologos::core::lseq :refer-all])
    ;; map: Keyed instance + ops (map-filter-vals, map-merge, map-seq, etc.)
    (imports [prologos::core::map  :refer-all])

    ;; ---- Identity trait instances ----
    ;; Instances are now in prologos::core::algebra (loaded via :refer-all above)

    ;; ---- Generic collection operations (HKT-dispatched) ----
    (imports [prologos::core::generic-ops :refer [gmap gfilter gfold glength
                                                  gconcat gany? gall? gto-list]])

    ;; ---- Lattice + HasTop + BoundedLattice + Widenable + GaloisConnection ----
    ;; All lattice hierarchy consolidated into prologos::core::lattice (loaded via :refer-all above)

    ;; ---- Standard capability types (side-effect registration) ----
    ;; ReadCap, WriteCap, HttpCap, StdioCap, FsCap, NetCap, SysCap
    ;; + subtype hierarchy (ReadCap <: FsCap <: SysCap, etc.)
    (imports [prologos::core::capabilities :refer []])

    ;; ---- IO convenience functions (IO-D2) ----
    ;; Only print/println in prelude; read-ln/read-file/write-file need explicit import
    (imports [prologos::core::io :refer [print println]])

    ;; ---- Propagator helpers ----
    (imports [prologos::core::propagator :refer [new-lattice-cell new-widenable-cell]])

    ;; ---- Abstract domain instances (Sign/Parity lattices, Galois connections, refined numerics) ----
    (imports [prologos::core::abstract-domains :refer-all])

    ;; ---- Generic collection functions + conversions (clean names) ----
    ;; These shadow List-specific names (map, filter, reduce, etc.) with
    ;; generic versions that work on any Seqable/Buildable/Foldable collection.
    ;; Also includes collection-to-collection conversions (vec, list-to-seq, etc.)
    ;; and List-specialized coll-map/coll-filter/coll-length/coll-to-list.
    ;; MUST BE LAST — shadowing depends on ordering.
    (imports [prologos::core::collections :refer [map filter reduce reduce1
                                                  length concat any? all?
                                                  to-list find take drop
                                                  into head empty? rest-seq
                                                  first second rest
                                                  coll-map coll-filter coll-length coll-to-list
                                                  vec list-to-seq pvec-to-seq
                                                  set-to-seq into-vec
                                                  into-list into-set]])))
;;; ---- END GENERATED PRELUDE ----

;; ========================================
;; Pre-parse Directive Processing
;; ========================================
;; These functions are called from macros.rkt during preparse-expand-all.
;; They consume ns/imports/exports forms and have side effects on
;; current-ns-context, current-global-env, and current-module-registry.

;; (ns namespace-sym)
;; (ns namespace-sym :no-prelude)
;; Sets the current namespace context.
;; Auto-imports the full prelude for user modules, or just prologos::core
;; for library modules and :no-prelude opt-outs.
(define (process-ns-declaration datum)
  (unless (and (list? datum) (>= (length datum) 2) (symbol? (cadr datum)))
    (error 'ns "ns requires: (ns namespace-name) or (ns namespace-name :no-prelude)"))
  (define ns-sym (cadr datum))
  (define no-prelude?
    (and (>= (length datum) 3)
         (memq ':no-prelude (cddr datum))))
  (current-ns-context (make-empty-ns-context ns-sym))
  ;; Decide what to auto-import
  (define skip-prelude?
    (or no-prelude?
        (eq? ns-sym 'prologos::core)
        (prelude-dependency? ns-sym)))
  (when (current-module-loader)
    (cond
      [skip-prelude?
       ;; Library modules and :no-prelude: just get prologos::core
       (unless (eq? ns-sym 'prologos::core)
         (with-handlers ([exn:fail? (lambda (e) (void))])
           (process-imports '(imports [prologos::core :refer-all]))))]
      [else
       ;; User modules: get the full prelude
       ;; Each imports is individually wrapped so one failure doesn't
       ;; prevent loading of subsequent modules.
       (for ([req (in-list prelude-imports)])
         (with-handlers ([exn:fail? (lambda (e) (void))])
           (process-imports req)))])))

;; (exports name ...)
;; (exports :all)
;; Records the export list in the current namespace context.
;; Also accepts legacy (provide ...) form for backward compatibility.
(define (process-exports datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'exports "exports requires: (exports name ...) or (exports :all)"))
  (define names (cdr datum))
  (define ctx (current-ns-context))
  (unless ctx
    (error 'exports "exports used without ns declaration"))
  (cond
    [(and (= (length names) 1) (eq? (car names) ':all))
     ;; :all — will be resolved at module finalization time
     (ns-context-set-exports ctx '(:all))]
    [else
     (unless (andmap symbol? names)
       (error 'exports "exports: all names must be symbols"))
     (current-ns-context (ns-context-set-exports ctx names))]))

;; (imports spec ...)
;; Where each spec is one of:
;;   [ns-sym :as alias]
;;   [ns-sym :refer [name ...]]
;;   [ns-sym :refer-all]
;;   ns-sym  (shorthand for [ns-sym :refer-all])
;; Also accepts legacy (require ...) form for backward compatibility.
(define (process-imports datum)
  (unless (and (list? datum) (>= (length datum) 2))
    (error 'imports "imports requires at least one spec"))
  (for ([spec (in-list (cdr datum))])
    (process-imports-spec spec)))

;; Process a single imports spec
(define (process-imports-spec spec)
  (cond
    ;; Bare symbol: (imports prologos::data::nat) → shorthand for :refer-all
    [(symbol? spec)
     (process-imports-spec (list spec ':refer-all))]

    ;; List form: [ns-sym :as alias] or [ns-sym :refer [...]] or [ns-sym :refer-all]
    [(and (list? spec) (>= (length spec) 2) (symbol? (car spec)))
     (define ns-sym (car spec))
     (define directives (cdr spec))

     ;; Load the module if not already loaded
     (define mod (ensure-module-loaded ns-sym))

     ;; Process directives
     (let loop ([dirs directives])
       (cond
         [(null? dirs) (void)]

         ;; :as alias (WS reader may strip colon: 'as or ':as)
         [(and (>= (length dirs) 2) (memq (car dirs) '(:as as)) (symbol? (cadr dirs)))
          (define alias (cadr dirs))
          (current-ns-context
           (ns-context-add-alias (current-ns-context) alias ns-sym))
          (loop (cddr dirs))]

         ;; :refer [name ...] (WS reader may strip colon: 'refer or ':refer)
         [(and (>= (length dirs) 2) (memq (car dirs) '(:refer refer)) (list? (cadr dirs)))
          (define names (cadr dirs))
          ;; Validate that all referred names are exported by the module
          (when mod
            (define exports (module-info-exports mod))
            (for ([name (in-list names)])
              (unless (or (member name exports)
                          (and (pair? exports) (eq? (car exports) ':all)))
                (error 'imports
                       "~a does not export ~a (exports: ~a)"
                       ns-sym name exports))))
          (current-ns-context
           (ns-context-add-refer (current-ns-context) ns-sym names))
          ;; Propagate specs for imported names (needed for implicit arg insertion
          ;; of where-constraint dicts in HKT generic functions)
          (when (and mod (current-spec-propagation-handler))
            ((current-spec-propagation-handler) mod names))
          (loop (cddr dirs))]

         ;; :refer-all (WS reader may strip colon: 'refer-all or ':refer-all)
         [(memq (car dirs) '(:refer-all refer-all))
          (current-ns-context
           (ns-context-add-refer-all (current-ns-context) ns-sym))
          ;; Also add explicit refers for all exports so they resolve without registry lookup
          (when mod
            (define exports (module-info-exports mod))
            (unless (and (pair? exports) (eq? (car exports) ':all))
              (current-ns-context
               (ns-context-add-refer (current-ns-context) ns-sym exports)))
            ;; Propagate specs for all exported names
            (when (current-spec-propagation-handler)
              ((current-spec-propagation-handler) mod exports)))
          (loop (cdr dirs))]

         [else
          (error 'imports "Unknown imports directive: ~a" (car dirs))]))]

    [else
     (error 'imports "Invalid imports spec: ~a" spec)]))

;; Ensure a module is loaded, returning its module-info (or #f if loader unavailable).
;; Always calls load-module (even if cached) so that load-module can import
;; the module's env-snapshot into the caller's current-global-env.
(define (ensure-module-loaded ns-sym)
  (let ([loader (current-module-loader)])
    (cond
      [loader
       (define mod (loader ns-sym #f))
       mod]
      [else
       ;; No loader available — check cache directly
       (lookup-module ns-sym)])))

;; ========================================
;; Foreign Import Handler
;; ========================================
;; Callback pattern: the actual handler is set by driver.rkt because it
;; needs access to parse-datum, elaborate, and dynamic-require.
;; namespace.rkt provides the parameter and thin dispatcher.

(define current-foreign-handler (make-parameter #f))

(define (process-foreign datum)
  (define handler (current-foreign-handler))
  (unless handler
    (error 'foreign "foreign handler not initialized (no driver context)"))
  (handler datum))
